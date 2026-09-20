import Foundation
import SwiftData

@Model
final class PersonaRecord {
    @Attribute(.unique) var personaID: String
    var name: String
    var yamlBody: String
    var isBundled: Bool
    var updatedAt: Date

    init(personaID: String, name: String, yamlBody: String, isBundled: Bool) {
        self.personaID = personaID
        self.name = name
        self.yamlBody = yamlBody
        self.isBundled = isBundled
        self.updatedAt = Date()
    }
}
