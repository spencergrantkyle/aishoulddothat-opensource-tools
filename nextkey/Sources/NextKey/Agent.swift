import Foundation

enum Agent {
    struct Turn {
        let role: String
        let text: String
        let jpeg: Data?
    }

    static let systemPrompt = """
    You are NextKey, a macOS keyboard-shortcut navigator. The user pressed a hotkey mid-task. \
    You get a screenshot of their screen at that moment, the frontmost app and window title, \
    and their question. Tell them the exact keys to press next to do what they want without the mouse.

    Rules:
    - Ground the answer in the screenshot and the frontmost app. Shortcuts differ per app; give \
    that app's real macOS shortcuts (e.g. Excel for Mac, not Excel for Windows).
    - A plain "what's the shortcut for X" gets one shortcut and a short explanation. Add STEP lines \
    only if the obvious next move needs them.
    - If the user describes a goal, a task in progress or why they are doing it, forecast the full \
    key sequence as ordered STEP lines, as far as the keyboard can take them.
    - If no built-in shortcut exists, put the best keyboard route in KEYS (e.g. ⌘ ⇧ / to search \
    the Help menu, ⌃ F2 to focus the menu bar, Tab/arrow navigation) and mention in WHAT that \
    they can add one in System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts.
    - Never invent shortcuts. If you are not certain, say "likely" in WHAT.
    - Be terse.

    Output exactly this format. No markdown, no preamble, KEYS line first:
    KEYS: <primary keys>
    WHAT: <one or two short sentences>
    STEP: <keys> | <what it does>
    (0 to 6 STEP lines)

    Key notation: ⌘ ⌥ ⌃ ⇧ fn, ⏎ Return, ⎋ Escape, ⇥ Tab, ⌫ Delete, ⌦ Forward Delete, Space, \
    ← → ↑ ↓, F1–F12, uppercase letters. Separate keys within one chord with single spaces \
    (⌘ ⇧ T). Separate chords pressed one after another with " → " (⌃ F2 → ↓ → ⏎).
    """

    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        return URLSession(configuration: c)
    }()

    /// Opens the TLS connection while the user types, so the real request skips the handshake.
    static func warmUp() {
        guard let key = ConfigStore.apiKey else { return }
        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/key")!)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        session.dataTask(with: req).resume()
    }

    static func stream(history: [Turn], model: String, apiKey: String,
                       reasoningEffort: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = URLRequest(url: endpoint)
                    req.httpMethod = "POST"
                    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("NextKey", forHTTPHeaderField: "X-Title")
                    req.httpBody = try JSONSerialization.data(withJSONObject: body(history, model, reasoningEffort))

                    let (bytes, response) = try await session.bytes(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var text = ""
                        for try await line in bytes.lines { text += line }
                        throw AgentError.http(http.statusCode, errorMessage(text) ?? text)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }  // skips ": OPENROUTER PROCESSING"
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        if let err = obj["error"] as? [String: Any] {
                            throw AgentError.api(err["message"] as? String ?? "Unknown error")
                        }
                        if let choices = obj["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func body(_ history: [Turn], _ model: String, _ effort: String?) -> [String: Any] {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for turn in history {
            if let jpeg = turn.jpeg {
                messages.append(["role": turn.role, "content": [
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())"]],
                    ["type": "text", "text": turn.text],
                ]])
            } else {
                messages.append(["role": turn.role, "content": turn.text])
            }
        }
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "max_tokens": 600,
            "temperature": 0.2,
            "provider": ["sort": "latency"],
        ]
        // Both default models reason unless told not to, which adds seconds before the first
        // token and can burn max_tokens before any answer. Off unless config sets an effort.
        if let effort, !effort.isEmpty {
            body["reasoning"] = ["effort": effort]
        } else if model.hasPrefix("openai/") {
            body["reasoning"] = ["effort": "none"]
        } else {
            body["reasoning"] = ["enabled": false]
        }
        return body
    }

    private static func errorMessage(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return nil }
        return err["message"] as? String
    }
}

enum AgentError: LocalizedError {
    case http(Int, String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .http(401, _): return "OpenRouter rejected the API key (401). Check ~/projects/NextKey/.env."
        case .http(let code, let msg): return "OpenRouter error \(code): \(msg)"
        case .api(let msg): return "OpenRouter: \(msg)"
        }
    }
}

/// The model's reply, parsed from the KEYS / WHAT / STEP line format. Tolerates partial
/// (still-streaming) text and falls back to showing raw text if the model ignores the format.
struct Answer {
    struct Step { let keys: String; let text: String }

    var keys = ""
    var what = ""
    var steps: [Step] = []

    static func parse(_ raw: String) -> Answer {
        var answer = Answer()
        var section = ""
        for line in raw.replacingOccurrences(of: "**", with: "").components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if let v = value(t, "KEYS:") {
                answer.keys = v; section = "keys"
            } else if let v = value(t, "WHAT:") {
                answer.what = v; section = "what"
            } else if let v = value(t, "STEP:") {
                // Keep empty pieces: mid-stream "STEP:" has no value yet, and split would return [].
                let parts = v.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                let step = Step(keys: parts[0], text: parts.count > 1 ? parts[1] : "")
                if !step.keys.isEmpty || !step.text.isEmpty { answer.steps.append(step) }
                section = "step"
            } else if section == "what" || section == "" {
                answer.what += (answer.what.isEmpty ? "" : " ") + t
            }
        }
        return answer
    }

    private static func value(_ line: String, _ prefix: String) -> String? {
        guard line.uppercased().hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }
}
