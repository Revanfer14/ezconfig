//
//  LocalConfig.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

enum SetupError: Error, CustomStringConvertible {
    case notInitialized(String)
    case noBundlePrefix(String)
    case unusableTeamID(String)

    var description: String {
        switch self {
        case let .notInitialized(path):
            return """
            Nggak nemu \(path).
            Project ini belum di-init. Yang bikin repo harus jalanin dulu:
              ezconfig init
            lalu commit hasilnya.
            """
        case let .noBundlePrefix(path):
            return """
            \(path) ada tapi nggak punya baris BUNDLE_PREFIX.
            File-nya kemungkinan diedit tangan atau bukan bikinan ezconfig.
            """
        case let .unusableTeamID(id):
            return "Team ID '\(id)' nggak bisa dijadiin suffix bundle ID."
        }
    }
}

struct SetupOutcome {
    var teamID = ""
    var displayName = ""
    var suffix = ""
    var canonicalPrefix = ""
    var localPath = ""
    var previousTeamID: String?
    var previews: [(target: String, config: String, bundleID: String)] = []
    var git = GitOutcome()
    var hook = HookOutcome()
    var appGroupPreviews: [(config: String, value: String)] = []
}

enum LocalConfig {

    // Team ID → suffix bundle ID. Deterministik, huruf kecil semua.
    static func suffix(for teamID: String) throws -> String {
        let cleaned = teamID.lowercased().filter { $0.isLetter || $0.isNumber }
        guard let first = cleaned.first else {
            throw SetupError.unusableTeamID(teamID)
        }
        return first.isNumber ? ".t\(cleaned)" : ".\(cleaned)"
    }

    // Baca `BUNDLE_PREFIX` dari Base.xcconfig, buang `$(LOCAL_SUFFIX)`-nya.
    static func canonicalPrefix(from base: Path) throws -> String {
        let text: String = try base.read()
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("BUNDLE_PREFIX"),
                  let eq = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: eq)...]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "$(LOCAL_SUFFIX)", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        throw SetupError.noBundlePrefix(base.string)
    }

    // Team ID yang kesimpen di Local.xcconfig sebelumnya, kalau ada.
    static func existingTeamID(at path: Path) -> String? {
        guard path.exists, let text: String = try? path.read() else { return nil }
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("LOCAL_DEV_TEAM"),
                  let eq = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: eq)...]
                .trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return nil
    }

    static func run(
        sourceRoot: Path,
        projectPath: String,
        identity: SigningIdentity
    ) throws -> SetupOutcome {

        var outcome = SetupOutcome()
        outcome.teamID = identity.teamID
        outcome.displayName = identity.displayName

        let configsDir = sourceRoot + "Configs"
        let basePath = configsDir + "Base.xcconfig"
        let localPath = configsDir + "Local.xcconfig"
        outcome.localPath = "Configs/Local.xcconfig"

        guard basePath.exists else {
            throw SetupError.notInitialized("Configs/Base.xcconfig")
        }

        let prefix = try canonicalPrefix(from: basePath)
        let sfx = try suffix(for: identity.teamID)
        outcome.canonicalPrefix = prefix
        outcome.suffix = sfx
        outcome.previousTeamID = existingTeamID(at: localPath)

        try XcconfigTemplate
            .local(teamID: identity.teamID, suffix: sfx)
            .write(toFile: localPath.string, atomically: true, encoding: .utf8)

        // Preview: substitusi $(BUNDLE_PREFIX) pakai nilai yang baru ditulis.
        let info = try ProjectReader.read(projectPath)
        for target in info.targets where target.isSignable {
            for config in target.configs {
                guard let template = config.bundleID?.value else { continue }
                let applied = config.name == "Debug" ? prefix + sfx : prefix
                outcome.previews.append((
                    target: target.name,
                    config: config.name,
                    bundleID: template.replacingOccurrences(
                        of: "$(BUNDLE_PREFIX)", with: applied
                    )
                ))
            }
        }
        for g in BaseConfig.appGroups(from: basePath) {
            outcome.appGroupPreviews.append((config: "Debug", value: g.canonical + sfx))
            outcome.appGroupPreviews.append((config: "Release", value: g.canonical))
        }
        
        outcome.git = Gitignore.ensure(sourceRoot: sourceRoot)
        outcome.hook = HookInstaller.install(sourceRoot: sourceRoot)
        return outcome
    }
}
