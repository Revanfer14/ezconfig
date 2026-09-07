//
//  ProjectReader.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit
import XcodeProj

enum ReaderError: Error, CustomStringConvertible {
    case notFound(String)
    case ambiguous([String])
    case noRootObject
    
    var description: String {
        switch self {
        case .notFound(let path):
            return ".xcodeproj not found in \(path)"
        case .ambiguous(let names):
            return """
            Found more than one .xcodeproj: \(names.joined(separator: ", "))
            Choose one using --path
            """
        case .noRootObject:
            return "File .pbxproj corrupt. No root object found."
        }
    }
}

enum ProjectReader {
    static func locate(in path: String) throws -> String {
        let fm = FileManager.default
        var expanded = (path as NSString).expandingTildeInPath
        while expanded.count > 1 && expanded.hasSuffix("/") { expanded.removeLast() }
        
        if expanded.hasSuffix(".xcodeproj") {
            guard fm.fileExists(atPath: expanded) else {
                throw ReaderError.notFound(expanded)
            }
            return canonicalize(expanded, fm: fm)
        }
        
        let items = (try? fm.contentsOfDirectory(atPath: expanded)) ?? []
        let projects = items.filter { $0.hasSuffix(".xcodeproj") }.sorted()
        
        switch projects.count {
        case 0:  throw ReaderError.notFound(expanded)
        case 1:  return (expanded as NSString).appendingPathComponent(projects[0])
        default: throw ReaderError.ambiguous(projects)
        }
    }
    
    private static func canonicalize(_ path: String, fm: FileManager) -> String {
        let ns = path as NSString
        let parentRaw = ns.deletingLastPathComponent
        let parent = parentRaw.isEmpty ? "." : parentRaw
        let name = ns.lastPathComponent
        
        let items = (try? fm.contentsOfDirectory(atPath: parent)) ?? []
        guard let real = items.first(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            return path
        }
        return (parent as NSString).appendingPathComponent(real)
    }
    
    static func read(_ projectPath: String) throws -> ProjectInfo {
        let xcodeproj = try XcodeProj(path: Path(projectPath))
        let pbxproj = xcodeproj.pbxproj
        
        guard let root = pbxproj.rootObject else {
            throw ReaderError.noRootObject
        }
        
        // Build settings di level project
        var projectSettings: [String: [String: Any]] = [:]
        for config in root.buildConfigurationList?.buildConfigurations ?? [] {
            projectSettings[config.name] = config.buildSettings
        }
        
        var targets: [TargetInfo] = []
        
        for target in pbxproj.nativeTargets.sorted(by: { $0.name < $1.name }) {
            let attrs = root.targetAttributes[target]
            let attributeTeam = unquote(attrs?["DevelopmentTeam"])
            
            var configs: [ConfigInfo] = []
            for config in target.buildConfigurationList?.buildConfigurations ?? [] {
                let targetSettings = config.buildSettings
                let fallback = projectSettings[config.name] ?? [:]
                
                configs.append(
                    ConfigInfo(
                        name: config.name,
                        bundleID: resolve("PRODUCT_BUNDLE_IDENTIFIER",
                                          target: targetSettings, project: fallback),
                        team: resolve("DEVELOPMENT_TEAM",
                                      target: targetSettings, project: fallback),
                        baseConfigFile: config.baseConfiguration?.name
                        ?? config.baseConfiguration?.path,
                        sdkroot: resolve("SDKROOT",
                                         target: targetSettings, project: fallback)?.value,
                        entitlements: resolve("CODE_SIGN_ENTITLEMENTS",
                                              target: targetSettings, project: fallback),
                        companionBundleID: resolve("INFOPLIST_KEY_WKCompanionAppBundleIdentifier",
                                                   target: targetSettings, project: fallback),
                        infoPlistFile: resolve("INFOPLIST_FILE",
                                               target: targetSettings, project: fallback),
                        generatesInfoPlist: resolve("GENERATE_INFOPLIST_FILE",
                                                    target: targetSettings, project: fallback)?
                            .value.uppercased() == "YES"
                    )
                )
            }
            
            let sortedConfigs = configs.sorted { $0.name < $1.name }
            let sdkroot = sortedConfigs.compactMap(\.sdkroot).first
            
            targets.append(
                TargetInfo(
                    name: target.name,
                    productType: label(target.productType?.rawValue),
                    rawProductType: target.productType?.rawValue ?? "",
                    platform: Platform(sdkroot: sdkroot),
                    attributeTeam: attributeTeam,
                    configs: sortedConfigs
                )
            )
        }
        
        let name = ((projectPath as NSString).lastPathComponent as NSString)
            .deletingPathExtension
        
        return ProjectInfo(path: projectPath, name: name, targets: targets)
    }
    
    private static func resolve(
        _ key: String,
        target: [String: Any],
        project: [String: Any]
    ) -> SettingValue? {
        if let v = unquote(target[key]) {
            return SettingValue(value: v, source: .target)
        }
        if let v = unquote(project[key]) {
            return SettingValue(value: v, source: .project)
        }
        return nil
    }
    
    // Helper to remove quote in .pbxproj
    private static func unquote(_ any: Any?) -> String? {
        guard let raw = any as? String else { return nil }
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
            s = String(s.dropFirst().dropLast())
        }
        return s.isEmpty ? nil : s
    }
    
    private static func label(_ rawProductType: String?) -> String {
        guard let raw = rawProductType else { return "unknown" }
        let short = raw.replacingOccurrences(
            of: "com.apple.product-type.", with: ""
        )
        let friendly: [String: String] = [
            "application": "app",
            "application.watchapp2": "watchOS app",
            "application.on-demand-install-capable": "app clip",
            "app-extension": "extension",
            "watchkit2-extension": "watch extension",
            "framework": "framework",
            "bundle.unit-test": "unit tests",
            "bundle.ui-testing": "UI tests",
        ]
        return friendly[short] ?? short
    }
}
