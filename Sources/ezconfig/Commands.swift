//
//  Commands.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import ArgumentParser
import Foundation
import PathKit

struct ProjectOptions: ParsableArguments {
    @Option(name: .long, help: "Path ke folder project. Default: folder sekarang.")
    var path: String = FileManager.default.currentDirectoryPath
}

extension Ezconfig {
    
    struct InitCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Extract signing identity from .pbxproj and create Base.xcconfig."
        )
        
        @Option(name: .long, help: "Paksa prefix bundle ID kanonik.")
        var prefix: String?
        
        @Flag(name: .long, help: "Cuma tampilkan rencana, jangan nulis apa-apa.")
        var dryRun = false
        
        func run() throws {
            let cwd = Path.current
            guard let projectPath = cwd.glob("*.xcodeproj").first else {
                throw ValidationError("Nggak nemu .xcodeproj di \(cwd). Pindah ke root project dulu.")
            }
            
            let writer = try ProjectWriter(projectPath: projectPath)
            let outcome = try writer.runInit(overridePrefix: prefix, dryRun: dryRun)
            
            Report.printInit(outcome, projectName: projectPath.lastComponent, dryRun: dryRun)
        }
    }
    
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Detect Team ID and write Configs/Local.xcconfig."
        )
        
        @OptionGroup var options: ProjectOptions
        
        @Option(name: .long, help: "Paksa pakai Team ID tertentu.")
        var team: String?
        
        func run() throws {
            let projectPath = try ProjectReader.locate(in: options.path)
            let sourceRoot = Path(projectPath).parent()
            
            let identity = try Keychain.resolve(override: team)
            let outcome = try LocalConfig.run(
                sourceRoot: sourceRoot,
                projectPath: projectPath,
                identity: identity
            )
            Report.printSetup(outcome)
        }
    }
    
    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "check",
            abstract: "Check if .pbxproj is clean of signing identity."
        )

        @OptionGroup var options: ProjectOptions

        @Flag(name: .long, help: "Langsung strip dan git add ulang kalau kotor.")
        var fix = false

        @Flag(name: .long, help: "Periksa staging area, bukan file di disk. Dipakai pre-commit hook.")
        var staged = false

        @Flag(name: .long, help: "Tolak juga nilai literal di target yang nggak diadopsi.")
        var strict = false

        func run() throws {
            let ctx = try CheckContext.resolve(path: options.path, staged: staged)
            guard let text = ctx.text else { return }

            let allow = strict ? [] : CheckPolicy.allowlist(projectPath: ctx.projectPath.string)
            let split = CheckPolicy.split(PbxprojScanner.scan(text), allowlist: allow)
            let audit = ConfigAudit.run(
                sourceRoot: ctx.sourceRoot,
                projectPath: ctx.projectPath.string
            )

            // Bersih dari yang wajib dibersihin.
            guard !split.blocking.isEmpty else {
                if !staged {
                    print("✓ \(ctx.projectName) bersih (\(ctx.source.label)) — nggak ada identitas literal.")
                    Report.printTolerated(split.tolerated, toStdout: true)
                    Report.printAudit(audit, toStdout: true)
                } else {
                    Report.printAudit(audit, toStdout: false)
                }
                return
            }

            guard fix else {
                Report.printCheck(split.blocking, projectName: ctx.projectName, source: ctx.source)
                Report.printTolerated(split.tolerated, toStdout: false)
                throw ExitCode.failure
            }

            let writer = try ProjectWriter(projectPath: ctx.projectPath)
            let outcome = try writer.runStrip()

            // Residu diklasifikasi ulang. Yang ditoleransi bukan kegagalan —
            // tanpa ini, repo dengan target di luar prefix nggak bisa commit selamanya.
            let residue = CheckPolicy.split(
                PbxprojScanner.scan(try ctx.pbxprojPath.read()),
                allowlist: allow
            )
            guard residue.blocking.isEmpty else {
                Report.printFixFailed(residue.blocking, projectName: ctx.projectName)
                throw ExitCode.failure
            }

            guard staged else {
                Report.printFixed(outcome, restaged: false)
                Report.printFixTolerated(residue.tolerated)
                return
            }

            if let repoPath = ctx.repoPath {
                Git.add(repoPath, cwd: ctx.sourceRoot)
            }
            Report.printFixed(outcome, restaged: true)
            Report.printFixTolerated(residue.tolerated)
            throw ExitCode.failure
        }
    }
    
    struct Clean: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clean",
            abstract: "Strip .pbxproj again if Xcode writes signing identity back."
        )
        
        @OptionGroup var options: ProjectOptions
        
        func run() throws {
            print("ezconfig clean — belum diimplementasi")
        }
    }
    
    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Baca .xcodeproj dan laporin isinya. Nggak nulis apa-apa."
        )
        
        @OptionGroup var options: ProjectOptions
        
        func run() throws {
            let path = try ProjectReader.locate(in: options.path)
            let info = try ProjectReader.read(path)
            Report.print(info)
            
            do {
                let plan = try AdoptionPlan.make(info: info)
                Report.printPlan(plan)
            } catch {
                print("▸ Rencana adopsi")
                print("  Nggak bisa disusun:")
                print("  \(error)")
                print("")
            }
        }
    }
}
