//
//  Report+Suffix.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//

import Foundation

extension Report {

    static func printSuffixCleanings(
        _ cleanings: [SuffixCleaning],
        suspicious: [SuspiciousSuffix]
    ) {
        let out: (String) -> Void = { Swift.print($0) }

        if !cleanings.isEmpty {
            out("▸ Identitas lokal dibersihin")
            out("  Xcode nulis nilai dari hasil resolve di mesin lo, bukan dari")
            out("  $(BUNDLE_PREFIX) — jadi suffix lokal ikut kebawa. Dibuang otomatis.")
            out("")

            var order: [String] = []
            var byTarget: [String: [SuffixCleaning]] = [:]
            for c in cleanings {
                if byTarget[c.target] == nil { order.append(c.target) }
                byTarget[c.target, default: []].append(c)
            }

            for target in order {
                out("  \(target == "—" ? "(project)" : target)")
                for c in byTarget[target] ?? [] {
                    out("    \(pad(c.site, 12))\(c.from)")
                    out("    \(pad("", 12))→ \(c.to)   [buang \(c.suffix)]")
                }
                out("")
            }

            out("  ⚠︎  Kalau nilai tercemar itu udah pernah naik ke Release/TestFlight,")
            out("     App ID-nya kemungkinan udah ke-claim di App Store Connect")
            out("     dan nggak bisa dilepas. Periksa portal.")
            out("")
        }

        guard !suspicious.isEmpty else { return }

        out("▸ Suffix nggak dikenali")
        for s in suspicious {
            out("  \(s.target)  [\(s.site)]")
            out("    \(s.value)")
            if s.resolved != s.value {
                out("    setelah init: \(s.resolved)")
            }
            out("    komponen '\(s.component)' bentuknya kayak suffix lokal, tapi")
            out("    nggak cocok sama Local.xcconfig maupun sertifikat di keychain.")
        }
        out("")
        out("  ezconfig nggak nebak, nilainya dibiarin apa adanya.")
        out("  `check` juga nggak bakal ngeblokir nilai ini, jadi commit tetap jalan.")
        out("  Kemungkinan besar suffix dari Apple ID lama yang sertifikatnya")
        out("  udah dihapus. Benerin bundle ID-nya di Xcode, atau tentuin")
        out("  prefix manual: ezconfig init --prefix <id>")
        out("")
    }
}
