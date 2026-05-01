import SwiftUI
import WebKit

/// A 3D wireframe talking head avatar rendered in a WKWebView.
/// Uses @met4citizen/talkinghead (Three.js) with two-pass wireframe rendering.
struct TalkingHeadView: UIViewRepresentable {
    var isSpeaking: Bool
    var mood: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = config.userContentController
        // Use a weak wrapper to avoid retain cycle (WKUserContentController retains its handlers)
        let handler = WeakScriptMessageHandler(delegate: context.coordinator)
        contentController.add(handler, name: "talkingHead")

        // Custom URL scheme handler so fetch() can load the .glb (file:// is opaque-origin and blocks fetch)
        let schemeHandler = TalkingHeadResourceHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "thapp")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        context.coordinator.webView = webView

        // Load via custom scheme so fetch/XHR for sibling resources works
        if let url = URL(string: "thapp://localhost/talkinghead.html") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        if isSpeaking != coordinator.lastSpeaking {
            coordinator.lastSpeaking = isSpeaking
            coordinator.sendCommand(
                "handleCommand({type:'setSpeaking',speaking:\(isSpeaking)})"
            )
        }

        if mood != coordinator.lastMood {
            coordinator.lastMood = mood
            coordinator.sendCommand(
                "handleCommand({type:'mood',mood:'\(mood)'})"
            )
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "talkingHead")
        coordinator.webView = nil
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        var isLoaded = false
        var pendingCommands: [String] = []
        var lastSpeaking = false
        var lastMood = "neutral"

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body as? [String: Any]
            Task { @MainActor [weak self] in
                guard let self, let body, let event = body["event"] as? String else { return }

                switch event {
                case "loaded":
                    self.isLoaded = true
                    NSLog("[TalkingHead] ✅ loaded")
                    for cmd in self.pendingCommands {
                        self.webView?.evaluateJavaScript(cmd, completionHandler: nil)
                    }
                    self.pendingCommands.removeAll()
                case "error":
                    let msg = body["message"] as? String ?? "unknown"
                    NSLog("[TalkingHead] ❌ Error: \(msg)")
                case "console":
                    let level = body["level"] as? String ?? "log"
                    let msg = body["message"] as? String ?? ""
                    NSLog("[TalkingHead/%@] %@", level, msg)
                case "speechEnd":
                    break
                default:
                    break
                }
            }
        }

        func sendCommand(_ js: String) {
            if isLoaded {
                webView?.evaluateJavaScript(js, completionHandler: nil)
            } else {
                pendingCommands.append(js)
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NSLog("[TalkingHead] Navigation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Weak Script Message Handler (avoids retain cycle)

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Custom Resource URL Scheme Handler
// Serves files from the app bundle Resources folder via `thapp://` URLs so that
// JS `fetch()` works (file:// origins are opaque and block fetch/CORS).

private final class TalkingHeadResourceHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "TalkingHead", code: -1))
            return
        }
        // Resource name comes from the URL path (strip leading slash)
        let path = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard !path.isEmpty,
              let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(path),
              let data = try? Data(contentsOf: resourceURL) else {
            urlSchemeTask.didFailWithError(NSError(domain: "TalkingHead", code: 404, userInfo: [NSLocalizedDescriptionKey: "Resource not found: \(path)"]))
            return
        }
        let mime = Self.mimeType(for: resourceURL.pathExtension.lowercased())
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Access-Control-Allow-Origin": "*"
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext {
        case "html": return "text/html"
        case "js", "mjs": return "application/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "glb": return "model/gltf-binary"
        case "gltf": return "model/gltf+json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        default: return "application/octet-stream"
        }
    }
}
