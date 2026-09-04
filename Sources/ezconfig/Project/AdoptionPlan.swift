//
//  AdoptionPlan.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation
import PathKit

enum PlanError: Error, CustomStringConvertible {
    case noSignableTarget
    case noAnchor([String])
    case ambiguousAnchor([String])
    case anchorConflict(target: String, values: [String])
    
    var description: String {
        switch self {
        case .noSignableTarget:
            return "Nggak ada target yang punya PRODUCT_BUNDLE_IDENTIFIER."
        case let .noAnchor(names):
            return """
            Nggak nemu target aplikasi buat dijadiin acuan prefix.
            Target yang ada: \(names.joined(separator: ", "))
            Tentuin manual: ezconfig init --prefix com.contoh.app
            """
        case let .ambiguousAnchor(names):
            return """
            Ada \(names.count) target aplikasi: \(names.joined(separator: ", "))
            ezconfig nggak nebak yang mana yang jadi acuan.
            Tentuin manual: ezconfig init --prefix com.contoh.app
            """
        case let .anchorConflict(target, values):
            return """
            Target acuan '\(target)' punya bundle ID beda antar konfigurasi:
              \(values.joined(separator: "\n  "))
            Samain dulu di Xcode, atau tentuin manual: ezconfig init --prefix <id>
            """
        }
    }
}

struct TargetPlan {
    enum Decision {
        case anchor                        // sumber prefix, jadi $(BUNDLE_PREFIX)
        case adopt(remainder: String)      // jadi $(BUNDLE_PREFIX)<remainder>
        case alreadyAdopted                // udah pakai variabel
        case skip(reason: String)
    }
    
    let target: TargetInfo
    let decision: Decision
    let currentBundleID: String?
    
    // Nilai yang bakal ditulis ke .pbxproj.
    var template: String? {
        switch decision {
        case .anchor:                 return "$(BUNDLE_PREFIX)"
        case let .adopt(remainder):   return "$(BUNDLE_PREFIX)" + remainder
        case .alreadyAdopted, .skip:  return nil
        }
    }
    
    var isAdopted: Bool {
        switch decision {
        case .anchor, .adopt: return true
        default:              return false
        }
    }
}

struct CompanionPlan {
    enum Site {
        case buildSetting            // INFOPLIST_KEY_<key> di .pbxproj
        case plistFile(String)       // path relatif ke Info.plist
    }
    
    let target: String
    let site: Site
    let key: String                  // WKCompanionAppBundleIdentifier
    let from: String
    let to: String?                  // nil = nggak bisa diturunkan dari prefix
    
    var siteLabel: String {
        switch site {
        case .buildSetting:     return "build setting"
        case let .plistFile(p): return p
        }
    }
    
    var settingKey: String { "INFOPLIST_KEY_" + key }
    
    var isPlistFile: Bool {
        if case .plistFile = site { return true }
        return false
    }
}

struct AppGroupBinding {
    let variable: String      // APP_GROUP_ID
    let canonical: String     // group.com.revan.multitest
}

struct EntitlementsPlan {
    let file: EntitlementsInfo
    let appGroupRewrites: [(from: String, to: String)]
    let keychainRewrites: [(from: String, to: String)]
    
    var hasWork: Bool { !appGroupRewrites.isEmpty || !keychainRewrites.isEmpty }
    var blocked: Bool { file.exists && !file.isXML }
}

struct AdoptionPlan {
    let canonicalPrefix: String
    let prefixOrigin: String          // dari mana prefix-nya didapat
    let entries: [TargetPlan]
    let entitlements: [EntitlementsInfo]
    let appGroups: [AppGroupBinding]
    let entitlementPlans: [EntitlementsPlan]
    let companions: [CompanionPlan]
    let legacyPlistInfos: [InfoPlistInfo]
    
    // Build setting per target: nama setting → nilai template.
    func companionSettings(for target: String) -> [String: String] {
        var map: [String: String] = [:]
        for c in companions where c.target == target && !c.isPlistFile {
            if let to = c.to { map[c.settingKey] = to }
        }
        return map
    }
    
    var unresolvedCompanions: [CompanionPlan] {
        companions.filter { $0.to == nil }
    }
    
    var adopted: [TargetPlan]  { entries.filter(\.isAdopted) }
    var skipped:  [TargetPlan] {
        entries.filter { if case .skip = $0.decision { return true }; return false }
    }
    var legacyPlists: [(target: String, path: String)] {
        entries.compactMap { e in
            e.target.legacyInfoPlist.map { (e.target.name, $0) }
        }
    }
    
    static func make(
        info: ProjectInfo,
        overridePrefix: String? = nil
    ) throws -> AdoptionPlan {
        
        let sourceRoot = Path(info.sourceRoot)
        let signable = info.targets.filter(\.isSignable)
        guard !signable.isEmpty else { throw PlanError.noSignableTarget }
        
        // 1. Tentuin prefix kanonik.
        let (prefix, origin) = try resolvePrefix(
            info: info,
            signable: signable,
            sourceRoot: sourceRoot,
            override: overridePrefix
        )
        
        // 2. Putusin nasib tiap target.
        var entries: [TargetPlan] = []
        for target in info.targets {
            entries.append(decide(target, prefix: prefix))
        }
        
        // 3. Entitlements: kumpulin file unik, susun binding App Group.
        var seen: Set<String> = []
        var ents: [EntitlementsInfo] = []
        for target in info.targets {
            for rel in target.entitlementPaths where !seen.contains(rel) {
                seen.insert(rel)
                ents.append(EntitlementsReader.read(rel, sourceRoot: sourceRoot))
            }
        }
        
        // Nilai kanonik yang udah kesimpen dari init sebelumnya menang —
        // habis init pertama, entitlements isinya variabel, bukan literal lagi.
        var bindings = BaseConfig.appGroups(
            from: sourceRoot + "Configs" + "Base.xcconfig"
        )
        var known = Set(bindings.map(\.canonical))
        
        for literal in ents.flatMap(\.literalAppGroups).sorted() where !known.contains(literal) {
            bindings.append(
                AppGroupBinding(
                    variable: BaseConfig.variableName(index: bindings.count),
                    canonical: literal
                )
            )
            known.insert(literal)
        }
        
        let byCanonical = Dictionary(
            bindings.map { ($0.canonical, $0.variable) },
            uniquingKeysWith: { a, _ in a }
        )
        
        var entPlans: [EntitlementsPlan] = []
        for e in ents {
            var groups: [(from: String, to: String)] = []
            for g in e.literalAppGroups {
                guard let variable = byCanonical[g] else { continue }
                groups.append((from: g, to: "$(\(variable))"))
            }
            
            var keychains: [(from: String, to: String)] = []
            for k in e.literalKeychainGroups {
                let tail = EntitlementsReader.tail(of: k)
                guard tail.hasPrefix(prefix) else { continue }
                keychains.append((
                    from: k,
                    to: EntitlementsReader.head(of: k)
                    + "$(BUNDLE_PREFIX)"
                    + tail.dropFirst(prefix.count)
                ))
            }
            
            entPlans.append(
                EntitlementsPlan(
                    file: e,
                    appGroupRewrites: groups,
                    keychainRewrites: keychains
                )
            )
        }
        
        // 4. Companion reference: build setting & Info.plist lama.
        var companions: [CompanionPlan] = []
        var plistInfos: [InfoPlistInfo] = []
        
        for target in info.targets {
            if let literal = target.literalCompanion {
                companions.append(
                    CompanionPlan(
                        target: target.name,
                        site: .buildSetting,
                        key: "WKCompanionAppBundleIdentifier",
                        from: literal,
                        to: derive(literal, prefix: prefix)
                    )
                )
            }
            
            guard let rel = target.legacyInfoPlist else { continue }
            let plist = InfoPlistReader.read(rel, sourceRoot: sourceRoot)
            plistInfos.append(plist)
            
            for c in plist.literalCompanions {
                companions.append(
                    CompanionPlan(
                        target: target.name,
                        site: .plistFile(rel),
                        key: c.key,
                        from: c.value,
                        to: derive(c.value, prefix: prefix)
                    )
                )
            }
        }
        
        return AdoptionPlan(
            canonicalPrefix: prefix,
            prefixOrigin: origin,
            entries: entries,
            entitlements: ents,
            appGroups: bindings.sorted { $0.variable < $1.variable },
            entitlementPlans: entPlans,
            companions: companions,
            legacyPlistInfos: plistInfos,
        )
    }
    
    // Aturannya sama persis kayak bundle ID target: cukup hasPrefix.
    static func derive(_ value: String, prefix: String) -> String? {
        guard value.hasPrefix(prefix) else { return nil }
        return "$(BUNDLE_PREFIX)" + value.dropFirst(prefix.count)
    }
}

// Urutan: --prefix  →  Base.xcconfig  →  target aplikasi.
private func resolvePrefix(
    info: ProjectInfo,
    signable: [TargetInfo],
    sourceRoot: Path,
    override: String?
) throws -> (String, String) {
    
    if let override {
        return (override, "--prefix")
    }
    
    let base = sourceRoot + "Configs" + "Base.xcconfig"
    if base.exists, let existing = try? LocalConfig.canonicalPrefix(from: base) {
        return (existing, "Configs/Base.xcconfig")
    }
    
    // Anchor = target .application non-watchOS. Watch app punya productType
    // yang sama persis, jadi platform yang mbedain.
    var apps = signable.filter { $0.isApp && $0.platform != .watchOS }
    if apps.isEmpty {
        apps = signable.filter(\.isApp)   // project watchOS-only
    }
    
    guard !apps.isEmpty else {
        throw PlanError.noAnchor(signable.map(\.name))
    }
    guard apps.count == 1 else {
        throw PlanError.ambiguousAnchor(apps.map(\.name))
    }
    
    let anchor = apps[0]
    let literals = Set(
        anchor.configs.compactMap(\.bundleID)
            .filter { !$0.isVariable }
            .map(\.value)
    )
    
    switch literals.count {
    case 0:
        throw PlanError.noAnchor([anchor.name])
    case 1:
        return (literals.first!, "target \(anchor.name)")
    default:
        throw PlanError.anchorConflict(
            target: anchor.name,
            values: literals.sorted()
        )
    }
}

private func decide(_ target: TargetInfo, prefix: String) -> TargetPlan {
    guard target.isSignable else {
        return TargetPlan(
            target: target,
            decision: .skip(reason: "nggak punya bundle ID"),
            currentBundleID: nil
        )
    }
    
    let values = target.configs.compactMap(\.bundleID)
    let literals = Set(values.filter { !$0.isVariable }.map(\.value))
    
    if literals.isEmpty {
        return TargetPlan(
            target: target,
            decision: .alreadyAdopted,
            currentBundleID: values.first?.value
        )
    }
    
    guard literals.count == 1 else {
        return TargetPlan(
            target: target,
            decision: .skip(reason: "bundle ID beda antar konfigurasi"),
            currentBundleID: literals.sorted().joined(separator: " / ")
        )
    }
    
    let bid = literals.first!
    
    guard bid.hasPrefix(prefix) else {
        return TargetPlan(
            target: target,
            decision: .skip(reason: "di luar prefix \(prefix)"),
            currentBundleID: bid
        )
    }
    
    let remainder = String(bid.dropFirst(prefix.count))
    return TargetPlan(
        target: target,
        decision: remainder.isEmpty ? .anchor : .adopt(remainder: remainder),
        currentBundleID: bid
    )
}

