//
//  ConfigAudit.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//


import Foundation
import PathKit

struct ConfigAudit {
    var baseExists = false
    var undefined: [(file: String, variable: String)] = []
    
    struct Dangling {
        let target: String
        let config: String
        let value: String
    }

    var dangling: [Dangling] = []

    var isClean: Bool { baseExists && undefined.isEmpty }

    private static let builtins: Set<String> = [
        "AppIdentifierPrefix", "TeamIdentifierPrefix",
        "PRODUCT_BUNDLE_IDENTIFIER", "PRODUCT_NAME", "DEVELOPMENT_TEAM",
        "CFBundleIdentifier", "EXECUTABLE_NAME", "MARKETING_VERSION",
        "CURRENT_PROJECT_VERSION", "SRCROOT", "CONFIGURATION",
    ]

    static func run(sourceRoot: Path, projectPath: String) -> ConfigAudit {
        var audit = ConfigAudit()

        let basePath = sourceRoot + "Configs" + "Base.xcconfig"
        audit.baseExists = basePath.exists
        guard audit.baseExists else { return audit }

        let defined = Set(BaseConfig.values(from: basePath).keys)

        guard let info = try? ProjectReader.read(projectPath) else { return audit }
        
        audit.dangling = dangling(info: info)

        var seen: Set<String> = []
        for target in info.targets {
            for rel in target.entitlementPaths where !seen.contains(rel) {
                seen.insert(rel)
                let full = sourceRoot + Path(rel)
                guard let text = try? String(contentsOfFile: full.string, encoding: .utf8)
                else { continue }

                for name in variables(in: text)
                where !defined.contains(name) && !builtins.contains(name) {
                    audit.undefined.append((file: rel, variable: name))
                }
            }
        }

        return audit
    }
    
    static func dangling(info: ProjectInfo) -> [Dangling] {
        var out: [Dangling] = []
        for target in info.targets {
            for config in target.configs {
                guard let bid = config.bundleID,
                      bid.value.contains(AdoptionPlan.token) else { continue }
                let base = config.baseConfigFile ?? ""
                guard !base.hasSuffix("Base.xcconfig") else { continue }
                out.append(
                    Dangling(target: target.name, config: config.name, value: bid.value)
                )
            }
        }
        return out
    }

    private static func variables(in text: String) -> Set<String> {
        var out: Set<String> = []
        var rest = Substring(text)

        while let open = rest.range(of: "$(") {
            let after = rest[open.upperBound...]
            guard let close = after.firstIndex(of: ")") else { break }
            let name = String(after[after.startIndex..<close])
            if !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                out.insert(name)
            }
            rest = after[after.index(after: close)...]
        }
        return out
    }
}
