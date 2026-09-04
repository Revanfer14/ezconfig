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

        out("▸ Rencana adopsi")
        out("  Prefix kanonik   \(plan.canonicalPrefix)")
        out("  Sumber prefix    \(plan.prefixOrigin)")
        out("")

        let width = plan.entries.map(\.target.name.count).max() ?? 0

        for e in plan.entries {
            let name = pad(e.target.name, width)
            switch e.decision {
            case .anchor:
                out("  ✓ \(name)  $(BUNDLE_PREFIX)          [acuan]")
            case let .adopt(remainder):
                out("  ✓ \(name)  $(BUNDLE_PREFIX)\(remainder)")
            case .alreadyAdopted:
                out("  · \(name)  udah pakai variabel")
            case let .skip(reason):
                out("  ✗ \(name)  DILEWATIN — \(reason)")
                if let cur = e.currentBundleID {
                    out("    \(pad("", width))  sekarang: \(cur)")
                }
            }
        }
        out("")

        if !plan.companions.isEmpty {
            out("▸ Companion reference")
            for c in plan.companions {
                out("  \(c.target)  [\(c.siteLabel)]")
                if let to = c.to {
                    out("    \(c.key)  \(c.from) → \(to)")
                } else {
                    out("    \(c.key)  \(c.from)")
                    out("    ✗ di luar prefix — nggak bisa diturunkan, DILEWATIN")
                }
            }
            out("")
        }

        for p in plan.legacyPlistInfos where !p.exists || !p.isXML {
            out("  ⚠︎  \(p.relativePath)")
            out("     \(p.exists ? "bukan XML plist — nggak bisa diedit" : "file nggak ketemu")")
            out("")
        }

        if !plan.legacyPlists.isEmpty {
            out("▸ Info.plist terpisah (project lama)")
            for l in plan.legacyPlists {
                out("  \(l.target)  \(l.path)")
            }
            out("")
        }

        if !plan.appGroups.isEmpty {
            out("▸ App Group")
            for g in plan.appGroups {
                out("  \(pad(g.variable, 18))\(g.canonical)$(LOCAL_SUFFIX)")
            }
            out("")
        }

        out("▸ Entitlements")
        if plan.entitlementPlans.isEmpty {
            out("  Nggak ada target yang pakai .entitlements.")
        }
        for p in plan.entitlementPlans {
            let mark = p.blocked ? "⚠︎" : (p.hasWork ? "!" : "·")
            out("  \(mark) \(p.file.relativePath)")
            if !p.file.exists {
                out("    FILE NGGAK KETEMU di disk")
                continue
            }
            if p.blocked {
                out("    bukan XML plist — nggak bisa diedit otomatis")
                continue
            }
            for r in p.appGroupRewrites {
                out("    app group        \(r.from) → \(r.to)")
            }
            for r in p.keychainRewrites {
                out("    keychain group   \(r.from) → \(r.to)")
            }
            if !p.hasWork {
                out("    udah pakai variabel / nggak ada yang perlu diubah")
            }
        }
        out("")

        let n = plan.adopted.count
        let s = plan.skipped.count
        out(String(repeating: "─", count: 50))
        out("  \(n) target bakal diadopsi, \(s) dilewatin.")
        if s > 0 {
            out("  Target yang dilewatin bundle ID-nya tetap literal —")
            out("  `check` bakal terus nolak commit sampai itu dibenerin.")
        }
        out("")
    }
}
