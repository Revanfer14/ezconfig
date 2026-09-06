//
//  CheckPolicy.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation
import PathKit

enum CheckPolicy {

    // Dua himpunan, bukan satu, karena artinya beda jauh dan `--strict`
    // cuma boleh nyentuh yang pertama.
    struct Allowlist {
        var outsidePrefix: Set<String> = []   // target di luar prefix, sengaja
        var unfixable: Set<String> = []       // suffix nggak dikenal, ezconfig nolak nebak
    }

    struct Split {
        var blocking: [Finding] = []
        var tolerated: [Finding] = []
        var unfixable: [Finding] = []
    }

    static func allowlist(projectPath: String) -> Allowlist {
        let sourceRoot = Path(projectPath).parent()
        guard let info = try? ProjectReader.read(projectPath),
              let plan = try? AdoptionPlan.make(
                info: info,
                knownSuffixes: LocalConfig.knownSuffixes(sourceRoot: sourceRoot)
              )
        else { return Allowlist() }

        var out = Allowlist()

        for e in plan.skipped {
            guard let current = e.currentBundleID else { continue }
            // currentBundleID bisa gabungan "a / b" waktu beda antar konfigurasi.
            for part in current.components(separatedBy: " / ") {
                let v = part.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { out.outsidePrefix.insert(v) }
            }
        }

        for c in plan.unresolvedCompanions {
            out.outsidePrefix.insert(c.from)
        }

        // Nilai SETELAH pembersihan, bukan nilai mentah. Kalau nilai mentah ikut
        // masuk, kasus suffix dobel ke-tolerate duluan dan suffix yang anchored
        // nggak pernah kebersihin. Itu kebocoran beneran, Release bawa Team ID.
        for s in plan.suspicious {
            out.unfixable.insert(s.resolved)
        }

        return out
    }

    static func split(_ findings: [Finding], allowlist: Allowlist) -> Split {
        var s = Split()
        for f in findings {
            if f.isSuffixLeak {
                if allowlist.unfixable.contains(f.value) {
                    s.unfixable.append(f)
                } else if allowlist.outsidePrefix.contains(f.value) {
                    s.tolerated.append(f)
                } else {
                    s.blocking.append(f)
                }
                continue
            }

            switch f.key {
            case .developmentTeam, .attributeTeam,
                    .provisioningProfile, .provisioningSpecifier:
                s.blocking.append(f)

            case .bundleID, .companionBundleID:
                if allowlist.outsidePrefix.contains(f.value) {
                    s.tolerated.append(f)
                } else {
                    s.blocking.append(f)
                }
            }
        }
        return s
    }
}
