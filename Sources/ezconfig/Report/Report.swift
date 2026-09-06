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
    
    @discardableResult
    static func printStripLines(_ o: StripOutcome) -> Bool {
        let out: (String) -> Void = { Swift.print($0) }
        var any = false

        if o.teamsRemoved > 0 {
            out("  \(pad("DEVELOPMENT_TEAM", 34))removed \(o.teamsRemoved) \(plural(o.teamsRemoved, "occurrence"))")
            any = true
        }
        if o.attributeTeamsRemoved > 0 {
            out("  \(pad("TargetAttributes.DevelopmentTeam", 34))removed \(o.attributeTeamsRemoved) \(plural(o.attributeTeamsRemoved, "target"))")
            any = true
        }
        if o.provisioningRemoved > 0 {
            out("  \(pad("PROVISIONING_PROFILE*", 34))removed \(o.provisioningRemoved) \(plural(o.provisioningRemoved, "occurrence"))")
            any = true
        }
        if o.bundleIDsRewritten > 0 {
            out("  \(pad("PRODUCT_BUNDLE_IDENTIFIER", 34))→ variabel  "
                + "(\(o.bundleIDsRewritten) \(plural(o.bundleIDsRewritten, "configuration")))")
            any = true
        }
        if o.companionsRewritten > 0 {
            out("  \(pad("INFOPLIST_KEY_WKCompanion*", 34))→ variabel  "
                + "(\(o.companionsRewritten) \(plural(o.companionsRewritten, "configuration")))")
            any = true
        }
        return any
    }

    static func printClean(_ o: StripOutcome, projectName: String) {
        let out: (String) -> Void = { Swift.print($0) }

        out("")
        out("ezconfig \(EzconfigVersion.current)")
        out("")
        out("▸ \(projectName)")
        out("")

        guard !o.isEmpty else {
            out("  Nggak ada yang perlu dibersihin, .pbxproj udah bersih.")
            out("")
            return
        }

        printStripLines(o)
        out("")

        if !o.touchedTargets.isEmpty {
            out("▸ Target yang disentuh")
            for t in o.touchedTargets.sorted() { out("  \(t)") }
            out("")
        }

        out(String(repeating: "─", count: 50))
        out("  .pbxproj bersih. Commit hasilnya.")
        out("")
    }
    
    static func printInit(_ o: InitOutcome, projectName: String, dryRun: Bool) {
        let out: (String) -> Void = { Swift.print($0) }
        let rule = String(repeating: "─", count: 50)
        
        out("")
        out("ezconfig \(Ezconfig.configuration.version)")
        out("")
        out("▸ \(projectName)")
        out("  \(pad("Prefix kanonik", 20))\(o.canonicalPrefix)")
        out("  \(pad("Sumber prefix", 20))\(o.prefixOrigin)")
        out("")
        
        // Target
        let width = (o.adopted.map(\.target.count) + o.skipped.map(\.target.count))
            .max() ?? 0
        
        out("▸ Target")
        for a in o.adopted {
            out("  ✓ \(pad(a.target, width))  \(a.template)")
        }
        for s in o.skipped {
            let mark = s.blocksCheck ? "✗" : "·"
            out("  \(mark) \(pad(s.target, width))  DILEWATIN, \(s.reason)")
            if let b = s.bundleID {
                out("    \(pad("", width))  bundle ID tetap literal: \(b)")
            }
        }
        out("")
        
        printSuffixCleanings(o.cleanings, suspicious: o.suspicious)
        
        if dryRun {
            out("▸ Dry run — nggak ada file yang ditulis")
            out("  bikin        \(o.baseConfigPath)")
            out("  sambungin    ke tiap konfigurasi target di atas")
            out("  strip        DEVELOPMENT_TEAM, PROVISIONING_PROFILE*,")
            out("               TargetAttributes.DevelopmentTeam")
            out("  tulis ulang  PRODUCT_BUNDLE_IDENTIFIER → template per target")
            out("")
            out(rule)
            out("  Jalanin tanpa --dry-run buat eksekusi.")
            out("")
            return
        }
        
        // Strip
        out("▸ Stripping .pbxproj")
                if !printStripLines(o.strip) {
                    out("  Nggak ada identitas literal, .pbxproj emang udah bersih.")
                }
        out("")
        
        out("▸ Writing \(o.baseConfigPath)")
        let linked = o.adopted.reduce(0) { $0 + $1.configs.count }
        out("▸ Linking ke \(o.adopted.count) target (\(linked) konfigurasi)")
        out("")
        
        if !o.companionEdits.isEmpty {
            out("▸ Companion reference")
            for c in o.companionEdits {
                out("  \(c.target)  [\(c.site)]")
                out("    \(c.from) → \(c.to)")
            }
            out("")
        }
        
        if !o.appGroups.isEmpty {
            out("▸ App Group")
            for g in o.appGroups {
                out("  \(pad(g.variable, 18))\(g.canonical)$(LOCAL_SUFFIX)")
            }
            out("")
        }

        if !o.entitlementEdits.isEmpty {
            out("▸ Entitlements")
            for e in o.entitlementEdits {
                var parts: [String] = []
                if e.appGroups > 0 { parts.append("\(e.appGroups) app group") }
                if e.keychains > 0 { parts.append("\(e.keychains) keychain group") }
                out("  \(e.path)")
                out("    \(parts.joined(separator: ", ")) → variabel")
            }
            out("")
        }

        if !o.plistEdits.isEmpty {
            out("▸ Info.plist")
            for p in o.plistEdits {
                out("  \(p.path)  \(p.count) \(plural(p.count, "nilai")) ditulis ulang")
            }
            out("")
        }

        if !o.companionUnresolved.isEmpty || !o.plistFailures.isEmpty || !o.entitlementFailures.isEmpty {
            out("▸ Belum ditangani")
            for c in o.companionUnresolved {
                out("  \(c.target)  [\(c.site)]")
                out("    \(c.from) — di luar prefix, dilewatin")
            }
            for p in o.plistFailures {
                out("  \(p)")
                out("    gagal dibaca/ditulis — periksa manual")
            }
            
            for e in o.entitlementFailures {
                out("  \(e.path)")
                out("    \(e.reason)")
            }
            out("")
        }
        
        // Hook commit
        let h = o.hook
        out("▸ Pre-commit hook")
        switch h.action {
        case .created:   out("  Dipasang       \(h.path)")
        case .appended:  out("  Ditambahin ke hook yang udah ada")
        case .updated:   out("  Diperbarui     \(h.path)")
        case .unchanged: out("  Udah terpasang")
        case .skipped:   out("  ⚠︎  Nggak dipasang — \(h.reason ?? "alasan nggak diketahui")")
        }
        out("")
        
        // Closing
        out(rule)
        if !o.skipped.isEmpty {
            out("  ⚠︎  \(o.skipped.count) target dilewatin — bundle ID-nya masih literal,")
            out("     jadi `check` bakal terus nolak commit. Samain bundle ID-nya")
            out("     di Xcode, atau tentuin prefix manual: ezconfig init --prefix <id>")
            out("")
        }
        
        if !o.hardcodedGroups.isEmpty {
            out("  ⚠︎  App Group masih ditulis literal di kode:")
            for h in o.hardcodedGroups {
                out("     \(h.group)")
                for f in h.files { out("       \(f)") }
            }
            out("     Build setting nggak nyentuh string di Swift. Di Debug,")
            out("     App Group aslinya bakal dapet suffix — kode yang masih")
            out("     nunjuk string lama bakal gagal buka container.")
            out("     Ganti jadi baca dari Info.plist, atau pakai satu konstanta.")
            out("")
        }
        
        let blocking = o.skipped.filter(\.blocksCheck)
        if !blocking.isEmpty {
            out("  ⚠︎  \(blocking.count) target dilewatin, bundle ID-nya masih literal,")
            out("     jadi `check` bakal terus nolak commit. Samain bundle ID-nya")
            out("     di Xcode, atau tentuin prefix manual: ezconfig init --prefix <id>")
            out("")
        }
        
        let watchSkips = o.skipped.filter { $0.reason.hasPrefix("watch app di luar prefix") }
        if !watchSkips.isEmpty {
            out("  ⚠︎  Watch app ke-skip. Ini beda dari widget yang sengaja beda")
            out("     bundle ID, watch app harus satu prefix sama app induknya.")
            for w in watchSkips {
                out("     \(w.target)")
                if let b = w.bundleID { out("       sekarang  \(b)") }
                out("       harusnya  \(o.canonicalPrefix)<sisa>")
            }
            out("     Di Xcode, buka target itu:")
            out("       Signing & Capabilities  →  Bundle Identifier")
            out("       Build Settings  →  WKCompanionAppBundleIdentifier")
            out("     Dua-duanya harus nunjuk prefix yang sama, lalu init ulang.")
            out("")
        }
        
        switch o.setup {
        case let .success(s):
            out("▸ Setup")
            out("  \(pad("Team ID", 18))\(s.teamID)")
            out("  \(pad("Sertifikat", 18))\(s.displayName)")
            out("  \(pad("Suffix Debug", 18))\(s.suffix)")
            out("  \(pad("Ditulis", 18))\(s.localPath)")
            out("")
        case let .failure(e):
            out("▸ Setup DILEWATIN")
            out("  \(e)")
            out("")
            out("  init-nya sendiri sukses. Beresin di atas, lalu: ezconfig setup")
            out("")
        case nil:
            break
        }
        
        if o.localConfigExists {
            out("  Beres. Buka project dan build buat verifikasi.")
            out("  Tim lo cukup: brew install revan/adac9/ezconfig && ezconfig setup")
        } else {
            out("  .pbxproj bersih, tapi Configs/Local.xcconfig belum ada.")
            out("  Jalanin `ezconfig setup` dulu sebelum build.")
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
        
        if !o.appGroupPreviews.isEmpty {
            out("▸ App Group")
            for p in o.appGroupPreviews {
                out("  \(pad(p.config, 10))\(p.value)")
            }
            out("")
        }
        
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
        
        let h = o.hook
        out("▸ Pre-commit hook")
        switch h.action {
        case .created:   out("  Dipasang       \(h.path)")
        case .appended:  out("  Ditambahin ke hook yang udah ada")
            out("                 \(h.path)")
        case .updated:   out("  Diperbarui     \(h.path)")
        case .unchanged: out("  Udah terpasang \(h.path)")
        case .skipped:   out("  ⚠︎  Nggak dipasang — \(h.reason ?? "alasan nggak diketahui")")
        }
        if let custom = h.customHooksPath {
            out("  core.hooksPath \(custom)")
        }
        if h.projectDir != "." {
            out("  Project dir    \(h.projectDir)")
        }
        out("")
        
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
