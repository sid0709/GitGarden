import SwiftUI
import SwiftData

struct PersonasView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var selected: PersistentIdentifier?

    private var filtered: [PersonaRecord] {
        guard !search.isEmpty else { return personas }
        return personas.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.personaID.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Voices")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    Spacer()
                    Button {
                        let record = PersonaRecord(
                            personaID: "custom-\(Int(Date().timeIntervalSince1970))",
                            name: "Custom",
                            yamlBody: PersonaCatalog.rustaceanYAML,
                            isBundled: false
                        )
                        runtime.context.insert(record)
                        try? runtime.context.save()
                        selected = record.persistentModelID
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SKTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(SKTheme.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(filtered) { persona in
                            Button {
                                withAnimation(SKMotion.spring) {
                                    selected = persona.persistentModelID
                                }
                            } label: {
                                SKFilmRow(selected: selected == persona.persistentModelID) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(persona.name)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SKTheme.inkColor(for: scheme))
                                        SKTag(kind: persona.isBundled ? .ui : .ux, label: persona.isBundled ? "Bundled" : "Custom")
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 260)
            .background(SKTheme.railColor(for: scheme))
            .overlay(alignment: .trailing) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }

            if let persona = personas.first(where: { $0.persistentModelID == selected }) ?? filtered.first {
                PersonaEditorView(persona: persona)
                    .id(persona.persistentModelID)
            } else {
                ContentUnavailableView("Select a persona", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { if selected == nil { selected = personas.first?.persistentModelID } }
    }
}

struct PersonaEditorView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.colorScheme) private var scheme
    @Bindable var persona: PersonaRecord
    @State private var draft = ""
    @State private var parseError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $persona.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(SKTheme.canvasColor(for: scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .padding(24)
        .onAppear { draft = persona.yamlBody }
        .onChange(of: persona.personaID) { _, _ in
            draft = persona.yamlBody
            parseError = nil
        }
    }
}
