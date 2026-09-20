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

struct SKColumnHeader: View {
    var title: String
    var count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            Text("\(count)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(SKTheme.mute.opacity(0.7))
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(SKTheme.mute.opacity(0.6))
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 4)
    }
}

struct SKKanbanColumn<Content: View>: View {
    var title: String
    var count: Int
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SKColumnHeader(title: title, count: count)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    content
                }
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 260, maxWidth: 340, alignment: .top)
    }
}

struct SKBoard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}
