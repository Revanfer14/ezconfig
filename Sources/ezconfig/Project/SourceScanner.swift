//
//  SourceScanner.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//

import Foundation
import PathKit

enum SourceScanner {

    private static let extensions: Set<String> = ["swift", "m", "mm", "h", "c"]
    private static let skipped: Set<String> = [
        ".git", ".build", "DerivedData", "Pods", "Carthage", ".swiftpm", "node_modules"
    ]

    // Cari file source yang masih nyebut string literal ini.
    static func filesContaining(_ needle: String, under root: Path, limit: Int = 8) -> [String] {
        guard !needle.isEmpty else { return [] }

        var hits: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(atPath: root.string) else { return [] }

        for case let rel as String in walker {
            let first = rel.split(separator: "/").first.map(String.init) ?? rel
            if skipped.contains(first) || rel.hasSuffix(".xcodeproj") {
                walker.skipDescendants()
                continue
            }
            guard extensions.contains((rel as NSString).pathExtension.lowercased())
            else { continue }

            let full = root + Path(rel)
            guard let text = try? String(contentsOfFile: full.string, encoding: .utf8),
                  text.contains(needle) else { continue }

            hits.append(rel)
            if hits.count >= limit { break }
        }
        return hits.sorted()
    }
}
