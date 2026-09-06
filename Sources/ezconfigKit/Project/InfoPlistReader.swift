//
//  InfoPlistReader.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//


import Foundation
import PathKit

struct PlistCompanion {
    let key: String
    let value: String

    var isVariable: Bool { value.contains("$(") || value.contains("${") }
}

struct InfoPlistInfo {
    let relativePath: String
    let exists: Bool
    let isXML: Bool
    let companions: [PlistCompanion]

    var literalCompanions: [PlistCompanion] {
        companions.filter { !$0.isVariable }
    }
}

enum InfoPlistReader {

    static let companionKeys: Set<String> = [
        "WKCompanionAppBundleIdentifier",
        "WKAppBundleIdentifier",
    ]

    static func read(_ relativePath: String, sourceRoot: Path) -> InfoPlistInfo {
        let full = sourceRoot + Path(relativePath)

        guard full.exists,
              let data = FileManager.default.contents(atPath: full.string)
        else {
            return InfoPlistInfo(
                relativePath: relativePath, exists: false,
                isXML: false, companions: []
            )
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        let xml = PlistText.isXML(text)

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) else {
            return InfoPlistInfo(
                relativePath: relativePath, exists: true,
                isXML: xml, companions: []
            )
        }

        var found: [PlistCompanion] = []
        scan(plist, into: &found)

        return InfoPlistInfo(
            relativePath: relativePath,
            exists: true,
            isXML: xml,
            companions: found.sorted { $0.key < $1.key }
        )
    }

    private static func scan(_ any: Any, into out: inout [PlistCompanion]) {
        if let dict = any as? [String: Any] {
            for (k, v) in dict {
                if companionKeys.contains(k), let s = v as? String {
                    out.append(PlistCompanion(key: k, value: s))
                } else {
                    scan(v, into: &out)
                }
            }
        } else if let arr = any as? [Any] {
            for v in arr { scan(v, into: &out) }
        }
    }
}
