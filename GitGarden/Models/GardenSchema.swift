import Foundation
import SwiftData

enum GardenSchema {
    static let models: [any PersistentModel.Type] = [
        Account.self,
        PersonaRecord.self,
        Campaign.self,
        Job.self,
        CreatedResource.self,
        AuditEvent.self,
        CampaignSnapshot.self,
        AppSettings.self,
        AccountCron.self
    ]

    static var schema: Schema { Schema(models) }
}
