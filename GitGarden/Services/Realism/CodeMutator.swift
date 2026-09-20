import Foundation

nonisolated struct ProjectState: Sendable, Hashable {
    var files: [String: String]
    var language: String

    subscript(_ path: String) -> String {
        get { files[path] ?? "" }
        set { files[path] = newValue }
    }
}

nonisolated struct MutationResult: Sendable {
    var state: ProjectState
    var message: String
    var changedPaths: [String]
}

nonisolated struct CodeMutator: Sendable {
    func seed(language: String, repoName: String) -> ProjectState {
        switch language {
        case "typescript":
            return typescriptSeed(repoName)
        case "go":
            return goSeed(repoName)
        default:
            return rustSeed(repoName)
        }
    }

    func apply(state: ProjectState, slug: String, index: Int, persona: Persona, rng: inout SeededGenerator) -> MutationResult {
        switch state.language {
        case "typescript":
            return mutateTypeScript(state: state, slug: slug, index: index, persona: persona, rng: &rng)
        case "go":
            return mutateGo(state: state, slug: slug, index: index, persona: persona, rng: &rng)
        default:
            return mutateRust(state: state, slug: slug, index: index, persona: persona, rng: &rng)
        }
    }

    func rustSeed(_ repoName: String) -> ProjectState {
        let cargo = """
        [package]
        name = "\(repoName.replacingOccurrences(of: "-", with: "_"))"
        version = "0.1.0"
        edition = "2021"

        [dependencies]
        """
        let lib = """
        //! \(repoName)

        pub fn version() -> &'static str {
            "0.1.0"
        }

        #[cfg(test)]
        mod tests {
            use super::*;

            #[test]
            fn version_is_semver() {
                assert!(version().contains('.'));
            }
        }
        """
        let readme = """
        # \(repoName)

        Personal sandbox crate. Not a product.
        """
        return ProjectState(
            files: [
                "Cargo.toml": cargo,
                "src/lib.rs": lib,
                "README.md": readme
            ],
            language: "rust"
        )
    }

    func mutateRust(state: ProjectState, slug: String, index: Int, persona: Persona, rng: inout SeededGenerator) -> MutationResult {
        var next = state
        let fnName = slug.replacingOccurrences(of: "-", with: "_")
        switch index % 6 {
        case 0:
            next["src/\(fnName).rs"] = """
            pub fn \(fnName)_len(input: &str) -> usize {
                input.chars().count()
            }

            pub fn \(fnName)_empty(input: &str) -> bool {
                input.trim().is_empty()
            }
            """
            var lib = next["src/lib.rs"]
            if !lib.contains("mod \(fnName)") {
                lib += "\n\npub mod \(fnName);\n"
                next["src/lib.rs"] = lib
            }
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: ["src/\(fnName).rs", "src/lib.rs"])
        case 1:
            var lib = next["src/lib.rs"]
            if !lib.contains("pub enum GardenError") {
                lib += """

                #[derive(Debug)]
                pub enum GardenError {
                    Empty,
                    Invalid(String),
                }

                impl std::fmt::Display for GardenError {
                    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                        match self {
                            Self::Empty => write!(f, "empty input"),
                            Self::Invalid(msg) => write!(f, "{msg}"),
                        }
                    }
                }

                impl std::error::Error for GardenError {}
                """
                next["src/lib.rs"] = lib
            }
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: ["src/lib.rs"])
        case 2:
            next["tests/\(fnName)_test.rs"] = """
            use \(crateName(from: state))::*;

            #[test]
            fn \(fnName)_module_compiles() {
                let _ = version();
            }
            """
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: ["tests/\(fnName)_test.rs"])
        case 3:
            var readme = next["README.md"]
            readme += "\n\n## \(slug)\n\nNotes on the `\(fnName)` path.\n"
            next["README.md"] = readme
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: ["README.md"])
        case 4:
            var cargo = next["Cargo.toml"]
            if !cargo.contains("license") {
                cargo += "\nlicense = \"MIT\"\n"
                next["Cargo.toml"] = cargo
            } else {
                next["src/\(fnName)_error.rs"] = """
                pub fn \(fnName)_guard(input: &str) -> Result<&str, crate::GardenError> {
                    if input.trim().is_empty() {
                        Err(crate::GardenError::Empty)
                    } else {
                        Ok(input)
                    }
                }
                """
                var lib = next["src/lib.rs"]
                if !lib.contains("mod \(fnName)_error") {
                    lib += "\npub mod \(fnName)_error;\n"
                    next["src/lib.rs"] = lib
                }
            }
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: Array(next.files.keys))
        default:
            var lib = next["src/lib.rs"]
            lib += "\n/// \(slug) marker \(index)\n"
            next["src/lib.rs"] = lib
            return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: ["src/lib.rs"])
        }
    }

    func typescriptSeed(_ repoName: String) -> ProjectState {
        ProjectState(
            files: [
                "package.json": "{\n  \"name\": \"\(repoName)\",\n  \"version\": \"0.1.0\"\n}\n",
                "src/index.ts": "export const version = '0.1.0'\n",
                "README.md": "# \(repoName)\n"
            ],
            language: "typescript"
        )
    }

    func mutateTypeScript(state: ProjectState, slug: String, index: Int, persona: Persona, rng: inout SeededGenerator) -> MutationResult {
        var next = state
        let ident = slug.replacingOccurrences(of: "-", with: "")
        next["src/\(ident).ts"] = """
        export function \(ident)Ready(input: string): boolean {
          return input.trim().length > 0
        }
        """
        var indexFile = next["src/index.ts"]
        indexFile += "\nexport * from './\(ident)'\n"
        next["src/index.ts"] = indexFile
        if index % 2 == 0 {
            next["src/\(ident).test.ts"] = "import { \(ident)Ready } from './\(ident)'\n\nvoid \(ident)Ready('ok')\n"
        }
        return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: Array(next.files.keys))
    }

    func goSeed(_ repoName: String) -> ProjectState {
        return ProjectState(
            files: [
                "go.mod": "module github.com/example/\(repoName)\n\ngo 1.22\n",
                "main.go": "package main\n\nfunc Version() string { return \"0.1.0\" }\n",
                "README.md": "# \(repoName)\n"
            ],
            language: "go"
        )
    }

    func mutateGo(state: ProjectState, slug: String, index: Int, persona: Persona, rng: inout SeededGenerator) -> MutationResult {
        var next = state
        let ident = slug.replacingOccurrences(of: "-", with: "_")
        next["\(ident).go"] = """
        package main

        func \(goExported(ident))Len(input string) int {
            return len(input)
        }
        """
        if index % 3 == 0 {
            next["\(ident)_test.go"] = """
            package main

            import "testing"

            func Test\(goExported(ident))Len(t *testing.T) {
                if \(goExported(ident))Len("ab") != 2 {
                    t.Fatal("len")
                }
            }
            """
        }
        return MutationResult(state: next, message: MessageGenerator.commitMessage(persona: persona, slug: slug, rng: &rng), changedPaths: Array(next.files.keys))
    }

    private func goExported(_ ident: String) -> String {
        guard let first = ident.first else { return ident }
        return first.uppercased() + ident.dropFirst()
    }

    private func crateName(from state: ProjectState) -> String {
        guard let cargo = state.files["Cargo.toml"],
              let range = cargo.range(of: "name = \"") else { return "garden" }
        let rest = cargo[range.upperBound...]
        if let end = rest.firstIndex(of: "\"") {
            return String(rest[..<end])
        }
        return "garden"
    }
}
