import SwiftUI
import SwiftData

struct PersonasView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var selected: PersonaRecord.ID?
    @State private var draft = ""
    @State private var parseError: String?

    private var filtered: [PersonaRecord] {
        guard !search.isEmpty else { return personas }
        return personas.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.personaID.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SKBoard {
                SKKanbanColumn(title: "Personas", count: filtered.count) {
                    ForEach(filtered) { persona in
                        Button {
                            withAnimation(SKMotion.spring) {
                                selected = persona.id
                                draft = persona.yamlBody
                                parseError = nil
                            }
                        } label: {
                            SKCard(rotateOnHover: true) {
                                Text(persona.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(SKTheme.ink)
                                Text(persona.personaID)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(SKTheme.mute)
                                SKTag(kind: persona.isBundled ? .ui : .ux, label: persona.isBundled ? "Bundled" : "Custom")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    SKGhostCard(title: "+ Persona") {
                        let record = PersonaRecord(
                            personaID: "custom-\(Int(Date().timeIntervalSince1970))",
                            name: "Custom",
                            yamlBody: PersonaCatalog.rustaceanYAML,
                            isBundled: false
                        )
                        runtime.context.insert(record)
                        try? runtime.context.save()
                    }
                }
            }
            if let persona = personas.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Name", text: Bindable(persona).name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)
                    TextEditor(text: $draft)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(SKTheme.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if let parseError {
                        Text(parseError).foregroundStyle(SKTheme.coral)
                    }
                    HStack {
                        SKPrimaryButton(title: "Save YAML") {
                            do {
                                _ = try SimpleYAML.parse(draft)
                                persona.yamlBody = draft
                                persona.updatedAt = Date()
                                try runtime.context.save()
                                parseError = nil
                            } catch {
                                parseError = error.localizedDescription
                            }
                        }
                        Spacer()
                        Text(persona.isBundled ? "Bundled template" : "Custom")
                            .foregroundStyle(SKTheme.mute)
                    }
                }
                .padding(22)
                .frame(minWidth: 420)
                .background(SKTheme.railColor(for: scheme))
                .overlay(alignment: .leading) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }
            }
        }
    }
}
