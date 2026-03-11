#!/usr/bin/env python3
"""
Focus Coach — Conversation Quality Analyzer.

Analyzes exported conversation logs to detect coaching quality issues:
- Passive vs proactive coaching ratio
- Emotional intelligence (empathy, validation, minimization)
- Response length adaptation
- Tool usage patterns
- Question frequency
- Repetitive/generic responses
- Missing follow-ups on emotional topics
- Session structure issues

Usage:
    # Analyze a JSON export of conversations
    python3 tests/analyze_conversations.py conversations.json

    # Analyze with verbose output
    python3 tests/analyze_conversations.py -v conversations.json

    # Export sample format
    python3 tests/analyze_conversations.py --sample

    # Analyze from Backboard API thread directly
    python3 tests/analyze_conversations.py --thread THREAD_ID

Expected JSON format (array of messages):
[
    {"role": "user", "content": "...", "timestamp": "2025-03-11T10:00:00Z"},
    {"role": "assistant", "content": "...", "timestamp": "2025-03-11T10:00:05Z", "tool_calls": [...]},
    ...
]
"""

import json
import os
import re
import sys
import statistics
from collections import Counter, defaultdict
from pathlib import Path

try:
    import requests
except ImportError:
    requests = None

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

API_BASE = "https://app.backboard.io/api"

def load_api_key() -> str:
    key = os.environ.get("BACKBOARD_API_KEY")
    if key:
        return key
    plist_path = Path(__file__).resolve().parent.parent / "Focus" / "Config.plist"
    if plist_path.exists():
        try:
            import plistlib
            with open(plist_path, "rb") as f:
                plist = plistlib.load(f)
            key = plist.get("BACKBOARD_API_KEY", "")
            if key:
                return key
        except Exception:
            pass
    return ""


# ---------------------------------------------------------------------------
# Analysis patterns
# ---------------------------------------------------------------------------

# French emotional keywords that should trigger empathetic response
EMOTIONAL_KEYWORDS = {
    "high": [
        "déprimé", "dépression", "suicide", "mourir", "mort", "peur",
        "anxiété", "angoisse", "paniqué", "désespoir", "effondré",
        "pleure", "larmes", "détresse", "seul", "isolé", "abandonné",
    ],
    "medium": [
        "stressé", "fatigué", "épuisé", "triste", "mal", "difficile",
        "dur", "galère", "perdu", "confus", "frustré", "en colère",
        "dispute", "rupture", "séparation", "échec", "raté",
        "déçu", "honte", "coupable", "inquiet",
    ],
    "low": [
        "flemme", "bof", "pas envie", "la flemme", "pas motivé",
        "ennui", "ennuyé", "nul", "marre",
    ],
}

# Empathetic keywords the coach should use in emotional contexts
EMPATHY_MARKERS = [
    "comprends", "entends", "normal", "difficile", "dur",
    "là pour toi", "là si tu", "courage", "force",
    "sentiment", "ressens", "émotion",
]

# Minimization phrases (should NEVER appear in emotional contexts)
MINIMIZATION_PHRASES = [
    "ça va aller", "t'inquiète pas", "t'en fais pas",
    "c'est rien", "c'est pas grave", "détends-toi",
    "calme-toi", "relativise", "pense positif",
]

# Generic/filler phrases that suggest low-quality coaching
GENERIC_PHRASES = [
    "n'hésite pas", "n'hésites pas", "comment puis-je t'aider",
    "je suis là pour toi", "dis-moi tout", "raconte-moi",
    "je t'écoute", "parfait !", "super !",
]

# Proactive coaching markers
PROACTIVE_MARKERS = [
    "tu devrais", "essaie de", "je te propose", "pourquoi pas",
    "et si tu", "lance", "commence par", "ta priorité",
    "je te conseille", "focus sur", "concentre-toi",
]


# ---------------------------------------------------------------------------
# Message parsing
# ---------------------------------------------------------------------------

def load_from_file(path: str) -> list[dict]:
    """Load conversation messages from a JSON file."""
    with open(path) as f:
        data = json.load(f)

    if isinstance(data, list):
        return data
    if isinstance(data, dict) and "messages" in data:
        return data["messages"]
    raise ValueError(f"Unexpected JSON format in {path}")


def load_from_thread(thread_id: str) -> list[dict]:
    """Load messages from a Backboard thread via API."""
    if not requests:
        print("ERROR: 'requests' not installed. Run: pip3 install requests")
        sys.exit(1)

    api_key = load_api_key()
    if not api_key:
        print("ERROR: No API key found. Set BACKBOARD_API_KEY or check Config.plist")
        sys.exit(1)

    headers = {"X-API-Key": api_key, "Content-Type": "application/json"}
    resp = requests.get(f"{API_BASE}/threads/{thread_id}/messages", headers=headers, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    messages = data if isinstance(data, list) else data.get("messages", [])
    return messages


# ---------------------------------------------------------------------------
# Analysis functions
# ---------------------------------------------------------------------------

class ConversationAnalyzer:
    def __init__(self, messages: list[dict], verbose: bool = False):
        self.messages = messages
        self.verbose = verbose
        self.issues: list[dict] = []  # {severity, category, description, index}
        self.stats: dict = {}

    def analyze(self):
        """Run all analysis passes."""
        self._basic_stats()
        self._response_length_adaptation()
        self._emotional_intelligence()
        self._question_frequency()
        self._proactivity_ratio()
        self._generic_response_detection()
        self._tool_usage_patterns()
        self._repetition_detection()
        self._emoji_usage()
        self._follow_up_detection()

    def _user_messages(self) -> list[tuple[int, dict]]:
        return [(i, m) for i, m in enumerate(self.messages) if m.get("role") == "user"]

    def _assistant_messages(self) -> list[tuple[int, dict]]:
        return [(i, m) for i, m in enumerate(self.messages) if m.get("role") == "assistant"]

    def _get_response_for(self, user_msg_index: int) -> dict | None:
        """Get the assistant response that follows a user message."""
        for j in range(user_msg_index + 1, len(self.messages)):
            if self.messages[j].get("role") == "assistant":
                return self.messages[j]
            if self.messages[j].get("role") == "user":
                break  # No response before next user message
        return None

    # -- Basic stats --------------------------------------------------------

    def _basic_stats(self):
        user_msgs = self._user_messages()
        asst_msgs = self._assistant_messages()

        user_lengths = [len(m.get("content", "")) for _, m in user_msgs]
        asst_lengths = [len(m.get("content", "")) for _, m in asst_msgs]

        self.stats["total_messages"] = len(self.messages)
        self.stats["user_messages"] = len(user_msgs)
        self.stats["assistant_messages"] = len(asst_msgs)
        self.stats["avg_user_length"] = round(statistics.mean(user_lengths)) if user_lengths else 0
        self.stats["avg_assistant_length"] = round(statistics.mean(asst_lengths)) if asst_lengths else 0
        self.stats["max_assistant_length"] = max(asst_lengths) if asst_lengths else 0
        self.stats["min_assistant_length"] = min(asst_lengths) if asst_lengths else 0

    # -- Response length adaptation -----------------------------------------

    def _response_length_adaptation(self):
        """Check if response length adapts to user message length."""
        for i, user_msg in self._user_messages():
            response = self._get_response_for(i)
            if not response:
                continue

            user_len = len(user_msg.get("content", ""))
            resp_len = len(response.get("content", ""))

            # Long emotional message (>200 chars) should get >100 char response
            if user_len > 200 and resp_len < 60:
                self.issues.append({
                    "severity": "warning",
                    "category": "length_adaptation",
                    "description": f"Short response ({resp_len} chars) to long user message ({user_len} chars)",
                    "index": i,
                    "user_excerpt": user_msg.get("content", "")[:80],
                    "response_excerpt": response.get("content", "")[:80],
                })

            # Very short message (< 20 chars) should get concise response (< 500 chars)
            if user_len < 20 and resp_len > 500:
                self.issues.append({
                    "severity": "info",
                    "category": "length_adaptation",
                    "description": f"Verbose response ({resp_len} chars) to short user message ({user_len} chars)",
                    "index": i,
                    "user_excerpt": user_msg.get("content", "")[:80],
                    "response_excerpt": response.get("content", "")[:80],
                })

    # -- Emotional intelligence ---------------------------------------------

    def _emotional_intelligence(self):
        """Check empathetic responses to emotional messages."""
        for i, user_msg in self._user_messages():
            content = user_msg.get("content", "").lower()
            response = self._get_response_for(i)
            if not response:
                continue

            resp_text = response.get("content", "").lower()

            # Detect emotional level
            emotional_level = None
            matched_words = []
            for level in ["high", "medium", "low"]:
                for word in EMOTIONAL_KEYWORDS[level]:
                    if word in content:
                        emotional_level = level
                        matched_words.append(word)
                if emotional_level:
                    break

            if not emotional_level:
                continue

            # Check for empathy markers in response
            has_empathy = any(m in resp_text for m in EMPATHY_MARKERS)

            # Check for minimization
            has_minimization = any(p in resp_text for p in MINIMIZATION_PHRASES)

            # Check for question (engaging)
            has_question = "?" in resp_text

            if emotional_level == "high":
                if has_minimization:
                    self.issues.append({
                        "severity": "critical",
                        "category": "emotional_intelligence",
                        "description": f"MINIMIZATION in response to high-distress message (keywords: {matched_words})",
                        "index": i,
                        "user_excerpt": content[:100],
                        "response_excerpt": resp_text[:100],
                    })
                if not has_empathy:
                    self.issues.append({
                        "severity": "warning",
                        "category": "emotional_intelligence",
                        "description": f"No empathy markers in response to high-distress message",
                        "index": i,
                        "user_excerpt": content[:100],
                        "response_excerpt": resp_text[:100],
                    })
                # Check for 3114 in truly dark moments
                if any(w in content for w in ["suicide", "mourir", "mort", "tout arrêter", "plus envie de vivre"]):
                    if "3114" not in resp_text:
                        self.issues.append({
                            "severity": "critical",
                            "category": "emotional_intelligence",
                            "description": "Missing crisis number (3114) in response to potential suicidal ideation",
                            "index": i,
                            "user_excerpt": content[:100],
                        })

            elif emotional_level == "medium":
                if has_minimization:
                    self.issues.append({
                        "severity": "warning",
                        "category": "emotional_intelligence",
                        "description": f"Minimization in response to emotional message (keywords: {matched_words})",
                        "index": i,
                        "user_excerpt": content[:100],
                        "response_excerpt": resp_text[:100],
                    })
                if not has_empathy and not has_question:
                    self.issues.append({
                        "severity": "info",
                        "category": "emotional_intelligence",
                        "description": f"No empathy or follow-up question for emotional message",
                        "index": i,
                        "user_excerpt": content[:100],
                    })

    # -- Question frequency -------------------------------------------------

    def _question_frequency(self):
        """Check how often the coach asks questions (should be ~60-80% of responses)."""
        asst_msgs = self._assistant_messages()
        if not asst_msgs:
            return

        with_questions = sum(1 for _, m in asst_msgs if "?" in m.get("content", ""))
        ratio = with_questions / len(asst_msgs)
        self.stats["question_ratio"] = round(ratio * 100)

        if ratio < 0.4:
            self.issues.append({
                "severity": "warning",
                "category": "engagement",
                "description": f"Low question frequency: {self.stats['question_ratio']}% (target: 60-80%). Coach may be too declarative.",
            })

    # -- Proactivity ratio --------------------------------------------------

    def _proactivity_ratio(self):
        """Check ratio of proactive suggestions vs passive responses."""
        asst_msgs = self._assistant_messages()
        if not asst_msgs:
            return

        proactive_count = 0
        for _, m in asst_msgs:
            content = m.get("content", "").lower()
            if any(marker in content for marker in PROACTIVE_MARKERS):
                proactive_count += 1

        ratio = proactive_count / len(asst_msgs)
        self.stats["proactivity_ratio"] = round(ratio * 100)

        if ratio < 0.2:
            self.issues.append({
                "severity": "info",
                "category": "coaching_quality",
                "description": f"Low proactivity: {self.stats['proactivity_ratio']}%. Coach mostly reacts instead of guiding.",
            })

    # -- Generic response detection -----------------------------------------

    def _generic_response_detection(self):
        """Detect responses that are too generic / filler."""
        for i, m in self._assistant_messages():
            content = m.get("content", "").lower()
            found_generic = [p for p in GENERIC_PHRASES if p in content]

            if len(found_generic) >= 2:
                self.issues.append({
                    "severity": "info",
                    "category": "coaching_quality",
                    "description": f"Generic response with {len(found_generic)} filler phrases: {found_generic}",
                    "index": i,
                    "response_excerpt": content[:120],
                })

    # -- Tool usage patterns ------------------------------------------------

    def _tool_usage_patterns(self):
        """Analyze tool usage frequency and patterns."""
        tool_counter = Counter()
        msgs_with_tools = 0

        for _, m in self._assistant_messages():
            tool_calls = m.get("tool_calls", [])
            if tool_calls:
                msgs_with_tools += 1
                for tc in tool_calls:
                    name = tc.get("function", {}).get("name", tc.get("name", "unknown"))
                    tool_counter[name] += 1

        self.stats["tool_usage"] = dict(tool_counter.most_common(10))
        self.stats["messages_with_tools"] = msgs_with_tools

        # Check if get_user_context is called on first message
        if self.messages and self.messages[0].get("role") == "user":
            first_response = self._get_response_for(0)
            if first_response:
                first_tools = first_response.get("tool_calls", [])
                first_tool_names = [tc.get("function", {}).get("name", tc.get("name", "")) for tc in first_tools]
                if "get_user_context" not in first_tool_names and "start_morning_flow" not in first_tool_names:
                    self.issues.append({
                        "severity": "warning",
                        "category": "tool_usage",
                        "description": "get_user_context not called on first message (expected per system prompt)",
                    })

    # -- Repetition detection -----------------------------------------------

    def _repetition_detection(self):
        """Detect if the coach repeats the same phrases across messages."""
        asst_contents = [m.get("content", "") for _, m in self._assistant_messages()]

        # Extract sentences (split by . ! ?)
        sentence_counter = Counter()
        for content in asst_contents:
            sentences = re.split(r'[.!?]+', content.strip())
            for s in sentences:
                s = s.strip().lower()
                if len(s) > 20:  # Only track meaningful sentences
                    sentence_counter[s] += 1

        repeated = {s: c for s, c in sentence_counter.items() if c >= 3}
        if repeated:
            self.stats["repeated_sentences"] = repeated
            self.issues.append({
                "severity": "warning",
                "category": "repetition",
                "description": f"Coach repeats {len(repeated)} sentence(s) 3+ times: {list(repeated.keys())[:3]}",
            })

    # -- Emoji usage --------------------------------------------------------

    def _emoji_usage(self):
        """Check emoji density (system prompt says max 1 per message)."""
        emoji_pattern = re.compile(
            "["
            "\U0001F600-\U0001F64F"  # Emoticons
            "\U0001F300-\U0001F5FF"  # Misc Symbols and Pictographs
            "\U0001F680-\U0001F6FF"  # Transport and Map
            "\U0001F1E0-\U0001F1FF"  # Flags
            "\U00002702-\U000027B0"
            "\U000024C2-\U0001F251"
            "]+",
            flags=re.UNICODE,
        )

        over_emoji_count = 0
        for i, m in self._assistant_messages():
            content = m.get("content", "")
            emojis = emoji_pattern.findall(content)
            if len(emojis) > 2:  # Allow some tolerance (1 recommended, 2 ok)
                over_emoji_count += 1
                if self.verbose:
                    self.issues.append({
                        "severity": "info",
                        "category": "style",
                        "description": f"Too many emojis ({len(emojis)}) in response (max recommended: 1)",
                        "index": i,
                        "response_excerpt": content[:80],
                    })

        if over_emoji_count > 0:
            self.stats["over_emoji_messages"] = over_emoji_count

    # -- Follow-up detection ------------------------------------------------

    def _follow_up_detection(self):
        """Check if the coach follows up on emotional topics in subsequent messages."""
        emotional_topics = []

        for i, user_msg in self._user_messages():
            content = user_msg.get("content", "").lower()
            for level in ["high", "medium"]:
                if any(w in content for w in EMOTIONAL_KEYWORDS[level]):
                    emotional_topics.append((i, level, content[:60]))
                    break

        # Check if later messages reference emotional topics
        # (Simple heuristic: look for topic keywords in next 3 assistant messages)
        missed_followups = 0
        for idx, level, excerpt in emotional_topics:
            # Get next 3 assistant messages after this
            following = []
            for j in range(idx + 1, min(idx + 8, len(self.messages))):
                if self.messages[j].get("role") == "assistant" and j > idx + 1:
                    following.append(self.messages[j])
                if len(following) >= 2:
                    break

            # Check if any following message references the topic
            topic_words = [w for w in excerpt.split() if len(w) > 4]
            has_followup = False
            for f_msg in following:
                f_content = f_msg.get("content", "").lower()
                if any(w in f_content for w in topic_words[:3]):
                    has_followup = True
                    break
                if any(m in f_content for m in ["comment", "mieux", "ça va", "sujet", "parlé"]):
                    has_followup = True
                    break

            if not has_followup and level in ("high", "medium"):
                missed_followups += 1

        if missed_followups > 0:
            self.stats["missed_emotional_followups"] = missed_followups
            self.issues.append({
                "severity": "info",
                "category": "emotional_intelligence",
                "description": f"Coach dropped {missed_followups} emotional topic(s) without follow-up in later messages",
            })

    # -- Report -------------------------------------------------------------

    def print_report(self):
        """Print the full analysis report."""
        print("\n" + "=" * 65)
        print("  CONVERSATION QUALITY ANALYSIS")
        print("=" * 65)

        # Stats
        print("\n📊 STATISTICS")
        print(f"  Total messages: {self.stats.get('total_messages', 0)}")
        print(f"  User messages: {self.stats.get('user_messages', 0)}")
        print(f"  Assistant messages: {self.stats.get('assistant_messages', 0)}")
        print(f"  Avg user message length: {self.stats.get('avg_user_length', 0)} chars")
        print(f"  Avg assistant response length: {self.stats.get('avg_assistant_length', 0)} chars")
        print(f"  Question ratio: {self.stats.get('question_ratio', '?')}%")
        print(f"  Proactivity ratio: {self.stats.get('proactivity_ratio', '?')}%")

        if self.stats.get("tool_usage"):
            print(f"\n🔧 TOP TOOLS USED")
            for tool, count in self.stats["tool_usage"].items():
                print(f"  {tool}: {count}x")

        if self.stats.get("repeated_sentences"):
            print(f"\n🔁 REPEATED SENTENCES")
            for sentence, count in list(self.stats["repeated_sentences"].items())[:5]:
                print(f"  ({count}x) \"{sentence[:60]}...\"")

        # Issues by severity
        print(f"\n{'='*65}")
        print(f"  ISSUES FOUND: {len(self.issues)}")
        print(f"{'='*65}")

        severity_order = {"critical": 0, "warning": 1, "info": 2}
        severity_icons = {"critical": "🔴", "warning": "⚠️", "info": "ℹ️"}
        sorted_issues = sorted(self.issues, key=lambda x: severity_order.get(x["severity"], 3))

        by_category = defaultdict(list)
        for issue in sorted_issues:
            by_category[issue["category"]].append(issue)

        for category, issues in by_category.items():
            print(f"\n  [{category.upper().replace('_', ' ')}]")
            for issue in issues:
                icon = severity_icons.get(issue["severity"], "•")
                print(f"    {icon} {issue['description']}")
                if self.verbose:
                    if "user_excerpt" in issue:
                        print(f"       User: \"{issue['user_excerpt']}\"")
                    if "response_excerpt" in issue:
                        print(f"       Response: \"{issue['response_excerpt']}\"")

        # Summary
        critical = sum(1 for i in self.issues if i["severity"] == "critical")
        warnings = sum(1 for i in self.issues if i["severity"] == "warning")
        infos = sum(1 for i in self.issues if i["severity"] == "info")

        print(f"\n{'='*65}")
        print(f"  SUMMARY: {critical} critical, {warnings} warnings, {infos} info")

        # Grade
        if critical > 0:
            grade = "D"
        elif warnings > 3:
            grade = "C"
        elif warnings > 0:
            grade = "B"
        else:
            grade = "A"

        question_ratio = self.stats.get("question_ratio", 0)
        proactivity = self.stats.get("proactivity_ratio", 0)

        if question_ratio > 60 and proactivity > 30 and grade in ("A", "B"):
            grade = "A" if grade == "A" else "B+"

        print(f"  GRADE: {grade}")
        print(f"{'='*65}\n")

        return critical == 0


# ---------------------------------------------------------------------------
# Sample export
# ---------------------------------------------------------------------------

SAMPLE_CONVERSATION = [
    {"role": "user", "content": "Salut", "timestamp": "2025-03-11T08:00:00Z"},
    {"role": "assistant", "content": "Salut TestUser ! 🌅 Comment tu te sens ce matin ?", "timestamp": "2025-03-11T08:00:03Z", "tool_calls": [{"function": {"name": "get_user_context"}}]},
    {"role": "user", "content": "Bien, j'ai bien dormi", "timestamp": "2025-03-11T08:01:00Z"},
    {"role": "assistant", "content": "Top ! T'as 3 tâches aujourd'hui. Par quoi tu commences ?", "timestamp": "2025-03-11T08:01:04Z", "tool_calls": [{"function": {"name": "get_today_tasks"}}]},
    {"role": "user", "content": "Je suis stressé par ma présentation de demain", "timestamp": "2025-03-11T08:05:00Z"},
    {"role": "assistant", "content": "Je comprends que la présentation te stresse. C'est normal quand c'est important. Tu l'as déjà préparée ou tu dois encore bosser dessus ?", "timestamp": "2025-03-11T08:05:05Z"},
    {"role": "user", "content": "J'ai fait la moitié", "timestamp": "2025-03-11T08:06:00Z"},
    {"role": "assistant", "content": "Ok, t'es déjà à mi-chemin, c'est bien. On lance 50 min de focus dessus pour finir le reste ?", "timestamp": "2025-03-11T08:06:04Z"},
]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Focus Coach — Conversation Quality Analyzer")
    parser.add_argument("input", nargs="?", help="JSON file with conversation messages")
    parser.add_argument("--thread", "-t", type=str, help="Backboard thread ID to fetch and analyze")
    parser.add_argument("--sample", action="store_true", help="Print sample JSON format and exit")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show detailed issue information")
    args = parser.parse_args()

    if args.sample:
        print(json.dumps(SAMPLE_CONVERSATION, indent=2, ensure_ascii=False))
        return

    messages = []

    if args.thread:
        print(f"Fetching messages from thread {args.thread}...")
        messages = load_from_thread(args.thread)
        print(f"Loaded {len(messages)} messages from Backboard API")
    elif args.input:
        messages = load_from_file(args.input)
        print(f"Loaded {len(messages)} messages from {args.input}")
    else:
        print("No input provided. Use --sample for format, or provide a JSON file / --thread ID")
        print("\nRunning on sample conversation for demo:\n")
        messages = SAMPLE_CONVERSATION

    if len(messages) < 2:
        print("Not enough messages to analyze (need at least 2)")
        sys.exit(1)

    analyzer = ConversationAnalyzer(messages, verbose=args.verbose)
    analyzer.analyze()
    ok = analyzer.print_report()
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
