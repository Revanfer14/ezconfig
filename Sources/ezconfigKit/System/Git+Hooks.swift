//
//  Git+Hooks.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

extension Git {
    static func hooksPath(_ cwd: Path) -> Path? {
        let r = Shell.run("/usr/bin/git", ["config", "--get", "core.hooksPath"], cwd: cwd.string)
        guard r.ok else { return nil }
        let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        let p = Path(s)
        if p.isAbsolute { return p }
        guard let root = repoRoot(cwd) else { return nil }
        return Path(root) + p
    }
}
