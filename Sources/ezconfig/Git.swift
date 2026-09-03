//
//  Git.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

enum Git {

    private static func git(_ args: [String], cwd: Path) -> Shell.Result {
        Shell.run("/usr/bin/git", args, cwd: cwd.string)
    }

    static func repoRoot(_ cwd: Path) -> String? {
        let r = git(["rev-parse", "--show-toplevel"], cwd: cwd)
        guard r.ok else { return nil }
        let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    static func isIgnored(_ relPath: String, cwd: Path) -> Bool {
        git(["check-ignore", "-q", relPath], cwd: cwd).status == 0
    }

    static func ignoreRule(_ relPath: String, cwd: Path) -> String? {
        let r = git(["check-ignore", "-v", "--no-index", relPath], cwd: cwd)
        guard r.status == 0 else { return nil }
        return r.stdout
            .split(separator: "\n").first
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    static func isTracked(_ relPath: String, cwd: Path) -> Bool {
        git(["ls-files", "--error-unmatch", relPath], cwd: cwd).status == 0
    }
}

struct GitOutcome {
    var isRepo = false
    var gitignorePath = ""
    var addedRules: [String] = []
    var localIgnored = false
    var localTracked = false
    var baseIgnored = false
    var baseIgnoreRule: String?
}

enum Gitignore {

    private static let localRel = "Configs/Local.xcconfig"
    private static let baseRel  = "Configs/Base.xcconfig"
    private static let marker   = "# ezconfig — identitas signing per developer"

    // `.gitignore` ditulis di samping folder Configs, bukan di root repo.
    static func ensure(sourceRoot: Path) -> GitOutcome {
        var outcome = GitOutcome()

        guard Git.repoRoot(sourceRoot) != nil else { return outcome }
        outcome.isRepo = true

        let path = sourceRoot + ".gitignore"
        outcome.gitignorePath = ".gitignore"

        outcome.localTracked = Git.isTracked(localRel, cwd: sourceRoot)

        // 1. Local.xcconfig harus ke-ignore.
        if !Git.isIgnored(localRel, cwd: sourceRoot) {
            append([localRel], to: path, outcome: &outcome)
        }
        outcome.localIgnored = Git.isIgnored(localRel, cwd: sourceRoot)
        
        // 2. Base.xcconfig nggak boleh ke-ignore.
        if Git.isIgnored(baseRel, cwd: sourceRoot) {
            append(["!\(baseRel)"], to: path, outcome: &outcome)

            if Git.isIgnored(baseRel, cwd: sourceRoot) {
                outcome.baseIgnored = true
                outcome.baseIgnoreRule = Git.ignoreRule(baseRel, cwd: sourceRoot)
            }
        }

        return outcome
    }

    private static func append(
        _ rules: [String],
        to path: Path,
        outcome: inout GitOutcome
    ) {
        var text = (try? path.read()) ?? ""

        // Jangan duplikat kalau barisnya udah ada.
        let existing = Set(
            text.split(separator: "\n").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        )
        let fresh = rules.filter { !existing.contains($0) }
        guard !fresh.isEmpty else { return }

        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        if !text.contains(marker) {
            if !text.isEmpty { text += "\n" }
            text += marker + "\n"
        }
        text += fresh.joined(separator: "\n") + "\n"

        try? text.write(toFile: path.string, atomically: true, encoding: .utf8)
        outcome.addedRules.append(contentsOf: fresh)
    }
}
