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
    
    private static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }
    
    static func printInit(_ o: InitOutcome, projectName: String, dryRun: Bool) {
        let out: (String) -> Void = { Swift.print($0) }
        let rule = String(repeating: "─", count: 50)
        
        out("")
        out("ezconfig \(Ezconfig.configuration.version)")
        out("")
        out("▸ \(projectName)")
        out("  \(pad("Target", 20))\(o.targetName)")
        out("  \(pad("Canonical prefix", 20))\(o.canonicalPrefix)")
        out("")
        
        // Dry run: tampilkan rencana, bukan hasil
        if dryRun {
            out("▸ Dry run — nggak ada file yang ditulis")
            out("  bikin        \(o.baseConfigPath)")
            out("  sambungin    ke semua konfigurasi target")
            out("  strip        DEVELOPMENT_TEAM, PROVISIONING_PROFILE*,")
            out("               TargetAttributes.DevelopmentTeam")
            out("  tulis ulang  PRODUCT_BUNDLE_IDENTIFIER → $(BUNDLE_PREFIX)")
            out("")
            out(rule)
            out("  Jalanin tanpa --dry-run buat eksekusi.")
            out("")
            return
        }
        
        // Strip
        out("▸ Stripping .pbxproj")
        var stripped = false
        
        if o.teamsRemoved > 0 {
            out("  \(pad("DEVELOPMENT_TEAM", 34))removed \(o.teamsRemoved) \(plural(o.teamsRemoved, "occurrence"))")
            stripped = true
        }
        if o.targetAttributeTeamRemoved {
            out("  \(pad("TargetAttributes.DevelopmentTeam", 34))removed")
            stripped = true
        }
        if o.provisioningRemoved > 0 {
            out("  \(pad("PROVISIONING_PROFILE*", 34))removed \(o.provisioningRemoved) \(plural(o.provisioningRemoved, "occurrence"))")
            stripped = true
        }
        if o.bundleIDsRewritten > 0 {
            out("  \(pad("PRODUCT_BUNDLE_IDENTIFIER", 34))→ $(BUNDLE_PREFIX)  "
                + "(\(o.bundleIDsRewritten) \(plural(o.bundleIDsRewritten, "configuration")))")
            stripped = true
        }
        if !stripped {
            out("  Nggak ada identitas literal — .pbxproj emang udah bersih.")
        }
        out("")
        
        // Tulis & connect
        out("▸ Writing \(o.baseConfigPath)")
        if o.linkedConfigurations.isEmpty {
            out("▸ Nggak ada konfigurasi yang ke-link — periksa manual.")
        } else {
            out("▸ Linking to \(o.linkedConfigurations.joined(separator: ", "))")
        }
        out("")
        
        // Closing
        out(rule)
        if o.localConfigExists {
            out("  .pbxproj bersih. Configs/Local.xcconfig kedeteksi —")
            out("  buka project dan build buat verifikasi.")
        } else {
            out("  .pbxproj bersih. Belum bisa build sampai")
            out("  Configs/Local.xcconfig ada.")
        }
        out("")
    }   
    
    private static func plural(_ n: Int, _ word: String) -> String {
        n == 1 ? word : word + "s"
    }
    
    static func printSetup(_ o: SetupOutcome) {
        let out: (String) -> Void = { Swift.print($0) }
        let rule = String(repeating: "─", count: 50)
        
        out("")
        out("ezconfig \(Ezconfig.configuration.version)")
        out("")
        out("▸ Keychain")
        out("  \(pad("Team ID", 18))\(o.teamID)")
        out("  \(pad("Sertifikat", 18))\(o.displayName)")
        if let prev = o.previousTeamID, prev != o.teamID {
            out("  \(pad("Sebelumnya", 18))\(prev)  → diganti")
        }
        out("")
        
        let g = o.git
        if !g.isRepo {
            out("▸ Git")
            out("  Bukan git repo — gitignore dilewatin.")
            out("")
        } else {
            out("▸ \(g.gitignorePath)")
            if g.addedRules.isEmpty {
                out("  Udah bener, nggak ada yang diubah.")
            } else {
                for r in g.addedRules { out("  + \(r)") }
            }
            out("")
        }

        out(rule)

        var warned = false

        if g.localTracked {
            out("  ⚠︎  Configs/Local.xcconfig UDAH KE-COMMIT di repo ini.")
            out("     Selama masih tracked, .gitignore nggak ngefek —")
            out("     identitas lo tetap ke-push. Buang dari index:")
            out("")
            out("       git rm --cached Configs/Local.xcconfig")
            out("       git commit -m \"chore: untrack Local.xcconfig\"")
            out("")
            warned = true
        }

        if g.baseIgnored {
            out("  ⚠︎  Configs/Base.xcconfig KE-IGNORE dan nggak bisa dibatalin")
            out("     lewat negasi — kemungkinan folder induknya yang di-exclude.")
            if let rule = g.baseIgnoreRule {
                out("     Aturannya: \(rule)")
            }
            out("     Perbaiki manual. Kalau nggak, tim lo clone tanpa file ini")
            out("     dan build-nya gagal.")
            out("")
            warned = true
        }

        if !warned {
            out("  Local.xcconfig siap dan ke-ignore. Buka project dan build.")
        }
        out("")
    }
}
