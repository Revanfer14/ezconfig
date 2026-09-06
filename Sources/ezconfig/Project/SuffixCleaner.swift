//
//  SuffixCleaner.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//


import Foundation

enum SuffixCleaner {

    struct Result {
        let value: String
        let removed: String?
        var didClean: Bool { removed != nil }
    }

    static func clean(
        _ value: String,
        anchors: [String],
        suffixes: Set<String>
    ) -> Result {
        guard !suffixes.isEmpty else { return Result(value: value, removed: nil) }

        // Panjang duluan, biar suffix pendek nggak motong separuh yang panjang.
        let ordered = suffixes.filter { !$0.isEmpty }.sorted { $0.count > $1.count }

        for anchor in anchors {
            for suffix in ordered {
                let head = anchor + suffix
                guard value.hasPrefix(head) else { continue }
                return Result(
                    value: anchor + String(value.dropFirst(head.count)),
                    removed: suffix
                )
            }
        }
        return Result(value: value, removed: nil)
    }

    static func cleanTrailing(_ value: String, suffixes: Set<String>) -> Result {
        let ordered = suffixes.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        for suffix in ordered where value.hasSuffix(suffix) && value.count > suffix.count {
            return Result(value: String(value.dropLast(suffix.count)), removed: suffix)
        }
        return Result(value: value, removed: nil)
    }

    static func cleanAppGroup(
        _ value: String,
        knownCanonicals: [String],
        suffixes: Set<String>
    ) -> Result {
        for canonical in knownCanonicals {
            for suffix in suffixes where !suffix.isEmpty && value == canonical + suffix {
                return Result(value: canonical, removed: suffix)
            }
        }
        return cleanTrailing(value, suffixes: suffixes)
    }

    static func looksLikeSuffix(_ component: String) -> Bool {
        if isTeamIDShaped(component) { return true }
        if component.hasPrefix("t"), isTeamIDShaped(String(component.dropFirst())) {
            return true
        }
        return false
    }

    private static func isTeamIDShaped(_ s: String) -> Bool {
        s.count == 10
            && s.allSatisfy { ($0.isLetter && $0.isLowercase) || $0.isNumber }
            && s.contains(where: \.isNumber)
    }

    static func suspiciousComponent(in remainder: String) -> String? {
        remainder
            .split(separator: ".")
            .map(String.init)
            .first(where: looksLikeSuffix)
    }
}
