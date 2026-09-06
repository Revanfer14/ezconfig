//
//  Report+Suffix.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//

import Foundation

extension Report {

    // Blok ringkas: apa yang dibuang, dari mana. Konsekuensinya (App ID
    // ke-claim di portal) naik jadi item attention, bukan paragraf di sini.
    static func suffixCleaningLines(_ cleanings: [SuffixCleaning]) -> [String] {
        guard !cleanings.isEmpty else { return [] }

        var lines = ["Removed your local identity from \(cleanings.count) value\(cleanings.count == 1 ? "" : "s")"]

        var order: [String] = []
        var byTarget: [String: [SuffixCleaning]] = [:]
        for c in cleanings {
            if byTarget[c.target] == nil { order.append(c.target) }
            byTarget[c.target, default: []].append(c)
        }

        for target in order {
            for c in byTarget[target] ?? [] {
                let where_ = target == "—" ? c.site : "\(target) / \(c.site)"
                lines.append("  \(where_)")
                lines.append("    \(c.from)")
                lines.append("    \(c.to)   (dropped \(c.suffix))")
            }
        }
        return lines
    }

    // Peringatan portal cuma relevan kalau emang ada yang dibersihin.
    static func suffixCleaningAttention(_ cleanings: [SuffixCleaning]) -> [[String]] {
        guard !cleanings.isEmpty else { return [] }
        return [[
            "Your Team ID may already be on App Store Connect",
            "",
            "Xcode had written your identity into values that get committed.",
            "They are cleaned now, but if any of them reached Release or",
            "TestFlight earlier, the App ID is registered under your account",
            "and cannot be released.",
            "",
            "Check developer.apple.com > Identifiers before shipping again.",
        ]]
    }

    static func suspiciousAttention(_ suspicious: [SuspiciousSuffix]) -> [[String]] {
        guard !suspicious.isEmpty else { return [] }

        var lines = ["Some bundle IDs contain something that looks like a Team ID", ""]

        for s in suspicious {
            lines.append("  \(s.target) / \(s.site)")
            lines.append("    \(s.value)")
            if s.resolved != s.value {
                lines.append("    becomes \(s.resolved)")
            }
            lines.append("    '\(s.component)' has the shape of a local suffix")
        }

        lines.append("")
        lines.append("It is not attached to the prefix, so ezconfig cannot tell whether")
        lines.append("it is your identity or part of a target name. Nothing was changed,")
        lines.append("and `check` will not block commits over it.")
        lines.append("")
        lines.append("If it is your identity, fix the bundle ID in Xcode, or set the")
        lines.append("prefix by hand:")
        lines.append("  ezconfig init --prefix <id>")

        return [lines]
    }

    // Dipakai `inspect`, yang emang alat diagnostik dan boleh verbose.
    static func printSuffixCleanings(
        _ cleanings: [SuffixCleaning],
        suspicious: [SuspiciousSuffix]
    ) {
        for line in suffixCleaningLines(cleanings) { Swift.print(line) }
        if !cleanings.isEmpty { Swift.print("") }

        for item in suspiciousAttention(suspicious) {
            for line in item { Swift.print("  " + line) }
            Swift.print("")
        }
    }
}
