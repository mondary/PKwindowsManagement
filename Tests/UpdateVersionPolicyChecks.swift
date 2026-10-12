import Foundation

@main
enum UpdateVersionPolicyChecks {
    static func main() {
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.70-dev", build: 200,
            offered: "2026.10.67-dev", offeredBuild: 100) == .installedAhead)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.70-dev", build: 200,
            offered: "2026.10.67-dev", offeredBuild: 300) == .installedAhead)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.9-dev", build: 100,
            offered: "2026.10.71-dev", offeredBuild: 200) == .update)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.71-dev", build: 200,
            offered: "2026.10.71-dev", offeredBuild: 201) == .update)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.71-dev", build: 200,
            offered: "2026.10.71-dev", offeredBuild: 200) == .current)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.71-dev", build: 200,
            offered: "2026.10.71-dev", offeredBuild: 199) == .installedAhead)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.71-dev", build: 200,
            offered: "2026.10.43", offeredBuild: 100) == .channelSwitch)
        precondition(UpdateVersionPolicy.decision(installed: "2026.10.43", build: 200,
            offered: "2026.10.71-dev", offeredBuild: 300) == .channelSwitch)
        print("Update policy passed: no same-channel downgrade, numeric versions, rebuilds and explicit channel switches")
    }
}
