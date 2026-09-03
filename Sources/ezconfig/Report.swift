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
}
