//
//  ProjectWriter.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import CryptoKit
import Foundation
import PathKit
import XcodeProj

enum InitError: Error, CustomStringConvertible {
    case noNativeTarget
    case foreignBaseConfig([String])
    case noRootGroup
    
    var description: String {
        switch self {
        case .noNativeTarget:
            return "No native target found in this project."
        case let .foreignBaseConfig(lines):
            return """
            Some targets already point at an xcconfig of their own:
              \(lines.joined(separator: "\n  "))
            ezconfig will not overwrite a file it did not create.
            """
        case .noRootGroup:
            return "This project has no root group. The file structure is not what Xcode normally writes."
        }
    }}

enum WriteError: Error, CustomStringConvertible {
    case projectChanged

    var description: String {
        """
        The project file changed while ezconfig was running.

        Most likely Xcode wrote to project.pbxproj in the background.
        Nothing was written, the project is untouched.

        Run the command again.
        """
    }
}

enum StripError: Error, CustomStringConvertible {
    case notInitialized
    
    var description: String {
        """
        This project has not been initialised. Configs/Base.xcconfig is missing.

        `check --fix` rewrites PRODUCT_BUNDLE_IDENTIFIER to $(BUNDLE_PREFIX),
        a variable that only lives in Base.xcconfig. Without that file the
        project would be left broken.

        Run this first:
          ezconfig init
        """
    }
}

struct StripOutcome {
    var teamsRemoved = 0
    var provisioningRemoved = 0
    var attributeTeamsRemoved = 0
    var bundleIDsRewritten = 0
    var companionsRewritten = 0
    var touchedTargets: [String] = []
    
    var unlinkedTargets: [String] = []
    
    var isEmpty: Bool {
        teamsRemoved == 0 && provisioningRemoved == 0
        && attributeTeamsRemoved == 0 && bundleIDsRewritten == 0
        && companionsRewritten == 0
    }
}
struct InitOutcome {
    struct Adopted {
        let target: String
        let template: String
        let configs: [String]
    }
    
    struct Skipped {
        let target: String
        let reason: String
        let kind: TargetPlan.SkipKind
        let bundleID: String?
        let blocksCheck: Bool
        let isEmbedded: Bool
    }
    
    var canonicalPrefix = ""
    var prefixOrigin = ""
    var adopted: [Adopted] = []
    var skipped: [Skipped] = []
    var strip = StripOutcome()
    var baseConfigPath = ""
    var baseConfigCreated = false
    var linkedTargets = 0
    var localConfigExists = false
    var hook = HookOutcome()
    var git = GitOutcome()
    var setup: Result<SetupOutcome, Error>?
    
    var companionEdits: [(target: String, site: String, from: String, to: String)] = []
    var companionUnresolved: [(target: String, site: String, from: String)] = []
    var plistEdits: [(path: String, count: Int)] = []
    var plistFailures: [String] = []
    
    var appGroups: [(variable: String, canonical: String)] = []
    var entitlementEdits: [(path: String, appGroups: Int, keychains: Int)] = []
    var entitlementFailures: [(path: String, reason: String)] = []
    var hardcodedGroups: [(group: String, files: [String])] = []
    var cleanings: [SuffixCleaning] = []
    var suspicious: [SuspiciousSuffix] = []
}

struct TargetEdits {
    var bundleIDTemplate: String?
    var settings: [String: String] = [:]   // key build setting → nilai template
}

struct ProjectWriter {
    
    let projectPath: Path      // .../MultiTest.xcodeproj
    let sourceRoot: Path       // folder induknya
    private let xcodeproj: XcodeProj
    private let pbxprojPath: Path
    private let pbxprojDigest: SHA256Digest

    init(projectPath: Path) throws {
        self.projectPath = projectPath
        self.sourceRoot = projectPath.parent()
        self.xcodeproj = try XcodeProj(path: projectPath)
        self.pbxprojPath = projectPath + "project.pbxproj"
        self.pbxprojDigest = try Self.digest(of: pbxprojPath)
    }

    private static func digest(of path: Path) throws -> SHA256Digest {
        SHA256.hash(data: try path.read())
    }

    // Ketauan berubah kalau file-nya nggak kebaca sama sekali juga, bukan
    // cuma kalau isinya beda. Xcode bisa nulis pas file lagi dibaca.
    private func assertUnchanged() throws {
        guard let current = try? Self.digest(of: pbxprojPath),
              current == pbxprojDigest
        else {
            throw WriteError.projectChanged
        }
    }

    // Plan disusun dari pembacaan terpisah lewat ProjectReader.
    // Buka file dua kali — utang teknis yang dibayar di Fase 6.
    private func plan(overridePrefix: String?) throws -> AdoptionPlan {
        let info = try ProjectReader.read(projectPath.string)
        return try AdoptionPlan.make(
            info: info,
            overridePrefix: overridePrefix,
            knownSuffixes: LocalConfig.knownSuffixes(sourceRoot: sourceRoot)
        )
    }
    
    func runInit(overridePrefix: String?, dryRun: Bool) throws -> InitOutcome {
        var outcome = InitOutcome()
        
        guard !xcodeproj.pbxproj.nativeTargets.isEmpty else {
            throw InitError.noNativeTarget
        }
        
        let plan = try plan(overridePrefix: overridePrefix)
        if !dryRun { try assertUnchanged() }
        outcome.canonicalPrefix = plan.canonicalPrefix
        outcome.prefixOrigin = plan.prefixOrigin
        outcome.cleanings = plan.cleanings
        outcome.suspicious = plan.suspicious
        
        for c in plan.unresolvedCompanions {
            outcome.companionUnresolved.append((c.target, c.siteLabel, c.from))
        }
        
        outcome.appGroups = plan.appGroups.map { (variable: $0.variable, canonical: $0.canonical) }
        
        for e in plan.skipped {
            outcome.skipped.append(
                .init(
                    target: e.target.name,
                    reason: reasonText(e.decision),
                    kind: skipKind(e.decision),
                    bundleID: e.currentBundleID,
                    blocksCheck: e.target.isSignable,
                    isEmbedded: e.target.isEmbedded
                )
            )
        }
        
        // Target yang bakal disentuh: semua yang signable.
        let touchNames = Set(
            plan.entries
                .filter { $0.target.isSignable }
                .map(\.target.name)
        )
        let touchTargets = xcodeproj.pbxproj.nativeTargets
            .filter { touchNames.contains($0.name) }
        
        try assertNoForeignBaseConfig(touchTargets)
        
        // 1. Tulis Base.xcconfig ke disk duluan.
        let configsDir = sourceRoot + "Configs"
        let basePath = configsDir + "Base.xcconfig"
        outcome.baseConfigPath = "Configs/Base.xcconfig"
        outcome.baseConfigCreated = !basePath.exists
        
        if !dryRun {
            try FileManager.default.createDirectory(
                atPath: configsDir.string,
                withIntermediateDirectories: true
            )
            try XcconfigTemplate
                .base(canonicalPrefix: plan.canonicalPrefix, appGroups: plan.appGroups)
                .write(toFile: basePath.string, atomically: true, encoding: .utf8)
        }
        
        outcome.localConfigExists = (configsDir + "Local.xcconfig").exists
        
        // Dry run: rencana udah lengkap di outcome, berhenti sebelum nyentuh project.
        if dryRun {
            for e in plan.adopted {
                outcome.adopted.append(
                    .init(
                        target: e.target.name,
                        template: e.template ?? "",
                        configs: e.target.configs.map(\.name)
                    )
                )
            }
            
            for c in plan.companions {
                if let to = c.to {
                    outcome.companionEdits.append((c.target, c.siteLabel, c.from, to))
                }
            }
            
            for p in plan.entitlementPlans where p.hasWork {
                outcome.entitlementEdits.append((
                    path: p.file.relativePath,
                    appGroups: p.appGroupRewrites.count,
                    keychains: p.keychainRewrites.count
                ))
            }
            return outcome
        }
        
        // 2. Daftarin xcconfig sekali.
        let fileRef = try registerBaseConfigFile(at: basePath)
        let editsByTarget = edits(from: plan)
        
        // Waktu semua target udah teradopsi, template-nya nil karena nggak ada
        // yang perlu ditulis. Target-nya tetap dikelola, jadi tetap harus muncul.
        var planByName: [String: TargetPlan] = [:]
        for e in plan.entries { planByName[e.target.name] = e }
        
        // 2a. Link xcconfig duluan, cuma ke target yang diadopsi.
        for target in touchTargets.sorted(by: { $0.name < $1.name }) {
            var linked: [String] = []
            for config in target.buildConfigurationList?.buildConfigurations ?? [] {
                config.baseConfiguration = fileRef
                linked.append(config.name)
            }
            outcome.linkedTargets += 1
            
            guard let entry = planByName[target.name] else { continue }
            if case .skip = entry.decision { continue }
            
            let shown = editsByTarget[target.name]?.bundleIDTemplate
            ?? entry.currentBundleID
            ?? AdoptionPlan.token
            outcome.adopted.append(
                .init(target: target.name, template: shown, configs: linked.sorted())
            )
        }
        
        // 2b. Baru strip.
        for target in xcodeproj.pbxproj.nativeTargets.sorted(by: { $0.name < $1.name }) {
            stripTarget(
                target,
                edits: editsByTarget[target.name] ?? TargetEdits(),
                into: &outcome.strip
            )
        }
        
        for c in plan.companions where !c.isPlistFile {
            if let to = c.to {
                outcome.companionEdits.append((c.target, c.siteLabel, c.from, to))
            }
        }
        
        // 3. Level project.
        stripProjectLevel(into: &outcome.strip)

        // 4. Tulis balik.
        try assertUnchanged()
        try xcodeproj.write(path: projectPath)
        rewritePlists(plan, into: &outcome)
        rewriteEntitlements(plan, into: &outcome)
        scanHardcodedGroups(plan, into: &outcome)
        
        outcome.git = Gitignore.ensure(sourceRoot: sourceRoot, includeXcodeDefaults: true)
        outcome.hook = HookInstaller.install(sourceRoot: sourceRoot)
        outcome.localConfigExists = (configsDir + "Local.xcconfig").exists
        
        return outcome
    }
    
    private func reasonText(_ d: TargetPlan.Decision) -> String {
        if case let .skip(reason, _) = d { return reason }
        return "—"
    }
    
    private func skipKind(_ d: TargetPlan.Decision) -> TargetPlan.SkipKind {
        if case let .skip(_, kind) = d { return kind }
        return .other
    }
    
    private func edits(from plan: AdoptionPlan) -> [String: TargetEdits] {
        var map: [String: TargetEdits] = [:]
        for e in plan.entries {
            var edit = TargetEdits()
            edit.bundleIDTemplate = e.template
            edit.settings = plan.companionSettings(for: e.target.name)
            guard edit.bundleIDTemplate != nil || !edit.settings.isEmpty else { continue }
            map[e.target.name] = edit
        }
        return map
    }
    
    private func assertNoForeignBaseConfig(_ targets: [PBXNativeTarget]) throws {
        var offenders: [String] = []
        for target in targets {
            for config in target.buildConfigurationList?.buildConfigurations ?? [] {
                guard let existing = config.baseConfiguration else { continue }
                let path = existing.path ?? existing.name ?? "?"
                if path.hasSuffix("Base.xcconfig") { continue }   // punya kita, aman
                offenders.append("\(target.name) / \(config.name)  →  \(path)")
            }
        }
        guard offenders.isEmpty else {
            throw InitError.foreignBaseConfig(offenders)
        }
    }
    
    private func registerBaseConfigFile(at path: Path) throws -> PBXFileReference {
        // Kalau udah pernah didaftarin, pakai yang lama, jangan bikin duplikat.
        if let existing = xcodeproj.pbxproj.fileReferences.first(where: {
            ($0.path ?? "").hasSuffix("Base.xcconfig")
        }) {
            return existing
        }
        guard let rootGroup = try xcodeproj.pbxproj.rootGroup() else {
            throw InitError.noRootGroup
        }
        return try rootGroup.addFile(at: path, sourceRoot: sourceRoot)
    }
    
    // Key yang harus dibuang total dari .pbxproj.
    private static let killKeys = [
        "DEVELOPMENT_TEAM",
        "PROVISIONING_PROFILE_SPECIFIER",
        "PROVISIONING_PROFILE",
    ]
    
    func runStrip() throws -> StripOutcome {
        guard (sourceRoot + "Configs" + "Base.xcconfig").exists else {
            throw StripError.notInitialized
        }
        
        let editsByTarget = edits(from: try plan(overridePrefix: nil))

        var outcome = StripOutcome()
        stripProjectLevel(into: &outcome)

        for target in xcodeproj.pbxproj.nativeTargets.sorted(by: { $0.name < $1.name }) {
            stripTarget(
                target,
                edits: editsByTarget[target.name] ?? TargetEdits(),
                into: &outcome
            )
        }

        guard !outcome.isEmpty else { return outcome }

        try assertUnchanged()
        try xcodeproj.write(path: projectPath)
        return outcome
    }
    
    private func stripProjectLevel(into outcome: inout StripOutcome) {
        guard let project = xcodeproj.pbxproj.rootObject else { return }
        for config in project.buildConfigurationList?.buildConfigurations ?? [] {
            removeKills(from: &config.buildSettings, into: &outcome)
        }
    }
    
    private static func isLinked(_ config: XCBuildConfiguration) -> Bool {
        let path = config.baseConfiguration?.path
        ?? config.baseConfiguration?.name
        ?? ""
        return path.hasSuffix("Base.xcconfig")
    }
    
    // edits.bundleIDTemplate == nil → bundle ID dibiarin (target di luar prefix).
    private func stripTarget(
        _ target: PBXNativeTarget,
        edits: TargetEdits,
        into outcome: inout StripOutcome
    ) {
        var touched = false
        var blocked = false
        
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            let before = outcome.teamsRemoved + outcome.provisioningRemoved
            removeKills(from: &config.buildSettings, into: &outcome)
            if outcome.teamsRemoved + outcome.provisioningRemoved > before { touched = true }
            
            guard Self.isLinked(config) else {
                if edits.bundleIDTemplate != nil || !edits.settings.isEmpty {
                    blocked = true
                }
                continue
            }
            
            if let template = edits.bundleIDTemplate,
               let value = config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String,
               Self.unquote(value) != template {
                config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = template
                outcome.bundleIDsRewritten += 1
                touched = true
            }
            
            for (key, template) in edits.settings {
                guard let value = config.buildSettings[key] as? String,
                      Self.unquote(value) != template else { continue }
                config.buildSettings[key] = template
                outcome.companionsRewritten += 1
                touched = true
            }
        }
        
        if blocked, !outcome.unlinkedTargets.contains(target.name) {
            outcome.unlinkedTargets.append(target.name)
        }
        
        if let project = xcodeproj.pbxproj.rootObject,
           var attrs = project.attributes(for: target),
           attrs["DevelopmentTeam"] != nil {
            attrs.removeValue(forKey: "DevelopmentTeam")
            attrs.removeValue(forKey: "ProvisioningStyle")
            project.setTargetAttributes(attrs, target: target)
            outcome.attributeTeamsRemoved += 1
            touched = true
        }
        
        if touched { outcome.touchedTargets.append(target.name) }
    }
    
    private func removeKills(
        from settings: inout [String: Any],
        into outcome: inout StripOutcome
    ) {
        for key in settings.keys {
            // Tangkap juga varian berkondisi: DEVELOPMENT_TEAM[sdk=iphoneos*]
            let base = key.split(separator: "[").first.map(String.init) ?? key
            guard Self.killKeys.contains(base) else { continue }
            settings.removeValue(forKey: key)
            if base == "DEVELOPMENT_TEAM" {
                outcome.teamsRemoved += 1
            } else {
                outcome.provisioningRemoved += 1
            }
        }
    }
    
    // XcodeProj kadang nyimpen nilai lengkap sama kutipnya.
    private static func unquote(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, t.hasPrefix("\""), t.hasSuffix("\"") else { return t }
        return String(t.dropFirst().dropLast())
    }
    
    private func rewritePlists(_ plan: AdoptionPlan, into outcome: inout InitOutcome) {
        var byPath: [String: [(key: String, to: String)]] = [:]
        
        for c in plan.companions {
            guard case let .plistFile(path) = c.site, let to = c.to else { continue }
            byPath[path, default: []].append((c.key, to))
        }
        
        for (path, list) in byPath.sorted(by: { $0.key < $1.key }) {
            let full = sourceRoot + Path(path)
            
            guard let original = try? String(contentsOfFile: full.string, encoding: .utf8),
                  PlistText.isXML(original)
            else {
                outcome.plistFailures.append(path)
                continue
            }
            
            var text = original
            var n = 0
            for e in list {
                let r = PlistText.replaceStringValue(key: e.key, with: e.to, in: text)
                text = r.text
                n += r.replaced
            }
            
            guard n > 0, text != original else { continue }
            
            do {
                try text.write(toFile: full.string, atomically: true, encoding: .utf8)
                outcome.plistEdits.append((path: path, count: n))
            } catch {
                outcome.plistFailures.append(path)
            }
            
            for c in plan.companions where c.isPlistFile && c.siteLabel == path {
                if let to = c.to {
                    outcome.companionEdits.append((c.target, path, c.from, to))
                }
            }
        }
    }
    
    private func rewriteEntitlements(_ plan: AdoptionPlan, into outcome: inout InitOutcome) {
        for p in plan.entitlementPlans.sorted(by: { $0.file.relativePath < $1.file.relativePath }) {
            guard p.hasWork else { continue }
            
            let rel = p.file.relativePath
            let full = sourceRoot + Path(rel)
            
            guard p.file.exists else {
                outcome.entitlementFailures.append((rel, "file nggak ketemu"))
                continue
            }
            guard p.file.isXML,
                  let original = try? String(contentsOfFile: full.string, encoding: .utf8)
            else {
                outcome.entitlementFailures.append((rel, "bukan XML plist — edit manual"))
                continue
            }
            
            let groupMap = Dictionary(uniqueKeysWithValues: p.appGroupRewrites.map { ($0.from, $0.to) })
            let keyMap = Dictionary(uniqueKeysWithValues: p.keychainRewrites.map { ($0.from, $0.to) })
            
            var text = original
            
            let a = PlistText.replaceArrayStrings(
                key: EntitlementsReader.appGroupKey, in: text
            ) { groupMap[$0] }
            text = a.text
            
            let k = PlistText.replaceArrayStrings(
                key: EntitlementsReader.keychainKey, in: text
            ) { keyMap[$0] }
            text = k.text
            
            guard a.replaced + k.replaced > 0, text != original else { continue }
            
            do {
                try text.write(toFile: full.string, atomically: true, encoding: .utf8)
                outcome.entitlementEdits.append((rel, a.replaced, k.replaced))
            } catch {
                outcome.entitlementFailures.append((rel, "gagal ditulis: \(error)"))
            }
        }
    }
    
    // Build setting nggak nyentuh string literal di Swift. Kalau App Group
    // di-hardcode di kode, Debug bakal nunjuk container yang nggak ada.
    private func scanHardcodedGroups(_ plan: AdoptionPlan, into outcome: inout InitOutcome) {
        for g in plan.appGroups {
            let files = SourceScanner.filesContaining(g.canonical, under: sourceRoot)
            guard !files.isEmpty else { continue }
            outcome.hardcodedGroups.append((group: g.canonical, files: files))
        }
    }
}
