//
//  Report.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation

enum Report {
    
    static func print(_ info: ProjectInfo) {
        let out: (String) -> Void = { Swift.print($0) }
        
        out("")
        out("▸ \(info.name).xcodeproj")
        out("  \(info.path)")
        out("")
        
        let signable = info.targets.filter(\.isSignable)
        let others = info.targets.filter { !$0.isSignable }
        
        if signable.isEmpty {
            out("  No target have PRODUCT_BUNDLE_IDENTIFIER.")
        }
        
        for target in signable {
            out("  \(target.name)  [\(target.displayType)]")
            
            for config in target.configs {
                out("    \(pad(config.name, 10))"
                    + describe(config.bundleID, key: "bundle id"))
                out("    \(pad("", 10))"
                    + describe(config.team, key: "team"))
                if let base = config.baseConfigFile {
                    out("    \(pad("", 10))xcconfig   \(base)")
                }
            }
            
            if let attr = target.attributeTeam {
                out("    attributes  DevelopmentTeam = \(attr)")
            }
            out("")
        }
        
        if !others.isEmpty {
            out("  Skipped (doesn't have bundle id): "
                + others.map(\.name).joined(separator: ", "))
            out("")
        }
        
        let findings = info.literalFindings
        out(String(repeating: "─", count: 50))
        if findings.isEmpty {
            out(" Clean. No signing identity is missing in .pbxproj.")
        } else {
            out("  \(findings.count) literal value found in .pbxproj:")
            for f in findings {
                out("    \(f.target) / \(f.config)  \(f.key) = \(f.value)")
            }
            out("")
            out("  This will be stripped in `ezconfig init`.")
        }
        out("")
    }
    
    private static func describe(_ v: SettingValue?, key: String) -> String {
        guard let v else { return "\(pad(key, 10)) —" }
        let mark = v.isVariable ? "✓" : "!"
        let origin = v.source == .project ? "  (dari project)" : ""
        return "\(pad(key, 10)) \(mark) \(v.value)\(origin)"
    }
    
    static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
    
    static let rule = String(repeating: "─", count: 52)
    
    private static func plural(_ n: Int, _ word: String) -> String {
        n == 1 ? word : word + "s"
    }
    
    static func stripSummary(_ o: StripOutcome) -> String? {
        var parts: [String] = []

        var removed: [String] = []
        let teams = o.teamsRemoved + o.attributeTeamsRemoved
        if teams > 0 { removed.append("\(teams) Team \(plural(teams, "ID"))") }
        if o.provisioningRemoved > 0 {
            removed.append("\(o.provisioningRemoved) provisioning \(plural(o.provisioningRemoved, "setting"))")
        }
        if !removed.isEmpty {
            parts.append(removed.joined(separator: " + ") + " removed")
        }

        var rewritten: [String] = []
        if o.bundleIDsRewritten > 0 {
            rewritten.append("\(o.bundleIDsRewritten) bundle \(plural(o.bundleIDsRewritten, "ID"))")
        }
        if o.companionsRewritten > 0 {
            rewritten.append("\(o.companionsRewritten) \(plural(o.companionsRewritten, "companion"))")
        }
        if !rewritten.isEmpty {
            parts.append(rewritten.joined(separator: " + ") + " rewritten")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
    
    static func printAttention(_ items: [[String]]) {
        guard !items.isEmpty else { return }
        Swift.print("Needs your attention")
        Swift.print("")
        for (i, item) in items.enumerated() {
            for (j, line) in item.enumerated() {
                let lead = j == 0 ? "  \(i + 1). " : "     "
                Swift.print(line.isEmpty ? "" : lead + line)
            }
            Swift.print("")
        }
    }
    
    static func printClean(_ o: StripOutcome, projectName: String) {
        let out: (String) -> Void = { Swift.print($0) }
        
        out("")
        out("ezconfig \(EzconfigVersion.current)  ·  \(projectName)")
        out("")
        
        guard let summary = stripSummary(o) else {
            out("  Nothing to clean, .pbxproj has no signing identity in it.")
            out("")
            return
        }
        
        out("  \(summary)")
        if !o.touchedTargets.isEmpty {
            out("  in \(o.touchedTargets.sorted().joined(separator: ", "))")
        }
        out("")
        out(rule)
        out("Next: commit the result.")
        out("")
    }
    
    static func printInit(_ o: InitOutcome, projectName: String, dryRun: Bool, xcodeRunning: Bool) {
        let out: (String) -> Void = { Swift.print($0) }
        
        out("")
        out("ezconfig \(EzconfigVersion.current)  ·  \(projectName)")
        out("")
        out("  Bundle ID prefix   \(o.canonicalPrefix)   (from \(o.prefixOrigin))")
        out("")
        
        // Target
        let managed = o.adopted
        let unmanaged = o.skipped.filter(\.blocksCheck)
        let noBundleID = o.skipped.filter { !$0.blocksCheck }
        
        let width = (managed.map(\.target.count) + unmanaged.map(\.target.count)).max() ?? 0
        
        out("Targets")
        for a in managed {
            out("  \(pad(a.target, width))   \(a.template)")
        }
        for s in unmanaged {
            out("  \(pad(s.target, width))   not managed: \(s.bundleID ?? "?")")
        }
        if !noBundleID.isEmpty {
            out("  \(noBundleID.count) \(plural(noBundleID.count, "target")) with no bundle ID, nothing to do")
        }
        out("")
        
        if dryRun {
            out(rule)
            out("Dry run, nothing was written. Run without --dry-run to apply.")
            out("")
            return
        }
        
        // Apa yang berubah
        var changes: [(String, String)] = []
        
        if let summary = stripSummary(o.strip) {
            changes.append((".pbxproj", summary))
        }
        changes.append((
            o.baseConfigPath,
            "\(o.baseConfigCreated ? "created" : "updated"), "
            + "linked to \(o.linkedTargets) \(plural(o.linkedTargets, "target"))"
        ))
        
        if !o.appGroups.isEmpty {
            changes.append(("App Groups", o.appGroups.map(\.variable).joined(separator: ", ")))
        }
        let entGroups = o.entitlementEdits.reduce(0) { $0 + $1.appGroups + $1.keychains }
        if entGroups > 0 {
            changes.append((".entitlements", "\(entGroups) \(plural(entGroups, "value")) in \(o.entitlementEdits.count) \(plural(o.entitlementEdits.count, "file"))"))
        }
        let plistCount = o.plistEdits.reduce(0) { $0 + $1.count }
        
        if plistCount > 0 {
            changes.append(("Info.plist", "\(plistCount) \(plural(plistCount, "value")) rewritten"))
        }
        
        if !o.git.addedRules.isEmpty || !o.git.addedXcodeRules.isEmpty {
            var parts = o.git.addedRules
            if !o.git.addedXcodeRules.isEmpty {
                let n = o.git.addedXcodeRules.count
                parts.append("\(n) Xcode \(plural(n, "rule"))")
            }
            changes.append((".gitignore", parts.joined(separator: ", ")))
        }
        
        switch o.hook.action {
        case .created:   changes.append(("pre-commit hook", "installed"))
        case .appended:  changes.append(("pre-commit hook", "added to your existing hook"))
        case .updated:   changes.append(("pre-commit hook", "updated"))
        case .unchanged: changes.append(("pre-commit hook", "already installed"))
        case .skipped:   break
        }
        if case let .success(s)? = o.setup {
            changes.append(("Configs/Local.xcconfig", "team \(s.teamID), Debug suffix \(s.suffix)"))
        }
        
        let keyWidth = changes.map(\.0.count).max() ?? 0
        out("Changes")
        for c in changes {
            out("  \(pad(c.0, keyWidth))   \(c.1)")
        }
        out("")
        
        for line in suffixCleaningLines(o.cleanings) { out(line) }
        if !o.cleanings.isEmpty { out("") }
        
        // Yang butuh tindakan
        var attention: [[String]] = []
        attention += suffixCleaningAttention(o.cleanings)
        attention += suspiciousAttention(o.suspicious)
        
        let watchSkips = o.skipped.filter { $0.kind == .watchOutsidePrefix }
        for w in watchSkips {
            attention.append([
                "Watch app bundle ID does not match its parent app",
                "",
                "\(w.target)   \(w.bundleID ?? "?")",
                "should start with   \(o.canonicalPrefix)",
                "",
                "In Xcode, select that target and set both:",
                "  Signing & Capabilities  >  Bundle Identifier",
                "  Build Settings          >  WKCompanionAppBundleIdentifier",
                "",
                "Then run: ezconfig init",
            ])
        }
        
        let otherSkips = unmanaged.filter { $0.kind != .watchOutsidePrefix }
        if !otherSkips.isEmpty {
            var lines = [
                "\(otherSkips.count) \(plural(otherSkips.count, "target")) is not managed by ezconfig",
                "",
            ]
            for s in otherSkips {
                lines.append("  \(s.target)   \(s.bundleID ?? "?")")
            }
            lines.append("")
            lines.append("Their bundle ID does not start with \(o.canonicalPrefix), so it stays")
            lines.append("the same for everyone on the team. Commits are not blocked over")
            lines.append("this. It is fine until one of them needs a capability that requires")
            lines.append("an explicit App ID, at which point two developers collide on the")
            lines.append("same identifier.")
            lines.append("")
            lines.append("To bring them in: match the prefix in Xcode and run ezconfig init")
            lines.append("again.")
            attention.append(lines)
        }
        
        for h in o.hardcodedGroups {
            var lines = [
                "App Group ID is hardcoded in your source",
                "",
                "  \(h.group)",
            ]
            for f in h.files { lines.append("    \(f)") }
            lines.append("")
            lines.append("Build settings do not reach string literals in Swift. In Debug the")
            lines.append("real App Group gets your suffix, so this code opens a container")
            lines.append("that does not exist.")
            lines.append("")
            lines.append("Read the ID from Info.plist, or keep it in one constant.")
            attention.append(lines)
        }
        
        for c in o.companionUnresolved {
            attention.append([
                "Companion reference left as is",
                "",
                "\(c.target) / \(c.site)",
                "  \(c.from)",
                "",
                "It is outside \(o.canonicalPrefix), so ezconfig cannot derive it.",
                "Fix it in Xcode if it should point at this app.",
            ])
        }
        
        for p in o.plistFailures {
            attention.append([
                "Could not edit \(p)",
                "",
                "Open it and replace the bundle ID by hand.",
            ])
        }
        for e in o.entitlementFailures {
            attention.append([
                "Could not edit \(e.path)",
                "",
                e.reason,
            ])
        }
        
        if case .skipped = o.hook.action {
            attention.append([
                "Pre-commit hook was not installed",
                "",
                o.hook.reason ?? "unknown reason",
                "",
                "Without it, Xcode can write your identity back into .pbxproj and",
                "nobody will notice until someone else fails to build.",
            ])
        }
        
        if case let .failure(e)? = o.setup {
            attention.append([
                "Could not write Configs/Local.xcconfig",
                "",
                "\(e)",
                "",
                "init itself succeeded. Fix the above, then run: ezconfig setup",
            ])
        }
        
        if !o.git.trackedButIgnored.isEmpty {
            let n = o.git.trackedButIgnored.count
            var lines = [
                "\(n) tracked \(plural(n, "file")) now \(n == 1 ? "matches" : "match") a .gitignore rule",
                "",
            ]
            for f in o.git.trackedButIgnored.prefix(6) {
                lines.append("  \(f)")
            }
            if n > 6 { lines.append("  and \(n - 6) more") }
            lines.append("")
            lines.append("Git does not apply .gitignore to files already in the index, so")
            lines.append("these keep showing up in every diff. Drop them from tracking:")
            lines.append("")
            lines.append("  git rm -r --cached <path>")
            lines.append("  git commit -m \"chore: untrack build artifacts\"")
            attention.append(lines)
        }
        
        printAttention(attention)
        
        var localReady = o.localConfigExists
        if case .success = o.setup { localReady = true }
        
        out(rule)
        if localReady {
            out("Next: open the project and build to verify.")
            out("Then tell your team to run:")
            out("  brew install revanfer14/adac9/ezconfig && ezconfig setup")
        } else {
            out("Next: run `ezconfig setup` before building.")
        }
        if xcodeRunning {
            out("")
            out("Xcode is running and will reload these changes if it has this")
            out("project open. If it writes signing values back, the pre-commit")
            out("hook cleans them.")
        }
        out("")
    }

    static func printSetup(_ o: SetupOutcome) {
        let out: (String) -> Void = { Swift.print($0) }
        
        out("")
        out("ezconfig \(EzconfigVersion.current)")
        out("")
        out("  Team ID       \(o.teamID)   \(o.displayName)")
        if let prev = o.previousTeamID, prev != o.teamID {
            out("  Replaced      \(prev)")
        }
        out("")
        
        if !o.previews.isEmpty {
            var byConfig: [String: [(target: String, bundleID: String)]] = [:]
            for p in o.previews {
                byConfig[p.config, default: []].append((p.target, p.bundleID))
            }
            let width = o.previews.map(\.target.count).max() ?? 0
            
            out("Your bundle IDs")
            for config in byConfig.keys.sorted() {
                out("  \(config)")
                for row in (byConfig[config] ?? []).sorted(by: { $0.target < $1.target }) {
                    out("    \(pad(row.target, width))   \(row.bundleID)")
                }
            }
            out("")
        }
        
        if !o.appGroupPreviews.isEmpty {
            out("Your App Groups")
            for p in o.appGroupPreviews {
                out("  \(pad(p.config, 10))\(p.value)")
            }
            out("")
        }
        
        var changes: [(String, String)] = []
        changes.append((o.localPath, "written, gitignored"))
        if !o.git.isRepo {
            changes.append((".gitignore", "skipped, not a git repo"))
        } else if !o.git.addedRules.isEmpty {
            changes.append((o.git.gitignorePath, o.git.addedRules.joined(separator: ", ")))
        }
        switch o.hook.action {
        case .created:   changes.append(("pre-commit hook", "installed"))
        case .appended:  changes.append(("pre-commit hook", "added to your existing hook"))
        case .updated:   changes.append(("pre-commit hook", "updated"))
        case .unchanged: changes.append(("pre-commit hook", "already installed"))
        case .skipped:   break
        }
        
        let keyWidth = changes.map(\.0.count).max() ?? 0
        out("Changes")
        for c in changes { out("  \(pad(c.0, keyWidth))   \(c.1)") }
        out("")
        
        var attention: [[String]] = []
        
        if o.git.localTracked {
            attention.append([
                "Configs/Local.xcconfig is already committed in this repo",
                "",
                "While it stays tracked, .gitignore does nothing and your identity",
                "keeps getting pushed. Remove it from the index:",
                "",
                "  git rm --cached Configs/Local.xcconfig",
                "  git commit -m \"chore: untrack Local.xcconfig\"",
            ])
        }
        
        if o.git.baseIgnored {
            var lines = [
                "Configs/Base.xcconfig is gitignored and cannot be un-ignored",
                "",
                "A parent folder is probably excluded.",
            ]
            if let r = o.git.baseIgnoreRule { lines.append("Rule: \(r)") }
            lines.append("")
            lines.append("Fix it by hand. Otherwise your team clones without this file and")
            lines.append("their build fails.")
            attention.append(lines)
        }
        
        if case .skipped = o.hook.action {
            attention.append([
                "Pre-commit hook was not installed",
                "",
                o.hook.reason ?? "unknown reason",
            ])
        }
        
        printAttention(attention)
        
        out(rule)
        out("Next: open the project and build.")
        out("")
    }
}
