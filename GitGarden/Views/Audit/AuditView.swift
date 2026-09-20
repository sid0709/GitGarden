import SwiftUI
import SwiftData

struct AuditView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Query(sort: \AuditEvent.timestamp, order: .reverse) private var events: [AuditEvent]
    @State private var page = 0
    @State private var confirmClear = false

    private var filtered: [AuditEvent] {
        guard !search.isEmpty else { return events }
        return events.filter {
            $0.path.localizedCaseInsensitiveContains(search)
            || $0.accountLogin.localizedCaseInsensitiveContains(search)
            || $0.message.localizedCaseInsensitiveContains(search)
            || $0.method.localizedCaseInsensitiveContains(search)
            || $0.campaignName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        SKPage {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Console")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Live job log. Dismiss a line or clear the buffer.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                }
                Spacer()
                SKQuietButton(title: "Clear") { confirmClear = true }
                    .disabled(events.isEmpty)
            }

            AuditTerminal(
                events: SKPaging.slice(filtered, page: page),
                emptyHint: search.isEmpty ? "waiting for jobs…" : "no matching lines"
            ) { event in
                runtime.dismissAudit(event)
            }

            SKPagerBar(page: $page, total: filtered.count, noun: "lines")
        }
        .onChange(of: search) { _, _ in page = 0 }
        .onChange(of: filtered.count) { _, count in
            let pages = SKPaging.pageCount(total: count)
            if page >= pages { page = max(0, pages - 1) }
        }
        .alert("Clear console?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                runtime.clearAudit()
                page = 0
            }
        } message: {
            Text("Removes every GitGarden log line. This does not touch GitHub.")
        }
    }
}

private struct AuditTerminal: View {
    var events: [AuditEvent]
    var emptyHint: String
    var dismiss: (AuditEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(SKTheme.coral).frame(width: 8, height: 8)
                Circle().fill(SKTheme.peach).frame(width: 8, height: 8)
                Circle().fill(Color(red: 0.31, green: 0.72, blue: 0.45)).frame(width: 8, height: 8)
                Text("gitgarden — audit")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                Text("\(events.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))

            if events.isEmpty {
                Text("❯ \(emptyHint)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(events) { event in
                        AuditLogLine(event: event) {
                            dismiss(event)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(red: 0.07, green: 0.07, blue: 0.09),
            in: RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous)
                .stroke(SKTheme.hairline, lineWidth: 1)
        }
    }
}

private struct AuditLogLine: View {
    var event: AuditEvent
    var dismiss: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("❯")
                .foregroundStyle(promptColor)
            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                .foregroundStyle(Color.white.opacity(0.38))
            Text(event.method)
                .foregroundStyle(Color(red: 0.55, green: 0.82, blue: 1.0))
                .frame(minWidth: 44, alignment: .leading)
            Text(statusLabel)
                .foregroundStyle(statusColor)
                .frame(minWidth: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.path)
                    .foregroundStyle(Color.white.opacity(0.88))
                if !meta.isEmpty {
                    Text(meta)
                        .foregroundStyle(Color.white.opacity(0.38))
                }
                if !event.message.isEmpty {
                    Text(event.message)
                        .foregroundStyle(event.statusCode >= 400 ? SKTheme.coral : Color.white.opacity(0.55))
                }
            }
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(hovering ? 0.85 : 0.35))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(hovering ? 0.12 : 0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Dismiss", role: .destructive, action: dismiss)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.method) \(statusLabel) \(event.path)")
        .accessibilityHint("Dismiss this notification")
        .accessibilityAction(named: "Dismiss", dismiss)
    }

    private var statusLabel: String {
        event.statusCode == 0 ? "ok" : "\(event.statusCode)"
    }

    private var statusColor: Color {
        if event.statusCode == 0 || (200..<400).contains(event.statusCode) {
            return Color(red: 0.45, green: 0.86, blue: 0.58)
        }
        return SKTheme.coral
    }

    private var promptColor: Color {
        event.statusCode >= 400 ? SKTheme.coral : Color(red: 0.45, green: 0.86, blue: 0.58)
    }

    private var meta: String {
        [event.accountLogin, event.campaignName]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
