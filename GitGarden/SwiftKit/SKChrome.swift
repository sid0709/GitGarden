import SwiftUI

struct SKIconRail: View {
    @Binding var selection: SidebarItem
    @Namespace private var ns
    @Environment(\.colorScheme) private var scheme

    private var mainItems: [SidebarItem] {
        [.garden, .campaigns, .queue, .accounts, .personas, .audit]
    }

    var body: some View {
        VStack(spacing: 18) {
            SKMeshBlob(size: 38)
                .skGlow()
                .padding(.top, 36)
                .help("GitGarden")

            VStack(spacing: 10) {
                ForEach(mainItems) { item in
                    railButton(item)
                }
            }

            Spacer()

            railButton(.settings)
                .padding(.bottom, 18)
        }
        .frame(width: SKTheme.railWidth)
        .background(SKTheme.railColor(for: scheme))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SKTheme.hairline)
                .frame(width: 1)
        }
    }

    private func railButton(_ item: SidebarItem) -> some View {
        let selected = selection == item
        return Button {
            withAnimation(SKMotion.spring) { selection = item }
        } label: {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SKTheme.accentSoft)
                        .frame(width: 42, height: 42)
                        .matchedGeometryEffect(id: "rail-pill", in: ns)
                }
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? SKTheme.accent : SKTheme.mute)
                    .frame(width: 42, height: 42)
            }
        }
        .buttonStyle(.plain)
        .help(item.title)
    }
}

struct SKTopBar: View {
    var title: String
    var subtitle: String?
    @Binding var search: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("🌿")
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SKTheme.inkColor(for: scheme))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
            Spacer()
            SKSearchField(text: $search)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(SKTheme.canvasColor(for: scheme))
    }
}

struct SKPage<Content: View>: View {
    var spacing: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 32)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SKMetricChip: View {
    var title: String
    var value: String
    var kind: SKTagKind
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            SKTag(kind: kind)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKTheme.cardColor(for: scheme), in: RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous)
                .stroke(SKTheme.hairline, lineWidth: 1)
        }
    }
}

struct SKFilmRow<Content: View>: View {
    var selected: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? SKTheme.accentSoft : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? SKTheme.accent : Color.clear, lineWidth: selected ? 1.5 : 0)
            }
    }
}

struct SKRateBar: View {
    var remaining: Int
    var limit: Int

    var body: some View {
        let fraction = limit == 0 ? 0 : min(1, Double(remaining) / Double(limit))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Rate limit")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                Spacer()
                Text("\(remaining) / \(limit)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SKTheme.hairline)
                    Capsule()
                        .fill(fraction < 0.12 ? SKTheme.coral : SKTheme.accent)
                        .frame(width: max(8, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
    }
}
