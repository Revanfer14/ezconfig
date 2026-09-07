//
//  Report+Check.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation

private struct StdErr: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

extension Report {

    private static func emitter(toStdout: Bool) -> (String) -> Void {
        var err = StdErr()
        return { line in
            if toStdout { Swift.print(line) } else { Swift.print(line, to: &err) }
        }
    }

    private static func findingLine(_ f: Finding, width: Int) -> String {
        "    line \(padLeft(String(f.line), 5))  \(padRight(f.key.label, width))  \(f.value)"
    }

    static func printCheck(_ findings: [Finding], projectName: String, source: CheckContext.Source) {
        let emit = emitter(toStdout: false)

        let leaks = findings.filter(\.isSuffixLeak)
        let literals = findings.filter { !$0.isSuffixLeak }
        let noun = findings.count == 1 ? "value" : "values"

        // Baris pertama HARUS berdiri sendiri, GitHub Desktop motong sisanya.
        emit("ezconfig: \(findings.count) signing \(noun) in \(projectName), commit blocked.")
        emit("")

        let width = findings.map(\.key.label.count).max() ?? 0

        if !literals.isEmpty {
            emit("  Hardcoded values (checked in \(source.label))")
            for f in literals { emit(findingLine(f, width: width)) }
            emit("")
        }

        if !leaks.isEmpty {
            emit("  Your machine's suffix leaked into a variable value")
            for f in leaks {
                emit(findingLine(f, width: width))
                if let s = f.suffix {
                    emit("    \(padRight("", 5 + 8))\(padRight("", width))  '\(s)' is yours")
                }
            }
            emit("    Committing this gives everyone else a bundle ID that does not")
            emit("    resolve, and puts your identity into Release builds.")
            emit("")
        }

        emit("  Fix: ezconfig check --fix")
        emit("")
    }

    static func printFixed(_ o: StripOutcome, restaged: Bool) {
        let emit = emitter(toStdout: false)

        if o.isEmpty {
            emit("ezconfig: .pbxproj on disk was already clean, staging area re-synced.")
        } else {
            var parts: [String] = []
            if o.teamsRemoved > 0 { parts.append("\(o.teamsRemoved) DEVELOPMENT_TEAM") }
            if o.attributeTeamsRemoved > 0 { parts.append("\(o.attributeTeamsRemoved) TargetAttributes") }
            if o.provisioningRemoved > 0 { parts.append("\(o.provisioningRemoved) PROVISIONING_PROFILE*") }
            if o.bundleIDsRewritten > 0 { parts.append("\(o.bundleIDsRewritten) bundle ID") }
            if o.companionsRewritten > 0 { parts.append("\(o.companionsRewritten) companion reference") }
            emit("ezconfig: cleaned \(parts.joined(separator: ", ")).")
        }

        if restaged {
            emit("")
            emit("  Files re-staged. Commit again to continue.")
            emit("")
        }
    }

    static func printFixFailed(_ residue: [Finding], projectName: String) {
        let emit = emitter(toStdout: false)
        let width = residue.map(\.key.label.count).max() ?? 0

        emit("ezconfig: could not clean \(residue.count) value(s) in \(projectName).")
        emit("")
        for f in residue { emit(findingLine(f, width: width)) }
        emit("")
        emit("  This is an ezconfig bug. Fix these in Xcode to get unblocked, then")
        emit("  please report it: github.com/Revanfer14/ezconfig/issues")
        emit("")
    }

    static func printTolerated(_ findings: [Finding], toStdout: Bool) {
        guard !findings.isEmpty else { return }
        let emit = emitter(toStdout: toStdout)
        let width = findings.map(\.key.label.count).max() ?? 0

        emit("")
        emit("  \(findings.count) hardcoded value(s) left alone, in targets ezconfig does not manage")
        for f in findings { emit(findingLine(f, width: width)) }
        emit("    To bring them in: give them the same bundle ID prefix in Xcode,")
        emit("    then run ezconfig init.")
    }

    static func printFixTolerated(_ findings: [Finding]) {
        guard !findings.isEmpty else { return }
        let emit = emitter(toStdout: false)
        emit("")
        emit("  \(findings.count) value(s) left alone, in targets ezconfig does not manage.")
    }

    static func printUnfixable(_ findings: [Finding], toStdout: Bool) {
        guard !findings.isEmpty else { return }
        let emit = emitter(toStdout: toStdout)
        let width = findings.map(\.key.label.count).max() ?? 0

        emit("")
        emit("  \(findings.count) value(s) contain something shaped like a Team ID")
        for f in findings { emit(findingLine(f, width: width)) }
        emit("")
        emit("    It is not attached to the prefix, so ezconfig cannot tell whether")
        emit("    it is your identity or part of a target name. This commit goes")
        emit("    through, but if it is yours it ships in Release too.")
        emit("")
        emit("    Fix the bundle ID in Xcode, or: ezconfig init --prefix <id>")
    }
    
    static func printUnlinked(
        _ findings: [Finding],
        projectName: String,
        toStdout: Bool
    ) {
        guard !findings.isEmpty else { return }
        let emit = emitter(toStdout: toStdout)
        let width = findings.map(\.key.label.count).max() ?? 0

        emit("ezconfig: \(findings.count) value(s) in \(projectName) belong to a target")
        emit("that is not linked to Configs/Base.xcconfig.")
        emit("")
        for f in findings { emit(findingLine(f, width: width)) }
        emit("")
        emit("  Rewriting these would point them at $(BUNDLE_PREFIX), a variable")
        emit("  that target cannot see. It would resolve to nothing and the bundle")
        emit("  ID would come out malformed, so ezconfig left them alone.")
        emit("")
        emit("  Linking is done by init, not by the hook. Run:")
        emit("    ezconfig init")
        emit("  Then commit the project file and Configs/Base.xcconfig together.")
        emit("")
    }
    
    static func printDrift(
        _ findings: [Finding],
        context: CheckPolicy.DriftContext?,
        projectName: String,
        toStdout: Bool
    ) {
        guard let context, !findings.isEmpty else { return }
        let emit = emitter(toStdout: toStdout)
        let width = findings.map(\.key.label.count).max() ?? 0

        // Baris pertama HARUS berdiri sendiri, GitHub Desktop motong sisanya.
        emit("ezconfig: Configs/Base.xcconfig has the wrong prefix, commit blocked.")
        emit("")
        emit("  BUNDLE_PREFIX   \(context.expectedPrefix)")
        emit("  Anchor target   \(context.anchorName)")
        emit("")
        for f in findings { emit(findingLine(f, width: width)) }
        emit("")
        emit("  The prefix in Configs/Base.xcconfig was taken from that target, and")
        emit("  Base.xcconfig is committed, so the whole team builds against it. A")
        emit("  value that no longer matches means the stored prefix is wrong for")
        emit("  everyone, not just for this target.")
        emit("")
        emit("  --fix cannot repair this. It would write $(BUNDLE_PREFIX) over the")
        emit("  value and change the bundle ID without telling you.")
        emit("")
        emit("  Two ways out:")
        emit("    If the prefix is right, fix the bundle ID in Xcode.")
        emit("    If the bundle ID is right, run:")
        emit("      ezconfig init --prefix <id>")
        emit("")
    }

    static func printDangling(_ audit: ConfigAudit, toStdout: Bool) {
        guard !audit.dangling.isEmpty else { return }
        let emit = emitter(toStdout: toStdout)
        let width = audit.dangling.map(\.target.count).max() ?? 0

        emit("ezconfig: \(audit.dangling.count) build configuration(s) use $(BUNDLE_PREFIX)")
        emit("but are not linked to Configs/Base.xcconfig.")
        emit("")
        for d in audit.dangling {
            emit("    \(padRight(d.target, width))  \(padRight(d.config, 8))  \(d.value)")
        }
        emit("")
        emit("  The variable is undefined in those targets, so it resolves to")
        emit("  nothing and the bundle ID comes out malformed. The build either")
        emit("  fails or ships under the wrong identifier.")
        emit("")
        emit("  Run:")
        emit("    ezconfig init")
        emit("  Then commit the project file and Configs/Base.xcconfig together.")
        emit("")
    }

    static func printAudit(_ audit: ConfigAudit, toStdout: Bool) {
        guard !audit.isClean, audit.baseExists else { return }
        let emit = emitter(toStdout: toStdout)

        emit("")
        emit("  Variables used in entitlements but missing from Base.xcconfig")
        for u in audit.undefined {
            emit("    \(u.file)   $(\(u.variable))")
        }
        emit("    They resolve to nothing at build time. Run: ezconfig init")
    }

    static func padRight(_ s: String, _ w: Int) -> String {
        s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
    }

    static func padLeft(_ s: String, _ w: Int) -> String {
        s.count >= w ? s : String(repeating: " ", count: w - s.count) + s
    }
}
