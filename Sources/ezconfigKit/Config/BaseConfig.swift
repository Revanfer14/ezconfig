//
//  BaseConfig.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation
import PathKit

enum BaseConfig {

    static let appGroupPrefix = "APP_GROUP_ID"

    // Parse baris `KEY = VALUE` dari xcconfig. Komentar & #include dilewatin.
    static func values(from path: Path) -> [String: String] {
        guard path.exists, let text: String = try? path.read() else { return [:] }

        var out: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") || line.hasPrefix("#") { continue }
            if let comment = line.range(of: "//") {
                line = String(line[line.startIndex..<comment.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
            guard let eq = line.firstIndex(of: "=") else { continue }

            var key = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            if let bracket = key.firstIndex(of: "[") {
                key = String(key[key.startIndex..<bracket])
                    .trimmingCharacters(in: .whitespaces)
            }
            let value = String(line[line.index(after: eq)...])
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }
            out[key] = value
        }
        return out
    }

    // APP_GROUP_ID, APP_GROUP_ID_2, ... → nilai kanonik (tanpa $(LOCAL_SUFFIX)).
    // Urut biar init berkali-kali ngasilin Base.xcconfig yang identik.
    static func appGroups(from path: Path) -> [AppGroupBinding] {
        values(from: path)
            .filter { $0.key == appGroupPrefix || $0.key.hasPrefix(appGroupPrefix + "_") }
            .map {
                AppGroupBinding(
                    variable: $0.key,
                    canonical: $0.value
                        .replacingOccurrences(of: "$(LOCAL_SUFFIX)", with: "")
                        .trimmingCharacters(in: .whitespaces)
                )
            }
            .filter { !$0.canonical.isEmpty }
            .sorted { $0.variable < $1.variable }
    }

    static func variableName(index: Int) -> String {
        index == 0 ? appGroupPrefix : "\(appGroupPrefix)_\(index + 1)"
    }
}
