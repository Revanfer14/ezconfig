//
//  EntitlementsReader.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation
import PathKit

struct EntitlementsInfo {
    let relativePath: String
    let exists: Bool
    let isXML: Bool
    let appGroups: [String]
    let keychainGroups: [String]

    // App Group: nilai apa adanya, variabel = udah beres.
    var literalAppGroups: [String] {
        appGroups.filter { !$0.contains("$(") }
    }

    var literalKeychainGroups: [String] {
        keychainGroups.filter { !EntitlementsReader.tail(of: $0).isEmpty }
    }

    var isClean: Bool {
        literalAppGroups.isEmpty && literalKeychainGroups.isEmpty
    }
}

enum EntitlementsReader {

    static let appGroupKey = "com.apple.security.application-groups"
    static let keychainKey = "keychain-access-groups"

    // Buang token $(...) yang nempel di depan, sisain bagian literalnya.
    static func tail(of value: String) -> String {
        var rest = Substring(value)
        while rest.hasPrefix("$("), let close = rest.firstIndex(of: ")") {
            rest = rest[rest.index(after: close)...]
        }
        return rest.contains("$(") ? "" : String(rest)
    }

    static func head(of value: String) -> String {
        String(value.dropLast(tail(of: value).count))
    }

    static func read(_ relativePath: String, sourceRoot: Path) -> EntitlementsInfo {
        let full = sourceRoot + Path(relativePath)

        guard full.exists,
              let data = FileManager.default.contents(atPath: full.string)
        else {
            return EntitlementsInfo(
                relativePath: relativePath, exists: false,
                isXML: false, appGroups: [], keychainGroups: []
            )
        }

        let xml = PlistText.isXML(String(data: data, encoding: .utf8) ?? "")

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return EntitlementsInfo(
                relativePath: relativePath, exists: true,
                isXML: xml, appGroups: [], keychainGroups: []
            )
        }

        return EntitlementsInfo(
            relativePath: relativePath,
            exists: true,
            isXML: xml,
            appGroups: plist[appGroupKey] as? [String] ?? [],
            keychainGroups: plist[keychainKey] as? [String] ?? []
        )
    }
}
