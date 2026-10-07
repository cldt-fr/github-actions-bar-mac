import Foundation

struct Repository: Decodable, Hashable, Sendable {
    let fullName: String
    let archived: Bool?
    let pushedAt: Date?
}

struct RunRepository: Decodable, Hashable, Sendable {
    let fullName: String
    let name: String
}

struct Actor: Decodable, Hashable, Sendable {
    let login: String
}

struct WorkflowRun: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String?
    let displayTitle: String
    let headBranch: String?
    let status: String?
    let conclusion: String?
    let htmlUrl: URL
    let workflowId: Int
    let runNumber: Int
    let runAttempt: Int?
    let event: String
    let createdAt: Date
    let updatedAt: Date
    let runStartedAt: Date?
    let repository: RunRepository
    let actor: Actor?

    var isCompleted: Bool { status == "completed" }
    var startDate: Date { runStartedAt ?? createdAt }
    var duration: TimeInterval { updatedAt.timeIntervalSince(startDate) }
    var workflowName: String { name ?? "Workflow" }
}

struct WorkflowRunsResponse: Decodable, Sendable {
    let workflowRuns: [WorkflowRun]
}

struct Step: Decodable, Hashable, Sendable {
    let name: String
    let status: String
    let conclusion: String?
    let number: Int
}

struct Job: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: Date?
    let completedAt: Date?
    let htmlUrl: URL?
    let steps: [Step]?

    var currentStep: Step? { steps?.first { $0.status == "in_progress" } }

    /// Fraction of this job that is done, based on its steps.
    var progress: Double {
        if status == "completed" { return 1 }
        guard status == "in_progress", let steps, !steps.isEmpty else { return 0 }
        let done = Double(steps.filter { $0.status == "completed" }.count)
        let running = steps.contains { $0.status == "in_progress" } ? 0.5 : 0
        return min(1, (done + running) / Double(steps.count))
    }
}

struct JobsResponse: Decodable, Sendable {
    let jobs: [Job]
}

/// A run that is still going, together with its jobs.
struct ActiveRun: Identifiable, Hashable, Sendable {
    let run: WorkflowRun
    let jobs: [Job]
    /// Duration of the last successful run of the same workflow, used for an ETA.
    let referenceDuration: TimeInterval?

    var id: Int { run.id }

    var progress: Double {
        guard !jobs.isEmpty else { return 0 }
        return jobs.map(\.progress).reduce(0, +) / Double(jobs.count)
    }

    var completedJobs: Int { jobs.filter { $0.status == "completed" }.count }

    var hasFailedJob: Bool { jobs.contains { $0.conclusion == "failure" } }

    func remaining(at date: Date) -> TimeInterval? {
        guard let referenceDuration, run.status == "in_progress" else { return nil }
        let left = referenceDuration - date.timeIntervalSince(run.startDate)
        return left > 0 ? left : nil
    }
}
