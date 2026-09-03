//
//  CheckContext.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import PathKit

// Nentuin teks .pbxproj mana yang diperiksa: yang di disk, atau yang di staging area.
struct CheckContext {

    enum Source {
        case worktree
        case staged
        case notStaged     

        var label: String {
            switch self {
            case .worktree:   return "worktree"
            case .staged:     return "staging area"
            case .notStaged:  return "—"
            }
        }
    }

    let projectPath: Path        // .../SignTest.xcodeproj
    let sourceRoot: Path         // induknya
    let pbxprojPath: Path        // .../SignTest.xcodeproj/project.pbxproj
    let repoPath: String?        // path relatif repo root, nil kalau bukan repo
    let source: Source
    let text: String?            // nil kalau .notStaged

    var projectName: String { projectPath.lastComponent }

    static func resolve(path: String, staged: Bool) throws -> CheckContext {
        let projectPath = Path(try ProjectReader.locate(in: path))
        let sourceRoot = projectPath.parent()
        let pbxprojPath = projectPath + "project.pbxproj"

        // Path yang git ngerti: prefix cwd + nama project + file.
        let repoPath = Git.prefix(sourceRoot).map {
            $0 + projectPath.lastComponent + "/project.pbxproj"
        }

        // Mode manual, atau bukan git repo sama sekali → baca disk.
        guard staged, let repoPath else {
            return CheckContext(
                projectPath: projectPath,
                sourceRoot: sourceRoot,
                pbxprojPath: pbxprojPath,
                repoPath: repoPath,
                source: .worktree,
                text: try pbxprojPath.read()
            )
        }

        guard Git.isStaged(repoPath, cwd: sourceRoot),
              let blob = Git.stagedContent(repoPath, cwd: sourceRoot)
        else {
            return CheckContext(
                projectPath: projectPath,
                sourceRoot: sourceRoot,
                pbxprojPath: pbxprojPath,
                repoPath: repoPath,
                source: .notStaged,
                text: nil
            )
        }

        return CheckContext(
            projectPath: projectPath,
            sourceRoot: sourceRoot,
            pbxprojPath: pbxprojPath,
            repoPath: repoPath,
            source: .staged,
            text: blob
        )
    }
}
