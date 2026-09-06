//
//  PbxprojScanner.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//


import Foundation

struct Finding {
    enum Key: String {
        case developmentTeam       = "DEVELOPMENT_TEAM"
        case attributeTeam         = "DevelopmentTeam"
        case bundleID              = "PRODUCT_BUNDLE_IDENTIFIER"
        case provisioningSpecifier = "PROVISIONING_PROFILE_SPECIFIER"
        case provisioningProfile   = "PROVISIONING_PROFILE"
        case companionBundleID     = "INFOPLIST_KEY_WKCompanionAppBundleIdentifier"

        var label: String {
            switch self {
            case .attributeTeam:     return "TargetAttributes.DevelopmentTeam"
            case .companionBundleID: return "WKCompanionAppBundleIdentifier"
            default:                 return rawValue
            }
        }
    }

    enum Kind {
        case literal
        case localSuffix(String)
    }

    let key: Key
    let kind: Kind
    let value: String
    let line: Int

    var isSuffixLeak: Bool {
        if case .localSuffix = kind { return true }
        return false
    }

    var suffix: String? {
        if case let .localSuffix(s) = kind { return s }
        return nil
    }
}

enum PbxprojScanner {

    // Scan .pbxproj, balikin nilai literal yang nggak boleh ke-commit.
    static func scan(_ text: String, suffixes: Set<String> = []) -> [Finding] {
        var findings: [Finding] = []

        let ordered = suffixes
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasSuffix(";"), let eq = line.firstIndex(of: "=") else { continue }

            // Kiri tanda '=', buang varian berkondisi: DEVELOPMENT_TEAM[sdk=iphoneos*]
            var rawKey = String(line[line.startIndex..<eq])
                .trimmingCharacters(in: .whitespaces)
            if let bracket = rawKey.firstIndex(of: "[") {
                rawKey = String(rawKey[rawKey.startIndex..<bracket])
                    .trimmingCharacters(in: .whitespaces)
            }
            guard let key = Finding.Key(rawValue: rawKey) else { continue }

            // Kanan tanda '=', buang ';' penutup lalu kutipnya
            var value = String(line[line.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces)
            value.removeLast()
            value = unquote(value.trimmingCharacters(in: .whitespaces))

            guard !value.isEmpty else { continue }

            guard value.contains("$(") || value.contains("${") else {
                findings.append(Finding(key: key, kind: .literal, value: value, line: index + 1))
                continue
            }

            guard value.contains(AdoptionPlan.token) else { continue }

            guard let hit = ordered.first(where: { value.contains($0) }) else { continue }

            findings.append(
                Finding(key: key, kind: .localSuffix(hit), value: value, line: index + 1)
            )
        }

        return findings
    }

    static func scan(fileAt path: String, suffixes: Set<String> = []) throws -> [Finding] {
        scan(try String(contentsOfFile: path, encoding: .utf8), suffixes: suffixes)
    }

    static func scan(fileAt path: String) throws -> [Finding] {
        scan(try String(contentsOfFile: path, encoding: .utf8))
    }

    private static func unquote(_ s: String) -> String {
        guard s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") else { return s }
        return String(s.dropFirst().dropLast())
    }
}
