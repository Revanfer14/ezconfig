//
//  Git+Staging.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

extension Git {

    private static func g(_ args: [String], cwd: Path) -> Shell.Result {
        Shell.run("/usr/bin/git", args, cwd: cwd.string)
    }

    // Lokasi folder .git — buat masang hook. Bisa absolut atau relatif ke cwd.
    static func gitDir(_ cwd: Path) -> Path? {
        let r = g(["rev-parse", "--git-dir"], cwd: cwd)
        guard r.ok else { return nil }
        let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let p = Path(s)
        return p.isAbsolute ? p : cwd + p
    }

    static func prefix(_ cwd: Path) -> String? {
        let r = g(["rev-parse", "--show-prefix"], cwd: cwd)
        guard r.ok else { return nil }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isStaged(_ repoPath: String, cwd: Path) -> Bool {
        let r = g(["diff", "--cached", "--name-only", "--", repoPath], cwd: cwd)
        guard r.ok else { return false }
        return !r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Isi file versi staging area (blob di index), bukan yang di disk.
    static func stagedContent(_ repoPath: String, cwd: Path) -> String? {
        let r = g(["show", ":\(repoPath)"], cwd: cwd)
        return r.ok ? r.stdout : nil
    }

    @discardableResult
    static func add(_ repoPath: String, cwd: Path) -> Bool {
        g(["add", "--", repoPath], cwd: cwd).ok
    }
}
