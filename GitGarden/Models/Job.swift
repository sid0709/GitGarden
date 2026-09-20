import Foundation
import SwiftData

@Model
final class Job {
    var stepID: String
    var kindRaw: String
    var accountLogin: String
    var scheduledAt: Date
    var statusRaw: String
    var attempt: Int
    var lastError: String
    var completedAt: Date?
    var payloadJSON: Data?
    var summary: String
    var orderIndex: Int
    var campaign: Campaign?

    init(step: PlanStep, orderIndex: Int, campaign: Campaign) {
        self.stepID = step.id
        self.kindRaw = step.kind.rawValue
        self.accountLogin = step.accountLogin
        self.scheduledAt = step.scheduledAt
        self.statusRaw = JobStatus.pending.rawValue
        self.attempt = 0
        self.lastError = ""
        self.completedAt = nil
        self.payloadJSON = try? JSONEncoder.garden.encode(step.payload)
        self.summary = step.summary
        self.orderIndex = orderIndex
        self.campaign = campaign
    }

    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var kind: StepKind {
        StepKind(rawValue: kindRaw) ?? .commit
    }

    var payload: StepPayload {
        get {
            guard let payloadJSON else { return StepPayload() }
            return (try? JSONDecoder.garden.decode(StepPayload.self, from: payloadJSON)) ?? StepPayload()
        }
        set {
            payloadJSON = try? JSONEncoder.garden.encode(newValue)
        }
    }
}
