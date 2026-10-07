import AppKit
import SwiftUI

struct MenuContentView: View {
    @Environment(RunStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                SettingsView(settings: store.settings) { showSettings = false }
            } else {
                runList
            }
            Divider()
            footer
        }
        .frame(width: 380)
        // Opaque background: the default popover material is too see-through on recent macOS.
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text(showSettings ? "Réglages" : "GitHub Actions")
                .font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Rafraîchir")
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "xmark" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Réglages")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var runList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08))
                }

                SectionHeader(title: "En cours", count: store.active.count)
                if store.active.isEmpty {
                    Text(store.lastUpdate == nil ? "Chargement…" : "Aucun workflow en cours")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                } else {
                    ForEach(store.active) { item in
                        ActiveRunRow(item: item)
                        Divider().padding(.leading, 12)
                    }
                }

                if !store.recent.isEmpty {
                    SectionHeader(title: "Récents", count: nil)
                    ForEach(store.recent) { run in
                        RecentRunRow(run: run)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let lastUpdate = store.lastUpdate {
                    Text("Mis à jour \(lastUpdate.formatted(date: .omitted, time: .standard))")
                }
                Text("\(store.watchedRepos.count) dépôts suivis"
                    + (store.rateRemaining.map { " · API : \($0) restants" } ?? ""))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Quitter") { NSApp.terminate(nil) }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int?

    var body: some View {
        HStack {
            Text(title.uppercased())
            if let count, count > 0 {
                Text("\(count)")
                    .padding(.horizontal, 5)
                    .background(.quaternary, in: Capsule())
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct StatusIcon: View {
    let status: String?
    let conclusion: String?

    var body: some View {
        Image(systemName: RunStatus.symbol(status: status, conclusion: conclusion))
            .foregroundStyle(RunStatus.color(status: status, conclusion: conclusion))
            .help(RunStatus.label(status: status, conclusion: conclusion))
    }
}

private struct ActiveRunRow: View {
    let item: ActiveRun
    @State private var expanded = false
    @State private var hovering = false

    private var run: WorkflowRun { item.run }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                StatusIcon(status: run.status, conclusion: run.conclusion)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.workflowName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text("\(run.repository.name) · \(run.headBranch ?? run.event)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Format.duration(context.date.timeIntervalSince(run.startDate)))
                            .font(.callout.monospacedDigit())
                        if let remaining = item.remaining(at: context.date) {
                            Text("~\(Format.duration(remaining)) restantes")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text(run.displayTitle)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            ProgressView(value: item.progress)
                .tint(item.hasFailedJob ? .red : .accentColor)
                .animation(.easeInOut, value: item.progress)

            HStack {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !item.jobs.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                    } label: {
                        Label("Jobs", systemImage: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.jobs) { job in
                        JobRow(job: job)
                    }
                }
                .padding(.leading, 26)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hovering ? Color.primary.opacity(0.05) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { NSWorkspace.shared.open(run.htmlUrl) }
    }

    private var summary: String {
        let status = RunStatus.label(status: run.status, conclusion: run.conclusion)
        guard !item.jobs.isEmpty else { return status }
        return "\(item.completedJobs)/\(item.jobs.count) jobs · \(Int((item.progress * 100).rounded()))%"
    }
}

private struct JobRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 6) {
            StatusIcon(status: job.status, conclusion: job.conclusion)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(job.name)
                    .font(.caption)
                    .lineLimit(1)
                if let step = job.currentStep {
                    Text(step.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let startedAt = job.startedAt {
                if let completedAt = job.completedAt {
                    Text(Format.duration(completedAt.timeIntervalSince(startedAt)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Format.duration(context.date.timeIntervalSince(startedAt)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = job.htmlUrl { NSWorkspace.shared.open(url) }
        }
    }
}

private struct RecentRunRow: View {
    let run: WorkflowRun
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            StatusIcon(status: run.status, conclusion: run.conclusion)
            VStack(alignment: .leading, spacing: 1) {
                Text(run.workflowName)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(run.repository.name) · \(run.headBranch ?? run.event)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(run.updatedAt.formatted(.relative(presentation: .named)))
                Text(Format.duration(run.duration))
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(hovering ? Color.primary.opacity(0.05) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { NSWorkspace.shared.open(run.htmlUrl) }
        .help(run.displayTitle)
    }
}
