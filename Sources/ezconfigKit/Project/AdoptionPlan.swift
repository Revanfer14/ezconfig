//
//  AdoptionPlan.swift
//  ezconfig
//

import Foundation
import PathKit

enum PlanError: Error, CustomStringConvertible {
    case noSignableTarget
    case noAnchor([String])
    case ambiguousAnchor([String])
    case anchorConflict(target: String, values: [String])
    case prefixLost(target: String)
    
    var description: String {
        switch self {
        case .noSignableTarget:
            return "No target in this project has a PRODUCT_BUNDLE_IDENTIFIER."
            
        case let .prefixLost(target):
            return """
            This project is already set up, but Configs/Base.xcconfig is missing.
            
            Target '\(target)' points at $(BUNDLE_PREFIX), and that variable only
            lives in Base.xcconfig, so the prefix cannot be recovered from the
            project file alone.
            
            Restore it:
              git checkout Configs/Base.xcconfig
            """
            
        case let .noAnchor(names):
            return """
            No app target to take the bundle ID prefix from.
            Targets found: \(names.joined(separator: ", "))
            
            Set it by hand: ezconfig init --prefix com.example.app
            """
            
        case let .ambiguousAnchor(names):
            return """
            \(names.count) app targets found: \(names.joined(separator: ", "))
            ezconfig will not guess which one the prefix comes from.
            
            Set it by hand: ezconfig init --prefix com.example.app
            """
            
        case let .anchorConflict(target, values):
            return """
            Target '\(target)' has a different bundle ID per configuration:
              \(values.joined(separator: "\n  "))
            
            Make them match in Xcode, or set the prefix by hand:
              ezconfig init --prefix <id>
            """
        }
    }
}

struct TargetPlan {
    enum Decision {
        case anchor
        case adopt(remainder: String)
        case alreadyAdopted
        case skip(reason: String, kind: SkipKind)
    }
    
    enum SkipKind {
        case watchOutsidePrefix
        case outsidePrefix
        case other
    }
    
    let target: TargetInfo
    let decision: Decision
    let currentBundleID: String?
    
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
        case buildSetting
        case plistFile(String)
    }
    
    let target: String
    let site: Site
    let key: String
    let from: String
    let to: String?
    
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
    let variable: String
    let canonical: String
}

struct EntitlementsPlan {
    let file: EntitlementsInfo
    let appGroupRewrites: [(from: String, to: String)]
    let keychainRewrites: [(from: String, to: String)]
    
    var hasWork: Bool { !appGroupRewrites.isEmpty || !keychainRewrites.isEmpty }
    var blocked: Bool { file.exists && !file.isXML }
}

// Jejak suffix lokal yang kebuang. Dilaporin biar Lead sadar Xcode barusan
// nyuntik identitas dia.
struct SuffixCleaning {
    let target: String        // "—" kalau bukan milik target tertentu
    let site: String          // "bundle ID" / "companion" / "app group" / ...
    let from: String
    let to: String
    let suffix: String
}

// Komponen yang bentuknya kayak suffix tapi nggak ada di himpunan yang dikenal.
// Nggak di-strip — cuma dilaporin.
struct SuspiciousSuffix {
    let target: String
    let site: String
    let value: String
    let resolved: String
    let component: String
}

struct AdoptionPlan {
    let canonicalPrefix: String
    let prefixOrigin: String
    let entries: [TargetPlan]
    let entitlements: [EntitlementsInfo]
    let appGroups: [AppGroupBinding]
    let entitlementPlans: [EntitlementsPlan]
    let companions: [CompanionPlan]
    let legacyPlistInfos: [InfoPlistInfo]
    let cleanings: [SuffixCleaning]
    let suspicious: [SuspiciousSuffix]
    
    static let token = "$(BUNDLE_PREFIX)"
    
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
    var skippedSignable: [TargetPlan] {
        skipped.filter { $0.target.isSignable }
    }
    var legacyPlists: [(target: String, path: String)] {
        entries.compactMap { e in
            e.target.legacyInfoPlist.map { (e.target.name, $0) }
        }
    }
    
    static func make(
        info: ProjectInfo,
        overridePrefix: String? = nil,
        knownSuffixes: Set<String> = []
    ) throws -> AdoptionPlan {
        
        let sourceRoot = Path(info.sourceRoot)
        let signable = info.targets.filter(\.isSignable)
        guard !signable.isEmpty else { throw PlanError.noSignableTarget }
        
        var cleanings: [SuffixCleaning] = []
        var suspicious: [SuspiciousSuffix] = []
        
        // 1. Prefix kanonik.
        let (prefix, origin) = try resolvePrefix(
            info: info,
            signable: signable,
            sourceRoot: sourceRoot,
            override: overridePrefix,
            suffixes: knownSuffixes
        )
        
        let anchors = [prefix, token]
        
        // 2. Nasib tiap target.
        var entries: [TargetPlan] = []
        for target in info.targets {
            entries.append(
                decide(
                    target,
                    prefix: prefix,
                    suffixes: knownSuffixes,
                    cleanings: &cleanings,
                    suspicious: &suspicious
                )
            )
        }
        
        // 3. Entitlements.
        var seen: Set<String> = []
        var ents: [EntitlementsInfo] = []
        for target in info.targets {
            for rel in target.entitlementPaths where !seen.contains(rel) {
                seen.insert(rel)
                ents.append(EntitlementsReader.read(rel, sourceRoot: sourceRoot))
            }
        }
        
        // Binding yang udah ada di Base.xcconfig bisa ikut tercemar kalau init
        // buggy pernah jalan — bersihin duluan biar jadi acuan yang bener.
        var bindings: [AppGroupBinding] = []
        for b in BaseConfig.appGroups(from: sourceRoot + "Configs" + "Base.xcconfig") {
            let c = SuffixCleaner.cleanTrailing(b.canonical, suffixes: knownSuffixes)
            if let removed = c.removed {
                cleanings.append(
                    SuffixCleaning(
                        target: "—",
                        site: "Base.xcconfig / \(b.variable)",
                        from: b.canonical, to: c.value, suffix: removed
                    )
                )
            }
            bindings.append(AppGroupBinding(variable: b.variable, canonical: c.value))
        }
        
        var known = Set(bindings.map(\.canonical))
        
        // Literal apa adanya → nilai kanonik. Pembersihan HARUS sebelum dedup,
        // kalau nggak `group.x.ns8wsvtkad` kedaftar jadi APP_GROUP_ID_2 palsu.
        var groupCanonical: [String: String] = [:]
        for literal in ents.flatMap(\.literalAppGroups).sorted() {
            guard groupCanonical[literal] == nil else { continue }
            
            let c = SuffixCleaner.cleanAppGroup(
                literal,
                knownCanonicals: bindings.map(\.canonical),
                suffixes: knownSuffixes
            )
            groupCanonical[literal] = c.value
            
            if let removed = c.removed {
                cleanings.append(
                    SuffixCleaning(
                        target: "—", site: "app group",
                        from: literal, to: c.value, suffix: removed
                    )
                )
            }
            
            guard !known.contains(c.value) else { continue }
            bindings.append(
                AppGroupBinding(
                    variable: BaseConfig.variableName(index: bindings.count),
                    canonical: c.value
                )
            )
            known.insert(c.value)
        }
        
        let byCanonical = Dictionary(
            bindings.map { ($0.canonical, $0.variable) },
            uniquingKeysWith: { a, _ in a }
        )
        
        var entPlans: [EntitlementsPlan] = []
        for e in ents {
            var groups: [(from: String, to: String)] = []
            for g in e.literalAppGroups {
                let canonical = groupCanonical[g] ?? g
                guard let variable = byCanonical[canonical] else { continue }
                groups.append((from: g, to: "$(\(variable))"))
            }
            
            var keychains: [(from: String, to: String)] = []
            for k in e.literalKeychainGroups {
                let head = EntitlementsReader.head(of: k)
                let rawTail = EntitlementsReader.tail(of: k)
                
                // Udah diadopsi tapi ekornya tercemar:
                // $(AppIdentifierPrefix)$(BUNDLE_PREFIX).ns8wsvtkad
                if head.hasSuffix(token) {
                    let c = SuffixCleaner.clean(rawTail, anchors: [""], suffixes: knownSuffixes)
                    guard let removed = c.removed else { continue }
                    cleanings.append(
                        SuffixCleaning(
                            target: "—", site: "keychain group",
                            from: k, to: head + c.value, suffix: removed
                        )
                    )
                    keychains.append((from: k, to: head + c.value))
                    continue
                }
                
                let c = SuffixCleaner.clean(rawTail, anchors: [prefix], suffixes: knownSuffixes)
                guard c.value.hasPrefix(prefix) else { continue }
                if let removed = c.removed {
                    cleanings.append(
                        SuffixCleaning(
                            target: "—", site: "keychain group",
                            from: k, to: head + token + c.value.dropFirst(prefix.count),
                            suffix: removed
                        )
                    )
                }
                keychains.append((
                    from: k,
                    to: head + token + c.value.dropFirst(prefix.count)
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
        
        // 4. Companion reference.
        var companions: [CompanionPlan] = []
        var plistInfos: [InfoPlistInfo] = []
        
        for target in info.targets {
            for raw in target.companionValues {
                guard let c = companionPlan(
                    target: target.name, site: .buildSetting,
                    key: "WKCompanionAppBundleIdentifier", raw: raw,
                    prefix: prefix, anchors: anchors, suffixes: knownSuffixes,
                    cleanings: &cleanings, suspicious: &suspicious
                ) else { continue }
                companions.append(c)
            }
            
            guard let rel = target.legacyInfoPlist else { continue }
            let plist = InfoPlistReader.read(rel, sourceRoot: sourceRoot)
            plistInfos.append(plist)
            
            for entry in plist.companions {
                guard let c = companionPlan(
                    target: target.name, site: .plistFile(rel),
                    key: entry.key, raw: entry.value,
                    prefix: prefix, anchors: anchors, suffixes: knownSuffixes,
                    cleanings: &cleanings, suspicious: &suspicious
                ) else { continue }
                companions.append(c)
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
            cleanings: cleanings,
            suspicious: suspicious
        )
    }
    
    static func derive(_ value: String, prefix: String) -> String? {
        if value.hasPrefix(token) { return value }
        guard value.hasPrefix(prefix) else { return nil }
        return token + value.dropFirst(prefix.count)
    }
}

private func companionPlan(
    target: String,
    site: CompanionPlan.Site,
    key: String,
    raw: String,
    prefix: String,
    anchors: [String],
    suffixes: Set<String>,
    cleanings: inout [SuffixCleaning],
    suspicious: inout [SuspiciousSuffix]
) -> CompanionPlan? {
    
    let c = SuffixCleaner.clean(raw, anchors: anchors, suffixes: suffixes)
    let to = AdoptionPlan.derive(c.value, prefix: prefix)
    
    if let to, let s = SuffixCleaner.suspiciousComponent(
        in: String(to.dropFirst(AdoptionPlan.token.count))
    ) {
        suspicious.append(
            SuspiciousSuffix(
                target: target, site: "companion",
                value: raw, resolved: to, component: s
            )
        )
    }
    
    let isLiteral = !raw.contains("$(") && !raw.contains("${")
    guard c.didClean || isLiteral else { return nil }
    
    if let removed = c.removed {
        cleanings.append(
            SuffixCleaning(
                target: target, site: "companion",
                from: raw, to: to ?? c.value,
                suffix: removed
            )
        )
    }
    
    return CompanionPlan(target: target, site: site, key: key, from: raw, to: to)
}

// Urutan: --prefix  →  Base.xcconfig  →  target aplikasi.
private func resolvePrefix(
    info: ProjectInfo,
    signable: [TargetInfo],
    sourceRoot: Path,
    override: String?,
    suffixes: Set<String>
) throws -> (String, String) {
    
    if let override {
        return (override, "--prefix")
    }
    
    let base = sourceRoot + "Configs" + "Base.xcconfig"
    if base.exists, let existing = try? LocalConfig.canonicalPrefix(from: base) {
        return (existing, "Configs/Base.xcconfig")
    }
    
    var apps = signable.filter { $0.isApp && $0.platform != .watchOS }
    if apps.isEmpty {
        apps = signable.filter(\.isApp)
    }
    
    guard !apps.isEmpty else {
        throw PlanError.noAnchor(signable.map(\.name))
    }
    guard apps.count == 1 else {
        throw PlanError.ambiguousAnchor(apps.map(\.name))
    }
    
    let anchor = apps[0]
    // Base.xcconfig nggak ada tapi Local.xcconfig ada → anchor-nya sendiri
    // bisa tercemar. Suffix app selalu di ekor.
    let all = anchor.configs.compactMap(\.bundleID)
    let literals = Set(
        all.filter { !$0.isVariable }
            .map { SuffixCleaner.cleanTrailing($0.value, suffixes: suffixes).value }
    )
    
    switch literals.count {
    case 0:
        // Anchor ketemu tapi nilainya variabel semua: project udah pernah
        // di-init, Base.xcconfig-nya yang ilang.
        if all.contains(where: \.isVariable) {
            throw PlanError.prefixLost(target: anchor.name)
        }
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

private enum Normalized {
    case derived(String)     // remainder relatif prefix
    case foreign             // variabel orang lain — jangan disentuh
    case outside(String)     // literal di luar prefix
}

private func normalize(_ value: String, prefix: String) -> Normalized {
    if value.hasPrefix(AdoptionPlan.token) {
        return .derived(String(value.dropFirst(AdoptionPlan.token.count)))
    }
    if value.hasPrefix(prefix) {
        return .derived(String(value.dropFirst(prefix.count)))
    }
    if value.contains("$(") || value.contains("${") {
        return .foreign
    }
    return .outside(value)
}

private func decide(
    _ target: TargetInfo,
    prefix: String,
    suffixes: Set<String>,
    cleanings: inout [SuffixCleaning],
    suspicious: inout [SuspiciousSuffix]
) -> TargetPlan {
    
    guard target.isSignable else {
        return TargetPlan(
            target: target,
            decision: .skip(reason: "nggak punya bundle ID", kind: .other),
            currentBundleID: nil
        )
    }
    
    let anchors = [prefix, AdoptionPlan.token]
    
    var rawValues: [String] = []
    var remainders: Set<String> = []
    var outside: [String] = []
    var didClean = false
    var sawForeign = false
    
    for v in target.configs.compactMap(\.bundleID) {
        guard !rawValues.contains(v.value) else { continue }
        rawValues.append(v.value)
        
        let c = SuffixCleaner.clean(v.value, anchors: anchors, suffixes: suffixes)
        if let removed = c.removed {
            didClean = true
            cleanings.append(
                SuffixCleaning(
                    target: target.name, site: "bundle ID",
                    from: v.value,
                    to: AdoptionPlan.derive(c.value, prefix: prefix) ?? c.value,
                    suffix: removed
                )
            )
        }
        
        switch normalize(c.value, prefix: prefix) {
        case let .derived(remainder):
            remainders.insert(remainder)
            if let s = SuffixCleaner.suspiciousComponent(in: remainder) {
                suspicious.append(
                    SuspiciousSuffix(
                        target: target.name, site: "bundle ID",
                        value: v.value,
                        resolved: AdoptionPlan.token + remainder,
                        component: s
                    )
                )
            }
        case .foreign:
            sawForeign = true
        case let .outside(literal):
            outside.append(literal)
        }
    }
    
    guard outside.isEmpty else {
        let isWatchApp = target.platform == .watchOS && target.isApp
        let reason = isWatchApp
            ? "watch app di luar prefix \(prefix)"
            : "di luar prefix \(prefix)"

        return TargetPlan(
            target: target,
            decision: .skip(
                reason: reason,
                kind: isWatchApp ? .watchOutsidePrefix : .outsidePrefix
            ),
            currentBundleID: Set(outside).sorted().joined(separator: " / ")
        )
    }
    
    if remainders.isEmpty && sawForeign {
        return TargetPlan(
            target: target,
            decision: .alreadyAdopted,
            currentBundleID: rawValues.first
        )
    }
    
    guard remainders.count == 1 else {
        return TargetPlan(
            target: target,
            decision: .skip(reason: "bundle ID beda antar konfigurasi", kind: .other),
            currentBundleID: rawValues.sorted().joined(separator: " / ")
        )
    }
    
    // Nilai udah bentuk variabel, seragam, dan nggak ada yang dibersihin →
    // biarin. Ini yang bikin `init` idempoten dan output-nya stabil.
    if !didClean, rawValues.count == 1, rawValues[0].hasPrefix(AdoptionPlan.token) {
        return TargetPlan(
            target: target,
            decision: .alreadyAdopted,
            currentBundleID: rawValues[0]
        )
    }
    
    let remainder = remainders.first!
    return TargetPlan(
        target: target,
        decision: remainder.isEmpty ? .anchor : .adopt(remainder: remainder),
        currentBundleID: rawValues.sorted().joined(separator: " / ")
    )
}
