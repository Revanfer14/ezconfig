//
//  Report+Check.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation

private struct StdErr: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

extension Report {
    
    static func printTolerated(_ findings: [Finding], toStdout: Bool) {
        guard !findings.isEmpty else { return }
        var err = StdErr()
        let emit: (String) -> Void = { line in
            if toStdout { Swift.print(line) } else { Swift.print(line, to: &err) }
        }

        emit("")
        emit("  \(findings.count) nilai literal dibiarin (target di luar prefix):")
        for f in findings {
            emit("    line \(f.line)  \(f.key.label)  \(f.value)")
        }
        emit("  Ini bukan kebocoran — target itu emang nggak diadopsi ezconfig.")
        emit("  Kalau mau ikut diadopsi: samain bundle ID-nya di Xcode, lalu ezconfig init.")
    }

    static func printAudit(_ audit: ConfigAudit, toStdout: Bool) {
        guard !audit.isClean, audit.baseExists else { return }
        var err = StdErr()
        let emit: (String) -> Void = { line in
            if toStdout { Swift.print(line) } else { Swift.print(line, to: &err) }
        }

        emit("")
        emit("  ⚠︎  Variabel dipakai di entitlements tapi nggak ada di Base.xcconfig:")
        for u in audit.undefined {
            emit("     \(u.file)  →  $(\(u.variable))")
        }
        emit("     Nilainya bakal kosong waktu build. Jalanin: ezconfig init")
    }

    static func printFixTolerated(_ findings: [Finding]) {
        guard !findings.isEmpty else { return }
        var err = StdErr()
        Swift.print("", to: &err)
        Swift.print("  \(findings.count) nilai dibiarin apa adanya (target di luar prefix) — commit lanjut.", to: &err)
    }
    
    static func printFixed(_ o: StripOutcome, restaged: Bool) {
        var err = StdErr()

        if o.isEmpty {
            Swift.print("ezconfig: .pbxproj di disk udah bersih — staging area di-sinkronin ulang.", to: &err)
        } else {
            var parts: [String] = []
            if o.teamsRemoved > 0 { parts.append("\(o.teamsRemoved) DEVELOPMENT_TEAM") }
            if o.attributeTeamsRemoved > 0 { parts.append("\(o.attributeTeamsRemoved) TargetAttributes") }
            if o.provisioningRemoved > 0 { parts.append("\(o.provisioningRemoved) PROVISIONING_PROFILE*") }
            if o.bundleIDsRewritten > 0 { parts.append("\(o.bundleIDsRewritten) bundle ID → $(BUNDLE_PREFIX)") }
            if o.companionsRewritten > 0 { parts.append("\(o.companionsRewritten) companion → $(BUNDLE_PREFIX)") }
            Swift.print("ezconfig: signing identity dibersihin — \(parts.joined(separator: ", ")).", to: &err)
        }

        if restaged {
            Swift.print("", to: &err)
            Swift.print("  File udah di-stage ulang. Commit sekali lagi buat lanjut.", to: &err)
            Swift.print("", to: &err)
        }
    }

    static func printFixFailed(_ residue: [Finding], projectName: String) {
        var err = StdErr()
        Swift.print("ezconfig: fix gagal — \(residue.count) nilai masih ketinggalan di \(projectName).", to: &err)
        Swift.print("", to: &err)
        for f in residue {
            Swift.print("  line \(f.line)  \(f.key.label)  \(f.value)", to: &err)
        }
        Swift.print("", to: &err)
        Swift.print("  Ini bug ezconfig. Perbaiki manual dulu di Xcode.", to: &err)
        Swift.print("", to: &err)
    }

    static func printCheck(_ findings: [Finding], projectName: String, source: CheckContext.Source) {
        var err = StdErr()

        let leaks = findings.filter(\.isSuffixLeak)
        let literals = findings.filter { !$0.isSuffixLeak }
        let noun = findings.count == 1 ? "value" : "values"

        // Baris pertama HARUS berdiri sendiri, GitHub Desktop motong sisanya.
        Swift.print(
            "ezconfig: \(findings.count) signing \(noun) in \(projectName) [\(source.label)], commit blocked.",
            to: &err
        )
        Swift.print("", to: &err)

        let width = findings.map(\.key.label.count).max() ?? 0

        if !literals.isEmpty {
            Swift.print("  Nilai literal:", to: &err)
            for f in literals {
                Swift.print("    line \(padLeft(String(f.line), 5))  \(padRight(f.key.label, width))  \(f.value)", to: &err)
            }
            Swift.print("", to: &err)
        }

        if !leaks.isEmpty {
            Swift.print("  Suffix lokal ikut kebawa di nilai variabel:", to: &err)
            for f in leaks {
                Swift.print("    line \(padLeft(String(f.line), 5))  \(padRight(f.key.label, width))  \(f.value)", to: &err)
                if let s = f.suffix {
                    Swift.print("    \(padRight("", 5 + 8))\(padRight("", width))  ↑ '\(s)' itu suffix lokal", to: &err)
                }
            }
            Swift.print("", to: &err)
            Swift.print("  Nilainya keliatan bener karena diawali $(, tapi Xcode nyuntik", to: &err)
            Swift.print("  suffix mesin lo ke dalamnya. Kalau ini ke-commit, developer lain", to: &err)
            Swift.print("  dapet bundle ID yang nggak nyambung, dan Release bawa identitas lo.", to: &err)
            Swift.print("", to: &err)
        }

        Swift.print("  Fix: ezconfig check --fix", to: &err)
        Swift.print("", to: &err)
    }
    
    static func printUnfixable(_ findings: [Finding], toStdout: Bool) {
        guard !findings.isEmpty else { return }
        var err = StdErr()
        let emit: (String) -> Void = { line in
            if toStdout { Swift.print(line) } else { Swift.print(line, to: &err) }
        }

        emit("")
        emit("  ⚠︎  \(findings.count) nilai ngandung komponen yang bentuknya kayak suffix lokal:")
        for f in findings {
            emit("     line \(f.line)  \(f.key.label)  \(f.value)")
        }
        emit("")
        emit("     Komponennya nggak nempel di belakang prefix, jadi ezconfig nggak")
        emit("     bisa mastiin itu suntikan Xcode atau emang bagian nama target.")
        emit("     Sesuai prinsipnya, ezconfig nggak nebak: commit ini DILANJUT.")
        emit("")
        emit("     Kalau itu beneran identitas lo, dia ikut ke Release juga, dan")
        emit("     App ID-nya bisa ke-claim di App Store Connect atas nama lo.")
        emit("     Benerin bundle ID-nya di Xcode, atau tentuin prefix manual:")
        emit("       ezconfig init --prefix <id>")
    }

    private static func padRight(_ s: String, _ w: Int) -> String {
        s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
    }

    private static func padLeft(_ s: String, _ w: Int) -> String {
        s.count >= w ? s : String(repeating: " ", count: w - s.count) + s
    }
}
