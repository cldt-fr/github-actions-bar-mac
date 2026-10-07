import Foundation

enum GitHubError: LocalizedError {
    case noToken
    case unauthorized
    case rateLimited(reset: Date?)
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            "Aucun token GitHub. Connecte-toi avec `gh auth login` ou renseigne un token dans les réglages."
        case .unauthorized:
            "Token GitHub invalide ou expiré."
        case .rateLimited(let reset):
            if let reset {
                "Limite d'API atteinte, reprise \(reset.formatted(.relative(presentation: .named)))."
            } else {
                "Limite d'API GitHub atteinte."
            }
        case .http(let status, let message):
            "Erreur GitHub \(status) : \(message)"
        }
    }
}

/// Minimal GitHub REST client. Uses conditional requests (ETag) so that
/// unchanged responses come back as 304 and don't count against the rate limit.
actor GitHubClient {
    private let token: String
    private let session: URLSession
    private var cache: [URL: (etag: String, data: Data)] = [:]
    private(set) var rateRemaining: Int?

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: config)
    }

    func recentlyPushedRepos(limit: Int) async throws -> [Repository] {
        try await get("/user/repos", [
            "sort": "pushed",
            "per_page": String(limit),
            "affiliation": "owner,collaborator,organization_member",
        ])
    }

    func runs(repo: String, perPage: Int = 10) async throws -> [WorkflowRun] {
        let response: WorkflowRunsResponse = try await get(
            "/repos/\(repo)/actions/runs", ["per_page": String(perPage)])
        return response.workflowRuns
    }

    func jobs(repo: String, runID: Int) async throws -> [Job] {
        let response: JobsResponse = try await get(
            "/repos/\(repo)/actions/runs/\(runID)/jobs", ["per_page": "100", "filter": "latest"])
        return response.jobs
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "https://api.github.com" + path)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let url = components.url!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ActionsBar", forHTTPHeaderField: "User-Agent")
        if let cached = cache[url] {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.http(status: 0, message: "Réponse invalide")
        }
        if let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init) {
            rateRemaining = remaining
        }

        let body: Data
        switch http.statusCode {
        case 304:
            guard let cached = cache[url] else { throw GitHubError.http(status: 304, message: "Cache manquant") }
            body = cached.data
        case 200..<300:
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                cache[url] = (etag, data)
            }
            body = data
        case 401:
            throw GitHubError.unauthorized
        case 403 where rateRemaining == 0, 429:
            let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:))
            throw GitHubError.rateLimited(reset: reset)
        default:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
            throw GitHubError.http(status: http.statusCode, message: message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: body)
    }
}
