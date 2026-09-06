//
//  HookInstaller.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

struct HookOutcome {
    enum Action {
        case created      // pre-commit belum ada, dibikin
        case appended     // udah ada hook lain, blok ezconfig ditambahin
        case updated      // blok ezconfig udah ada, isinya diperbarui
        case unchanged    // blok ezconfig udah ada dan identik
        case skipped      // nggak dipasang, lihat `reason`
    }
    
    var action: Action = .skipped
    var path = ""
    var reason: String?
    var customHooksPath: String?
    var projectDir = "."
}

enum HookInstaller {
    
    private static let begin = "# >>> ezconfig >>>"
    private static let end   = "# <<< ezconfig <<<"
    
    // Blok yang disisipin ke pre-commit
    private static func block(projectDir: String) -> String {
        """
        \(begin)
        # Do not edit by hand. This block is rewritten on every `ezconfig setup`.
        # GUI clients (Xcode, GitHub Desktop) run without /opt/homebrew/bin on PATH.
        # Literal values in targets ezconfig does not manage are not blocked here.
        PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        if command -v ezconfig >/dev/null 2>&1; then
            ( cd "\(projectDir)" && ezconfig check --fix --staged ) || exit 1
        else
            echo "ezconfig: BINARY NOT FOUND. This commit passed WITHOUT any check." >&2
            echo "  Signing identity may have been committed unnoticed." >&2
            echo "  Install: brew install Revanfer14/adac9/ezconfig" >&2
        fi
        \(end)
        """
    }
    
    static func install(sourceRoot: Path) -> HookOutcome {
        var outcome = HookOutcome()
        
        guard Git.repoRoot(sourceRoot) != nil else {
            outcome.reason = "not a git repository"
            return outcome
        }
        
        // Folder project relatif repo root: "apps/ios" atau "." kalau di root.
        let prefix = (Git.prefix(sourceRoot) ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        outcome.projectDir = prefix.isEmpty ? "." : prefix
        
        let hooksDir: Path
        if let custom = Git.hooksPath(sourceRoot) {
            hooksDir = custom
            outcome.customHooksPath = custom.string
        } else {
            guard let gitDir = Git.gitDir(sourceRoot) else {
                outcome.reason = "could not find the .git directory"
                return outcome
            }
            hooksDir = gitDir + "hooks"
        }
        
        let hookPath = hooksDir + "pre-commit"
        outcome.path = hookPath.string
        
        let body = block(projectDir: outcome.projectDir)
        
        do {
            try FileManager.default.createDirectory(
                atPath: hooksDir.string, withIntermediateDirectories: true
            )
            
            if !hookPath.exists {
                try write("#!/bin/sh\n\n" + body + "\n", to: hookPath)
                outcome.action = .created
                return outcome
            }
            
            let existing: String = try hookPath.read()
            
            if existing.contains(begin) {
                let replaced = replaceBlock(in: existing, with: body)
                if replaced == existing {
                    outcome.action = .unchanged
                } else {
                    try write(replaced, to: hookPath)
                    outcome.action = .updated
                }
                return outcome
            }
            
            // Hook orang lain. Cuma aman di-append kalau dia shell script.
            guard let shebang = existing.split(separator: "\n").first,
                  shebang.hasPrefix("#!"),
                  shebang.contains("sh")            // sh, bash, zsh, env sh
            else {
                outcome.reason = "the existing pre-commit hook is not a shell script"
                return outcome
            }
            
            var merged = existing
            if !merged.hasSuffix("\n") { merged += "\n" }
            merged += "\n" + body + "\n"
            try write(merged, to: hookPath)
            outcome.action = .appended
            return outcome
            
        } catch {
            outcome.reason = "\(error)"
            return outcome
        }
    }
    
    private static func replaceBlock(in text: String, with body: String) -> String {
        guard let b = text.range(of: begin),
              let e = text.range(of: end, range: b.upperBound..<text.endIndex)
        else { return text }
        return text.replacingCharacters(in: b.lowerBound..<e.upperBound, with: body)
    }
    
    private static func write(_ text: String, to path: Path) throws {
        try text.write(toFile: path.string, atomically: true, encoding: .utf8)
        
        // Hook yang nggak executable diabaikan git
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: path.string
        )
    }
}
