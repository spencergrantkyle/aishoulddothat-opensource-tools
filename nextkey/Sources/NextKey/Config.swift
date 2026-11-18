import Foundation

/// User settings at ~/.config/nextkey/config.json. Every field is optional.
struct Config: Codable {
    var model: String?
    var hotkey: String?
    var reasoningEffort: String?
    var maxImageDimension: Int?
}

enum ConfigStore {
    static let defaultModel = "openai/gpt-6-luna"
    static let defaultHotkey = "cmd+opt+/"
    static let models: [(name: String, id: String)] = [
        ("Claude Haiku 5.5", "anthropic/claude-haiku-5.5"),
        ("GPT-6 Luna", "openai/gpt-6-luna"),
    ]

    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/nextkey")
    static let configURL = dir.appendingPathComponent("config.json")
    static let envURL = dir.appendingPathComponent(".env")

    static func load() -> Config {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = try? Data(contentsOf: configURL),
              let config = try? dec.decode(Config.self, from: data) else { return Config() }
        return config
    }

    static func save(_ config: Config) {
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? enc.encode(config).write(to: configURL, options: .atomic)
    }

    /// Key lookup order: OPENROUTER_API_KEY in the environment, then ~/.config/nextkey/.env.
    static var apiKey: String? {
        if let k = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !k.isEmpty { return k }
        guard let text = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0] == "OPENROUTER_API_KEY" else { continue }
            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    static func saveAPIKey(_ key: String) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = "OPENROUTER_API_KEY=\(key)\n"
        // Write through a symlink if one exists, so the project .env stays the source.
        let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: envURL.path))
            .map { URL(fileURLWithPath: $0) } ?? envURL
        try? text.write(to: target, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
    }
}
