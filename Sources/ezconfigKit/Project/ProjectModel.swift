//
//  ProjectModel.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

enum Platform: String {
    case iOS
    case watchOS
    case macOS
    case tvOS
    case visionOS
    case unknown
    
    init(sdkroot: String?) {
        switch sdkroot?.lowercased() {
        case let s? where s.hasPrefix("iphoneos"):  self = .iOS
        case let s? where s.hasPrefix("watchos"):   self = .watchOS
        case let s? where s.hasPrefix("macosx"):    self = .macOS
        case let s? where s.hasPrefix("appletvos"): self = .tvOS
        case let s? where s.hasPrefix("xros"):      self = .visionOS
        default: self = .unknown
        }
    }
}

struct SettingValue {
    enum Source: String {
        case target = "target"
        case project = "project"
    }
    
    let value: String
    let source: Source
    
    // Buat command 'check'
    var isVariable: Bool {
        value.contains("$(") || value.contains("${")
    }
    
    
}

struct ConfigInfo {
    let name: String              // "Debug" / "Release"
    let bundleID: SettingValue?
    let team: SettingValue?
    let baseConfigFile: String?   // .xcconfig yang udah ke-link
    let sdkroot: String? // Tipe target
    
    let entitlements: SettingValue?       // CODE_SIGN_ENTITLEMENTS
    let companionBundleID: SettingValue?  // INFOPLIST_KEY_WKCompanionAppBundleIdentifier
    let infoPlistFile: SettingValue?      // INFOPLIST_FILE (project lama)
    let generatesInfoPlist: Bool          // GENERATE_INFOPLIST_FILE == YES
}

struct TargetInfo {
    let name: String
    let productType: String
    let rawProductType: String
    let platform: Platform
    
    // DEVELOPMENT_TEAM yang nyempil di attributes
    let attributeTeam: String?
    let configs: [ConfigInfo]
    
    // Target yang punya bundle ID di config mana pun = target yang perlu diadopsi.
    var isSignable: Bool {
        configs.contains { $0.bundleID != nil }
    }
    
    var isApp: Bool {
        rawProductType == "com.apple.product-type.application"
    }
    
    var isEmbedded: Bool {
        rawProductType.contains("extension") || (isApp && platform == .watchOS)
    }
    
    var entitlementPaths: [String] {
        var seen: [String] = []
        for c in configs {
            guard let p = c.entitlements?.value, !seen.contains(p) else { continue }
            seen.append(p)
        }
        return seen
    }
    
    var companionValues: [String] {
        var seen: [String] = []
        for c in configs {
            guard let v = c.companionBundleID?.value, !seen.contains(v) else { continue }
            seen.append(v)
        }
        return seen
    }
    
    var legacyInfoPlist: String? {
        guard let c = configs.first(where: { !$0.generatesInfoPlist }),
              let p = c.infoPlistFile?.value else { return nil }
        return p
    }
    
    var displayType: String {
        switch (platform, productType) {
        case (.watchOS, "app"): return "watchOS app"
        case (.iOS, "app"):     return "iOS app"
        case (.macOS, "app"):   return "macOS app"
        default:
            return platform == .unknown
            ? productType
            : "\(productType) (\(platform.rawValue))"
        }
    }
}

struct ProjectInfo {
    let path: String
    let name: String
    let targets: [TargetInfo]
    
    var sourceRoot: String {
        (path as NSString).deletingLastPathComponent
    }
    
    var literalFindings: [(target: String, config: String, key: String, value: String)] {
        var out: [(String, String, String, String)] = []
        for t in targets {
            if let at = t.attributeTeam {
                out.append((t.name, "—", "TargetAttributes.DevelopmentTeam", at))
            }
            for c in t.configs {
                if let team = c.team, !team.isVariable {
                    out.append((t.name, c.name, "DEVELOPMENT_TEAM", team.value))
                }
                if let bid = c.bundleID, !bid.isVariable {
                    out.append((t.name, c.name, "PRODUCT_BUNDLE_IDENTIFIER", bid.value))
                }
            }
        }
        return out.map { (target: $0.0, config: $0.1, key: $0.2, value: $0.3) }
    }
}
