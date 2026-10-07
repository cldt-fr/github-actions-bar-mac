import Foundation
import Security

enum TokenSource: Equatable {
    case none
    case manual
    case githubCLI

    var label: String {
        switch self {
        case .none: "Aucun token"
        case .manual: "Token personnel (Keychain)"
        case .githubCLI: "GitHub CLI (gh auth token)"
        }
    }
}

enum TokenProvider {
    /// Manual token first, then the GitHub CLI.
    static func resolve() async -> (token: String, source: TokenSource)? {
        if let token = Keychain.read(), !token.isEmpty {
            return (token, .manual)
        }
        if let token = await ghToken() {
            return (token, .githubCLI)
        }
        return nil
    }

    /// GUI apps don't inherit the shell PATH, so look for `gh` in the usual places.
    private static func ghToken() async -> String? {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return nil
        }
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["auth", "token"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = Pipe()
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        }.value
    }
}

enum Keychain {
    private static let service = "fr.cldt.ActionsBar"
    private static let account = "github-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ token: String) {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
