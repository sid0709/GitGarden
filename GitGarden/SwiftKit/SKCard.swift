import SwiftUI

struct SKCard<Content: View>: View {
    var padding: CGFloat = 16
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKTheme.cardColor(for: scheme), in: RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous)
                .stroke(SKTheme.hairline, lineWidth: 1)
        }
    }
}

struct SKGhostCard: View {
    var title: String = "+ Card"
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(SKTheme.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SKTheme.cardColor(for: scheme).opacity(0.7))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SKTheme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct SKTag: View {
    var kind: SKTagKind
    var label: String?

    var body: some View {
        HStack(spacing: 4) {
            if kind == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(label ?? kind.title)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(kind.tint.opacity(0.12), in: Capsule())
    }
}

struct SKAvatar: View {
    var url: String
    var name: String
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: URL(string: url)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(SKTheme.accentSoft)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(SKTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

struct SKAvatarStack: View {
    var people: [(url: String, name: String)]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(people.prefix(3).enumerated()), id: \.offset) { _, person in
                SKAvatar(url: person.url, name: person.name, size: 26)
            }
        }
    }
}

struct SKSearchField: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SKTheme.mute)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: 220)
        .background(SKTheme.searchFill(for: scheme), in: Capsule())
        .overlay(Capsule().stroke(SKTheme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
}

struct SKPrimaryButton: View {
    var title: String
    var destructive: Bool = false
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(enabled ? (destructive ? SKTheme.coral : SKTheme.accent) : SKTheme.mute, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SKQuietButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(SKTheme.inkColor(for: scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(SKTheme.cardColor(for: scheme), in: Capsule())
                .overlay(Capsule().stroke(SKTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
