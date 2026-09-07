//
//  Report+Plan.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//


import Foundation

extension Report {

    static func printPlan(_ plan: AdoptionPlan) {
        let out: (String) -> Void = { Swift.print($0) }

        out("▸ Adoption plan")
        out("  Canonical prefix   \(plan.canonicalPrefix)")
        out("  Taken from         \(plan.prefixOrigin)")
        out("")

        let width = plan.entries.map(\.target.name.count).max() ?? 0

        for e in plan.entries {
            let name = pad(e.target.name, width)
            switch e.decision {
            case .anchor:
                out("  ✓ \(name)  $(BUNDLE_PREFIX)          [anchor]")
            case let .adopt(remainder):
                out("  ✓ \(name)  $(BUNDLE_PREFIX)\(remainder)")
            case .alreadyAdopted:
                out("  · \(name)  already using the variable")
            case let .skip(reason, _):
                out("  ✗ \(name)  SKIPPED, \(reason)")
                if let cur = e.currentBundleID {
                    out("    \(pad("", width))  currently: \(cur)")
                }
            }
        }
        out("")

        printSuffixCleanings(plan.cleanings, suspicious: plan.suspicious)

        if !plan.companions.isEmpty {
            out("▸ Companion references")
            for c in plan.companions {
                out("  \(c.target)  [\(c.siteLabel)]")
                if let to = c.to {
                    out("    \(c.key)  \(c.from) → \(to)")
                } else {
                    out("    \(c.key)  \(c.from)")
                    out("    ✗ outside the prefix, cannot be derived, SKIPPED")
                }
            }
            out("")
        }

        for p in plan.legacyPlistInfos where !p.exists || !p.isXML {
            out("  ⚠︎  \(p.relativePath)")
            out("     \(p.exists ? "not an XML plist, cannot be edited" : "file not found")")
            out("")
        }

        if !plan.legacyPlists.isEmpty {
            out("▸ Standalone Info.plist (older project layout)")
            for l in plan.legacyPlists {
                out("  \(l.target)  \(l.path)")
            }
            out("")
        }

        if !plan.appGroups.isEmpty {
            out("▸ App Groups")
            for g in plan.appGroups {
                out("  \(pad(g.variable, 18))\(g.canonical)$(LOCAL_SUFFIX)")
            }
            out("")
        }

        out("▸ Entitlements")
        if plan.entitlementPlans.isEmpty {
            out("  No target uses an .entitlements file.")
        }
        for p in plan.entitlementPlans {
            let mark = p.blocked ? "⚠︎" : (p.hasWork ? "!" : "·")
            out("  \(mark) \(p.file.relativePath)")
            if !p.file.exists {
                out("    FILE NOT FOUND on disk")
                continue
            }
            if p.blocked {
                out("    not an XML plist, cannot be edited automatically")
                continue
            }
            for r in p.appGroupRewrites {
                out("    app group        \(r.from) → \(r.to)")
            }
            for r in p.keychainRewrites {
                out("    keychain group   \(r.from) → \(r.to)")
            }
            if !p.hasWork {
                out("    already using variables, nothing to change")
            }
        }
        out("")

        let n = plan.adopted.count
        let s = plan.skipped.count
        out(String(repeating: "─", count: 50))
        out("  \(n) target(s) would be adopted, \(s) skipped.")
        if s > 0 {
            out("  Skipped targets keep their literal bundle ID. `check` leaves")
            out("  them alone, so commits still go through. To bring one in,")
            out("  give it the same prefix in Xcode and run init again.")
        }
        out("")
    }
}
