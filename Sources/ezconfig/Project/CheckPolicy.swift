//
//  CheckPolicy.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation

enum CheckPolicy {

    struct Split {
        var blocking: [Finding] = []
        var tolerated: [Finding] = []
    }

    static func allowlist(projectPath: String) -> Set<String> {
        guard let info = try? ProjectReader.read(projectPath),
              let plan = try? AdoptionPlan.make(info: info)
        else { return [] }

        var out: Set<String> = []

        for e in plan.skipped {
            guard let current = e.currentBundleID else { continue }
            // currentBundleID bisa gabungan "a / b" waktu beda antar konfigurasi.
            for part in current.components(separatedBy: " / ") {
                let v = part.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { out.insert(v) }
            }
        }

        for c in plan.unresolvedCompanions {
            out.insert(c.from)
        }

        return out
    }

    static func split(_ findings: [Finding], allowlist: Set<String>) -> Split {
        var s = Split()
        for f in findings {
            switch f.key {
            case .developmentTeam, .attributeTeam,
                 .provisioningProfile, .provisioningSpecifier:
                s.blocking.append(f)

            case .bundleID, .companionBundleID:
                if allowlist.contains(f.value) {
                    s.tolerated.append(f)
                } else {
                    s.blocking.append(f)
                }
            }
        }
        return s
    }
}
