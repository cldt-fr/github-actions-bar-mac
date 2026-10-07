import Foundation
import Observation

@MainActor
@Observable
final class RunStore {
    let settings: AppSettings

    private(set) var active: [ActiveRun] = []
    private(set) var recent: [WorkflowRun] = []
    private(set) var watchedRepos: [String] = []
    private(set) var lastUpdate: Date?
    private(set) var errorMessage: String?
    private(set) var rateRemaining: Int?
    private(set) var tokenSource: TokenSource = .none
    private(set) var isRefreshing = false

    @ObservationIgnored private var client: GitHubClient?
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var reposFetchedAt: Date?
    @ObservationIgnored private var knownActiveIDs: Set<Int> = []
    @ObservationIgnored private var hasLoadedOnce = false

    /// How long the auto-discovered repository list is reused.
    private let repoListTTL: TimeInterval = 5 * 60
    /// Runs stuck in a non-completed state for longer than this are ignored.
    private let staleRunAge: TimeInterval = 24 * 3600

    init(settings: AppSettings) {
        self.settings = settings
        start()
    }

    // MARK: - Derived state for the menu bar

    var overallProgress: Double {
        guard !active.isEmpty else { return 0 }
        return active.map(\.progress).reduce(0, +) / Double(active.count)
    }

    var lastConclusion: String? { recent.first?.conclusion }

    // MARK: - Polling

    func start() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                let delay = self.active.isEmpty ? self.settings.idleInterval : self.settings.activeInterval
                try? await Task.sleep(for: .seconds(max(delay, 2)))
            }
        }
    }

    /// Drops the client and the repository list, e.g. after the settings changed.
    func reload() {
        client = nil
        reposFetchedAt = nil
        start()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let client = try await currentClient()
            if reposFetchedAt == nil || Date().timeIntervalSince(reposFetchedAt!) > repoListTTL {
                watchedRepos = try await discoverRepos(client)
                reposFetchedAt = Date()
            }

            let runs = try await fetchRuns(client, repos: watchedRepos)
            let cutoff = Date().addingTimeInterval(-staleRunAge)
            let running = runs
                .filter { !$0.isCompleted && $0.createdAt > cutoff }
                .sorted { $0.createdAt > $1.createdAt }
            let completed = runs
                .filter(\.isCompleted)
                .sorted { $0.updatedAt > $1.updatedAt }

            let jobsByRun = await fetchJobs(client, runs: running)
            active = running.map { run in
                let reference = completed.first { $0.workflowId == run.workflowId && $0.conclusion == "success" }
                return ActiveRun(run: run, jobs: jobsByRun[run.id] ?? [], referenceDuration: reference?.duration)
            }
            recent = Array(completed.prefix(8))

            notifyFinishedRuns(running: running, completed: completed)

            rateRemaining = await client.rateRemaining
            lastUpdate = Date()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            if case GitHubError.unauthorized = error {
                client = nil
            }
        }
    }

    private func currentClient() async throws -> GitHubClient {
        if let client { return client }
        guard let resolved = await TokenProvider.resolve() else {
            tokenSource = .none
            throw GitHubError.noToken
        }
        tokenSource = resolved.source
        let client = GitHubClient(token: resolved.token)
        self.client = client
        return client
    }

    private func discoverRepos(_ client: GitHubClient) async throws -> [String] {
        var names: [String] = settings.pinnedRepos
        if settings.autoDiscover {
            let repos = try await client.recentlyPushedRepos(limit: settings.autoDiscoverCount)
            names += repos.filter { $0.archived != true }.map(\.fullName)
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Fetches the latest runs of every repository. Repositories that fail
    /// (Actions disabled, no access…) are skipped unless they all fail.
    private func fetchRuns(_ client: GitHubClient, repos: [String]) async throws -> [WorkflowRun] {
        let results = await withTaskGroup(of: Result<[WorkflowRun], Error>.self) { group in
            for repo in repos {
                group.addTask {
                    do { return .success(try await client.runs(repo: repo)) } catch { return .failure(error) }
                }
            }
            var results: [Result<[WorkflowRun], Error>] = []
            for await result in group { results.append(result) }
            return results
        }

        var runs: [WorkflowRun] = []
        var firstError: Error?
        for result in results {
            switch result {
            case .success(let repoRuns): runs += repoRuns
            case .failure(let error): firstError = firstError ?? error
            }
        }
        if let firstError, runs.isEmpty, !repos.isEmpty,
           results.allSatisfy({ if case .failure = $0 { true } else { false } }) {
            throw firstError
        }
        if case GitHubError.unauthorized? = firstError {
            throw GitHubError.unauthorized
        }
        return runs
    }

    private func fetchJobs(_ client: GitHubClient, runs: [WorkflowRun]) async -> [Int: [Job]] {
        await withTaskGroup(of: (Int, [Job]?).self) { group in
            for run in runs {
                group.addTask {
                    (run.id, try? await client.jobs(repo: run.repository.fullName, runID: run.id))
                }
            }
            var jobs: [Int: [Job]] = [:]
            for await (id, runJobs) in group {
                // Keep the previous jobs if this request failed, so progress doesn't jump back to 0.
                jobs[id] = runJobs ?? active.first { $0.id == id }?.jobs
            }
            return jobs
        }
    }

    private func notifyFinishedRuns(running: [WorkflowRun], completed: [WorkflowRun]) {
        let runningIDs = Set(running.map(\.id))
        defer {
            knownActiveIDs = runningIDs
            hasLoadedOnce = true
        }
        guard hasLoadedOnce, settings.notificationsEnabled else { return }
        for id in knownActiveIDs.subtracting(runningIDs) {
            if let run = completed.first(where: { $0.id == id }) {
                Notifier.notifyCompletion(of: run)
            }
        }
    }
}
