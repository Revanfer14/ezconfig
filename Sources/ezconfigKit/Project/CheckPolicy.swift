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
    struct DriftContext {
        let anchorName: String
        let expectedPrefix: String
    }

    struct Allowlist {
        var outsidePrefix: Set<String> = []   // target di luar prefix, sengaja
        var unfixable: Set<String> = []       // suffix nggak dikenal, ezconfig nolak nebak
        var unlinked: Set<String> = []        // target belum nunjuk Base.xcconfig
        var drift: Set<String> = []           // anchor keluar dari prefix sendiri
        var unrepairable: Set<String> = []    // nggak ada anchor, nggak ada template buat companion
        var driftContext: DriftContext?
    }

    struct Split {
        var blocking: [Finding] = []
        var tolerated: [Finding] = []
        var unfixable: [Finding] = []
        var unlinked: [Finding] = []
        var drift: [Finding] = []
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

        // Kumpulin drift duluan, karena nilainya harus dikeluarin dari
        // outsidePrefix. Kalau ke-tolerate, prefix salah lolos ke commit.
        var driftValues: Set<String> = []
        if let d = plan.anchorDrift, let current = d.currentBundleID {
            for part in current.components(separatedBy: " / ") {
                let v = part.trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { driftValues.insert(v) }
            }
            out.driftContext = DriftContext(
                anchorName: d.target.name,
                expectedPrefix: plan.canonicalPrefix
            )
        }
        out.drift = driftValues

        for e in plan.skipped {
            guard let current = e.currentBundleID else { continue }
            // currentBundleID bisa gabungan "a / b" waktu beda antar konfigurasi.
            for part in current.components(separatedBy: " / ") {
                let v = part.trimmingCharacters(in: .whitespaces)
                guard !v.isEmpty, !driftValues.contains(v) else { continue }
                out.outsidePrefix.insert(v)
            }
        }
        
        for c in plan.unresolvedCompanions {
            out.unrepairable.insert(c.from)
        }
        
        for s in plan.suspicious {
            out.unfixable.insert(s.resolved)
        }
        
        for e in plan.entries {
            if case .skip = e.decision { continue }
            for c in e.target.configs {
                let base = c.baseConfigFile ?? ""
                guard !base.hasSuffix("Base.xcconfig") else { continue }
                if let bid = c.bundleID { out.unlinked.insert(bid.value) }
                if let comp = c.companionBundleID { out.unlinked.insert(comp.value) }
            }
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
                } else if allowlist.unlinked.contains(f.value) {
                    // Bocor beneran, tapi `--fix` nggak punya jalan. Jawabannya init.
                    s.unlinked.append(f)
                } else {
                    s.blocking.append(f)
                }
                continue
            }

            switch f.key {
            case .developmentTeam, .attributeTeam,
                    .provisioningProfile, .provisioningSpecifier:
                // killKeys dibuang tanpa syarat link, jadi ini selalu fixable.
                s.blocking.append(f)

            case .bundleID, .companionBundleID:
                if allowlist.drift.contains(f.value) {
                    s.drift.append(f)
                } else if allowlist.outsidePrefix.contains(f.value) {
                    s.tolerated.append(f)
                } else if allowlist.unlinked.contains(f.value) {
                    s.unlinked.append(f)
                } else {
                    s.blocking.append(f)
                }
            }
        }
        return s
    }
}
