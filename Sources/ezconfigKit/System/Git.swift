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
    
    static func trackedButIgnored(_ cwd: Path) -> [String] {
        let r = git(["ls-files", "-i", "-c", "--exclude-standard"], cwd: cwd)
        guard r.ok else { return [] }
        return r.stdout
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

struct GitOutcome {
    var isRepo = false
    var gitignorePath = ""
    var addedRules: [String] = []
    var addedXcodeRules: [String] = []
    var trackedButIgnored: [String] = []
    var localIgnored = false
    var localTracked = false
    var baseIgnored = false
    var baseIgnoreRule: String?
}

enum Gitignore {
    
    private static let localRel = "Configs/Local.xcconfig"
    private static let baseRel  = "Configs/Base.xcconfig"
    
    private static let signingMarker = "# ezconfig: signing identity"
    private static let xcodeMarker   = "# ezconfig: Xcode defaults"
    
    // Sengaja nggak ada pola yang cocok sama *.xcconfig. Kalau ada,
    // Base.xcconfig ikut ke-ignore dan seluruh premis tool-nya rusak.
    private static let xcodeDefaults: [(rule: String, probe: String)] = [
        (".DS_Store",        ".DS_Store"),
        ("build/",           "build/x"),
        ("DerivedData/",     "DerivedData/x"),
        ("xcuserdata/",      "a.xcodeproj/xcuserdata/x"),
        ("*.moved-aside",    "x.moved-aside"),
        ("*.hmap",           "x.hmap"),
        ("*.ipa",            "x.ipa"),
        ("*.dSYM",           "x.dSYM"),
        ("*.dSYM.zip",       "x.dSYM.zip"),
        ("*.xccheckout",     "x.xccheckout"),
        ("*.xcscmblueprint", "x.xcscmblueprint"),
        (".build/",          ".build/x"),
        (".swiftpm/",        ".swiftpm/x"),
        ("Pods/",            "Pods/x"),
    ]
    
    // `.gitignore` ditulis di samping folder Configs, bukan di root repo.
    // Xcode defaults cuma dari `init`. Kalau `setup` ikut nulis, tiap anggota
    // tim yang clone bikin diff yang nggak ada gunanya.
    static func ensure(sourceRoot: Path, includeXcodeDefaults: Bool = false) -> GitOutcome {
        var outcome = GitOutcome()
        
        guard Git.repoRoot(sourceRoot) != nil else { return outcome }
        outcome.isRepo = true
        
        let path = sourceRoot + ".gitignore"
        outcome.gitignorePath = ".gitignore"
        
        outcome.localTracked = Git.isTracked(localRel, cwd: sourceRoot)
        
        // 1. Xcode defaults duluan, biar cek ignore di bawah baca file final.
        if includeXcodeDefaults {
            let missing = xcodeDefaults
                .filter { !Git.isIgnored($0.probe, cwd: sourceRoot) }
                .map(\.rule)
            outcome.addedXcodeRules = append(missing, marker: xcodeMarker, to: path)
        }
        
        // 2. Local.xcconfig harus ke-ignore.
        if !Git.isIgnored(localRel, cwd: sourceRoot) {
            outcome.addedRules += append([localRel], marker: signingMarker, to: path)
        }
        outcome.localIgnored = Git.isIgnored(localRel, cwd: sourceRoot)
        
        // 3. Base.xcconfig nggak boleh ke-ignore.
        if Git.isIgnored(baseRel, cwd: sourceRoot) {
            outcome.addedRules += append(["!\(baseRel)"], marker: signingMarker, to: path)
            
            if Git.isIgnored(baseRel, cwd: sourceRoot) {
                outcome.baseIgnored = true
                outcome.baseIgnoreRule = Git.ignoreRule(baseRel, cwd: sourceRoot)
            }
        }
        
        // 4. Rule baru nggak berlaku buat file yang udah ke-track.
        //    Local.xcconfig dikecualiin, dia punya jalur laporan sendiri.
        outcome.trackedButIgnored = Git.trackedButIgnored(sourceRoot)
            .filter { $0 != localRel }
        
        return outcome
    }
    
    @discardableResult
    private static func append(
        _ rules: [String],
        marker: String,
        to path: Path
    ) -> [String] {
        var text = (try? path.read()) ?? ""
        
        let existing = Set(
            text.split(separator: "\n").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        )
        let fresh = rules.filter { !existing.contains($0) }
        guard !fresh.isEmpty else { return [] }
        
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        if !text.contains(marker) {
            if !text.isEmpty { text += "\n" }
            text += marker + "\n"
        }
        text += fresh.joined(separator: "\n") + "\n"
        
        try? text.write(toFile: path.string, atomically: true, encoding: .utf8)
        return fresh
    }
}
