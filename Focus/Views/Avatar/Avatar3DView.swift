import SwiftUI
import SceneKit
import GLTFKit2

// MARK: - Avatar 3D View

/// A SwiftUI view that displays a 3D avatar from a Ready Player Me GLB URL
struct Avatar3DView: UIViewRepresentable {
    let avatarURL: String
    var backgroundColor: UIColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
    var enableRotation: Bool = true
    var autoRotate: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = backgroundColor
        sceneView.allowsCameraControl = enableRotation
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X

        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene

        // Add camera - positioned for 1.8m tall model
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        // Camera at chest height (1.2m), 3m away
        cameraNode.position = SCNVector3(x: 0, y: 1.2, z: 3.0)
        cameraNode.look(at: SCNVector3(x: 0, y: 1.0, z: 0))
        scene.rootNode.addChildNode(cameraNode)

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 1000
        directionalLight.position = SCNVector3(x: 3, y: 5, z: 3)
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 4, y: .pi / 4, z: 0)
        scene.rootNode.addChildNode(directionalLight)

        // Load avatar using GLTFKit2
        context.coordinator.loadAvatar(url: avatarURL, into: sceneView, autoRotate: autoRotate)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if URL changes
        if context.coordinator.currentURL != avatarURL {
            context.coordinator.loadAvatar(url: avatarURL, into: uiView, autoRotate: autoRotate)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var currentURL: String = ""
        var avatarNode: SCNNode?
        var animationPlayers: [SCNAnimationPlayer] = []

        func loadAvatar(url: String, into sceneView: SCNView, autoRotate: Bool) {
            currentURL = url

            // Remove previous avatar
            avatarNode?.removeFromParentNode()
            animationPlayers.removeAll()

            guard let avatarURL = URL(string: url) else {
                print("❌ Invalid avatar URL: \(url)")
                return
            }

            print("📥 Downloading avatar from: \(url)")

            // Download GLB file
            URLSession.shared.downloadTask(with: avatarURL) { [weak self] localURL, response, error in
                guard let self = self, let localURL = localURL, error == nil else {
                    print("❌ Download error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                print("✅ Download complete, loading GLB...")

                // Load GLB using GLTFKit2
                do {
                    let asset = try GLTFAsset(url: localURL)

                    // Convert GLTF to SceneKit
                    let sceneSource = GLTFSCNSceneSource(asset: asset)
                    guard let loadedScene = sceneSource.defaultScene else {
                        print("❌ Failed to get scene from GLTF asset")
                        return
                    }

                    // Get animations from the asset
                    let animations = sceneSource.animations

                    DispatchQueue.main.async {
                        // Clone the root node
                        let avatarNode = loadedScene.rootNode.clone()

                        // CesiumMan is ~1.8m tall, already in meters, Y-up
                        // Scale to fit nicely in view
                        avatarNode.scale = SCNVector3(x: 1.0, y: 1.0, z: 1.0)

                        // Position at origin (feet at y=0)
                        avatarNode.position = SCNVector3(x: 0, y: 0, z: 0)

                        // CesiumMan faces -Z by default (toward camera), no rotation needed
                        avatarNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)

                        // Store reference
                        self.avatarNode = avatarNode

                        // Add to scene
                        sceneView.scene?.rootNode.addChildNode(avatarNode)

                        // Play all animations (idle, etc.)
                        if !animations.isEmpty {
                            print("🎬 Found \(animations.count) animation(s), playing...")
                            for (index, animation) in animations.enumerated() {
                                // GLTFSCNAnimation has an animationPlayer property
                                animation.animationPlayer.animation.usesSceneTimeBase = false
                                animation.animationPlayer.animation.repeatCount = .greatestFiniteMagnitude
                                avatarNode.addAnimationPlayer(animation.animationPlayer, forKey: "animation_\(index)")
                                animation.animationPlayer.play()
                                self.animationPlayers.append(animation.animationPlayer)
                            }
                        } else {
                            print("⚠️ No animations found in model")
                            // Apply simple breathing animation as fallback
                            let breatheIn = SCNAction.scale(to: 1.02, duration: 1.5)
                            let breatheOut = SCNAction.scale(to: 1.0, duration: 1.5)
                            let breathe = SCNAction.sequence([breatheIn, breatheOut])
                            let breatheForever = SCNAction.repeatForever(breathe)
                            avatarNode.runAction(breatheForever)
                        }

                        // Optional auto-rotation animation
                        if autoRotate {
                            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8)
                            let repeatRotation = SCNAction.repeatForever(rotation)
                            avatarNode.runAction(repeatRotation)
                        }

                        print("✅ Avatar loaded successfully with GLTFKit2!")
                    }

                } catch {
                    print("❌ GLTFKit2 loading error: \(error)")
                }
            }.resume()
        }
    }
}

// MARK: - Avatar URL Constants

struct AvatarURLs {
    // Khronos official glTF sample - correctly oriented
    static let cesiumMan = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMan/glTF-Binary/CesiumMan.glb"

    // Problematic model (non-standard orientation)
    static let femaleAnimated = "https://raw.githubusercontent.com/hmthanh/3d-human-model/main/TranThiNgocTham.glb"

    /// Get avatar URL
    static func forGender(_ gender: String?) -> String {
        return cesiumMan  // Use correctly oriented model
    }
}

// MARK: - Avatar Card View (for use in profile)

struct AvatarCardView: View {
    let gender: String?
    var height: CGFloat = 400
    var showEditButton: Bool = true
    var onEditTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.11, blue: 0.31),
                            Color(red: 0.10, green: 0.10, blue: 0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height)

            // 3D Avatar
            Avatar3DView(
                avatarURL: AvatarURLs.forGender(gender),
                backgroundColor: .clear,
                enableRotation: true,
                autoRotate: false
            )
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Edit button overlay
            if showEditButton {
                VStack {
                    Spacer()

                    Button(action: { onEditTap?() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14))
                            Text("Modifier l'apparence")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AvatarCardView(gender: "male")
            .padding()

        AvatarCardView(gender: "female", height: 300)
            .padding()
    }
    .background(Color.black)
}
