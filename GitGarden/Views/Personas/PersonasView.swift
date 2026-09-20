import SwiftUI
import SwiftData

struct PersonasView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var selected: PersistentIdentifier?
    @State private var pendingDelete: PersonaRecord?

    private var filtered: [PersonaRecord] {
        guard !search.isEmpty else { return personas }
        return personas.filter {
            $0.name.localizedCaseInsensitiveContains(search)
            || $0.personaID.localizedCaseInsensitiveContains(search)
            || $0.yamlBody.localizedCaseInsensitiveContains(search)
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
                        select(runtime.createPersona(copying: selectedRecord))
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SKTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(SKTheme.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("New persona")
                }
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
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
                                        Text(persona.personaID)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(SKTheme.mute)
                                            .lineLimit(1)
                                        SKTag(
                                            kind: persona.isBundled ? .ui : .ux,
                                            label: persona.isBundled ? "Bundled" : "Custom"
                                        )
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .skFillWidth()
                            .contextMenu {
                                Button("Duplicate") {
                                    select(runtime.createPersona(copying: persona))
                                }
                                Button("Delete", role: .destructive) {
                                    pendingDelete = persona
                                }
                            }
                        }
                        if filtered.isEmpty {
                            Text(personas.isEmpty ? "No voices yet" : "No matches")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                                .padding(.top, 12)
                        }
                    }
                    .skFillWidth()
                }
                if personas.isEmpty || missingBundled {
                    SKQuietButton(title: "Restore bundled") {
                        runtime.restoreBundledPersonas()
                        selected = personas.first?.persistentModelID
                    }
                }
            }
            .padding(18)
            .frame(width: 260)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(SKTheme.railColor(for: scheme))
            .overlay(alignment: .trailing) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }

            Group {
                if let persona = selectedRecord ?? filtered.first {
                    PersonaEditorView(
                        persona: persona,
                        onDuplicate: { select(runtime.createPersona(copying: persona)) },
                        onDelete: { delete(persona) }
                    )
                    .id(persona.persistentModelID)
                } else {
                    VStack(spacing: 10) {
                        Text("Create a voice")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Personas shape commit messages, hours, and issue tone. Add a custom voice or restore the bundled set.")
                            .foregroundStyle(SKTheme.mute)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                        SKPrimaryButton(title: "New persona") {
                            select(runtime.createPersona())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selected == nil { selected = personas.first?.persistentModelID }
        }
        .onChange(of: personas.count) { _, _ in
            if selected == nil || !personas.contains(where: { $0.persistentModelID == selected }) {
                selected = personas.first?.persistentModelID
            }
        }
        .alert("Delete \(pendingDelete?.name ?? "persona")?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete { delete(pendingDelete) }
                pendingDelete = nil
            }
        } message: {
            Text("Accounts and campaigns using this voice switch to another persona.")
        }
    }

    private var selectedRecord: PersonaRecord? {
        personas.first(where: { $0.persistentModelID == selected })
    }

    private var missingBundled: Bool {
        let ids = Set(personas.map(\.personaID))
        return PersonaCatalog.bundledYAML.contains { !ids.contains($0.id) }
    }

    private func select(_ record: PersonaRecord) {
        selected = record.persistentModelID
    }

    private func delete(_ persona: PersonaRecord) {
        runtime.deletePersona(persona)
        selected = personas.first(where: { $0.persistentModelID != persona.persistentModelID })?.persistentModelID
    }
}

struct PersonaEditorView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.colorScheme) private var scheme
    @Bindable var persona: PersonaRecord
    var onDuplicate: () -> Void
    var onDelete: () -> Void
    @State private var draft = ""
    @State private var parseError: String?
    @State private var confirmDelete = false

    private var parsed: Persona { PersonaLoader.load(from: draft) }
    private var isDirty: Bool { draft != persona.yamlBody }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("Name", text: $persona.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .textFieldStyle(.plain)
                Spacer()
                SKTag(kind: persona.isBundled ? .ui : .ux, label: persona.isBundled ? "Bundled" : "Custom")
            }
            Text(persona.personaID)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(SKTheme.mute)

            HStack(spacing: 8) {
                previewChip(parsed.language)
                previewChip(parsed.timezone)
                previewChip("\(parsed.workingHours.start)–\(parsed.workingHours.end)")
                previewChip("\(parsed.slugs.count) slugs")
            }

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SKTheme.canvasColor(for: scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if let parseError {
                Text(parseError).foregroundStyle(SKTheme.coral)
            }
            HStack(spacing: 10) {
                SKPrimaryButton(title: isDirty ? "Save YAML" : "Saved", enabled: isDirty) {
                    do {
                        try runtime.savePersona(persona, yaml: draft)
                        parseError = nil
                        draft = persona.yamlBody
                    } catch {
                        parseError = error.localizedDescription
                    }
                }
                SKQuietButton(title: "Duplicate", action: onDuplicate)
                if persona.isBundled {
                    SKQuietButton(title: "Reset") {
                        runtime.resetPersona(persona)
                        draft = persona.yamlBody
                        parseError = nil
                    }
                }
                Spacer()
                SKPrimaryButton(title: "Delete", destructive: true) {
                    confirmDelete = true
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { draft = persona.yamlBody }
        .onChange(of: persona.personaID) { _, _ in
            draft = persona.yamlBody
            parseError = nil
        }
        .alert("Delete \(persona.name)?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Accounts and campaigns using this voice switch to another persona. Bundled templates can be restored later.")
        }
    }

    private func previewChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(SKTheme.mute)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(SKTheme.hairline, in: Capsule())
    }
}
