//
//  ProjectWriter.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit
import XcodeProj

enum InitError: Error, CustomStringConvertible {
    case noNativeTarget
    case multipleTargets([String])
    case noBundleID(target: String)
    case conflictingBundleIDs(target: String, values: [String])
    case foreignBaseConfig(target: String, config: String, existing: String)
    case noRootGroup

    var description: String {
        switch self {
        case .noNativeTarget:
            return "Nggak nemu native target di project ini."
        case let .multipleTargets(names):
            return """
            Project punya \(names.count) target: \(names.joined(separator: ", ")).
            Fase 2 baru dukung single target. Multi-target nyusul.
            """
        case let .noBundleID(target):
            return """
            Target '\(target)' nggak punya PRODUCT_BUNDLE_IDENTIFIER literal.
            Mungkin project ini udah pernah di-init.
            """
        case let .conflictingBundleIDs(target, values):
            return """
            Target '\(target)' punya bundle ID beda antar konfigurasi:
              \(values.joined(separator: "\n  "))
            Samain dulu di Xcode, atau tentuin manual: ezconfig init --prefix <id>
            """
        case let .foreignBaseConfig(target, config, existing):
            return """
            Target '\(target)' konfigurasi '\(config)' udah punya xcconfig: \(existing)
            ezconfig nggak bakal nimpa punya orang. Handling ini nyusul di fase lain.
            """
        case .noRootGroup:
            return "Project nggak punya root group — struktur nggak wajar."
        }
    }
}

enum StripError: Error, CustomStringConvertible {
    case notInitialized

    var description: String {
        """
        Project ini belum di-init — Configs/Base.xcconfig nggak ada.
        `check --fix` nulis PRODUCT_BUNDLE_IDENTIFIER jadi $(BUNDLE_PREFIX),
        variabel yang cuma hidup di Base.xcconfig. Tanpa itu project-nya rusak.
        Jalanin dulu: ezconfig init
        """
    }
}

struct StripOutcome {
    var teamsRemoved = 0
    var provisioningRemoved = 0
    var attributeTeamsRemoved = 0
    var bundleIDsRewritten = 0
    var touchedTargets: [String] = []

    var isEmpty: Bool {
        teamsRemoved == 0 && provisioningRemoved == 0
            && attributeTeamsRemoved == 0 && bundleIDsRewritten == 0
    }
}

struct InitOutcome {
    var targetName = ""
    var canonicalPrefix = ""
    var strip = StripOutcome()
    var linkedConfigurations: [String] = []
    var baseConfigPath = ""
    var localConfigExists = false
    var hook = HookOutcome()
}

struct ProjectWriter {

    let projectPath: Path      // .../SignTest.xcodeproj
    let sourceRoot: Path       // folder induknya
    private let xcodeproj: XcodeProj

    init(projectPath: Path) throws {
        self.projectPath = projectPath
        self.sourceRoot = projectPath.parent()
        self.xcodeproj = try XcodeProj(path: projectPath)
    }

    func runInit(overridePrefix: String?, dryRun: Bool) throws -> InitOutcome {
        var outcome = InitOutcome()

        let target = try singleNativeTarget()
        outcome.targetName = target.name

        let prefix = try overridePrefix ?? canonicalBundleID(for: target)
        outcome.canonicalPrefix = prefix

        try assertNoForeignBaseConfig(target)

        // 1. Tulis Base.xcconfig ke disk duluan.
        let configsDir = sourceRoot + "Configs"
        let basePath = configsDir + "Base.xcconfig"
        outcome.baseConfigPath = "Configs/Base.xcconfig"

        if !dryRun {
            try FileManager.default.createDirectory(
                atPath: configsDir.string,
                withIntermediateDirectories: true
            )
            try XcconfigTemplate
                .base(canonicalPrefix: prefix)
                .write(toFile: basePath.string, atomically: true, encoding: .utf8)
        }

        outcome.localConfigExists = (configsDir + "Local.xcconfig").exists
        guard !dryRun else { return outcome }

        // 2. Daftarin ke project & sambungin ke tiap konfigurasi.
        let fileRef = try registerBaseConfigFile(at: basePath)
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            config.baseConfiguration = fileRef
            outcome.linkedConfigurations.append(config.name)
        }

        // 3. Strip identitas.
        stripProjectLevel(into: &outcome.strip)
        stripTarget(target, into: &outcome.strip)

        // 4. Tulis balik.
        try xcodeproj.write(path: projectPath)
        
        outcome.hook = HookInstaller.install(sourceRoot: sourceRoot)
        outcome.localConfigExists = (configsDir + "Local.xcconfig").exists
        
        return outcome
    }

    private func singleNativeTarget() throws -> PBXNativeTarget {
        let targets = xcodeproj.pbxproj.nativeTargets
        guard !targets.isEmpty else { throw InitError.noNativeTarget }
        guard targets.count == 1 else {
            throw InitError.multipleTargets(targets.map(\.name))
        }
        return targets[0]
    }

    // Ambil bundle ID kanonik
    private func canonicalBundleID(for target: PBXNativeTarget) throws -> String {
        var literals: Set<String> = []
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            guard let value = config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String
            else { continue }
            if value.contains("$(") || value.contains("${") { continue }
            literals.insert(value)
        }

        switch literals.count {
        case 0: throw InitError.noBundleID(target: target.name)
        case 1: return literals.first!
        default:
            throw InitError.conflictingBundleIDs(
                target: target.name,
                values: literals.sorted()
            )
        }
    }

    private func assertNoForeignBaseConfig(_ target: PBXNativeTarget) throws {
        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            guard let existing = config.baseConfiguration else { continue }
            let path = existing.path ?? existing.name ?? "?"
            if path.hasSuffix("Base.xcconfig") { continue }   // punya kita, aman
            throw InitError.foreignBaseConfig(
                target: target.name,
                config: config.name,
                existing: path
            )
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

        var outcome = StripOutcome()
        stripProjectLevel(into: &outcome)
        for target in xcodeproj.pbxproj.nativeTargets.sorted(by: { $0.name < $1.name }) {
            stripTarget(target, into: &outcome)
        }

        // Jangan nulis kalau nggak ada yang berubah — XcodeProj bakal
        // nulis ulang seluruh file dan bikin diff palsu.
        guard !outcome.isEmpty else { return outcome }

        try xcodeproj.write(path: projectPath)
        return outcome
    }

    private func stripProjectLevel(into outcome: inout StripOutcome) {
        guard let project = xcodeproj.pbxproj.rootObject else { return }
        for config in project.buildConfigurationList?.buildConfigurations ?? [] {
            removeKills(from: &config.buildSettings, into: &outcome)
        }
    }

    private func stripTarget(_ target: PBXNativeTarget, into outcome: inout StripOutcome) {
        var touched = false

        for config in target.buildConfigurationList?.buildConfigurations ?? [] {
            let before = outcome.teamsRemoved + outcome.provisioningRemoved
            removeKills(from: &config.buildSettings, into: &outcome)
            if outcome.teamsRemoved + outcome.provisioningRemoved > before { touched = true }

            if let value = config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String,
               !value.contains("$("), !value.contains("${") {
                config.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = "$(BUNDLE_PREFIX)"
                outcome.bundleIDsRewritten += 1
                touched = true
            }
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
}
