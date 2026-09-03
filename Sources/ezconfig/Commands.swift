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
        
        func run() throws {
            let ctx = try CheckContext.resolve(path: options.path, staged: staged)

            guard let text = ctx.text else { return }

            let findings = PbxprojScanner.scan(text)

            guard !findings.isEmpty else {
                if !staged {
                    print("✓ \(ctx.projectName) bersih (\(ctx.source.label)) — nggak ada identitas literal.")
                }
                return
            }

            guard fix else {
                Report.printCheck(findings, projectName: ctx.projectName, source: ctx.source)
                throw ExitCode.failure
            }

            let writer = try ProjectWriter(projectPath: ctx.projectPath)
            let outcome = try writer.runStrip()
            
            let residue = PbxprojScanner.scan(try ctx.pbxprojPath.read())
            guard residue.isEmpty else {
                Report.printFixFailed(residue, projectName: ctx.projectName)
                throw ExitCode.failure
            }

            guard staged else {
                Report.printFixed(outcome, restaged: false)
                return
            }

            if let repoPath = ctx.repoPath {
                Git.add(repoPath, cwd: ctx.sourceRoot)
            }
            Report.printFixed(outcome, restaged: true)
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
        }
    }
}
