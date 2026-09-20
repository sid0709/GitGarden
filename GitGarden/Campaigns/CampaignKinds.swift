import Foundation

enum HistoryCampaign {
    static func enabled(on campaign: Campaign) -> Bool { campaign.includeHistory }
}

enum PRFlowCampaign {
    static func enabled(on campaign: Campaign) -> Bool { campaign.includePRs }
}

enum IssueCampaign {
    static func enabled(on campaign: Campaign) -> Bool { campaign.includeIssues }
}

enum ProfileCampaign {
    static func enabled(on campaign: Campaign) -> Bool { campaign.includeProfile }
}

enum SocialCampaign {
    static func enabled(on campaign: Campaign) -> Bool { campaign.includeSocial }
}
