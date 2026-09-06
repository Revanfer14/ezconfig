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
    @Option(name: .long, help: "Path to the project folder. Defaults to the current directory.")
    var path: String = FileManager.default.currentDirectoryPath
}

extension Ezconfig {
    
    struct InitCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Extract signing identity from .pbxproj and create Base.xcconfig."
        )

        @OptionGroup var options: ProjectOptions

        @Option(name: .long, help: "Force a specific canonical bundle ID prefix.")
        var prefix: String?

        @Flag(name: .long, help: "Show the plan without writing anything.")
        var dryRun = false

        @Flag(name: .long, help: "Run even if Xcode is open.")
        var force = false

        @Flag(name: .long, help: "Skip the setup step after init.")
        var noSetup = false

        @Option(name: .long, help: "Team ID to use for the setup step after init.")
        var team: String?

        func run() throws {
            if !dryRun, !force, Xcode.isRunning {
                throw ValidationError("""
                Xcode is running.

                Xcode keeps resolved build setting values in memory and can write
                them back to the project file. `init` reads those values to work
                out the canonical bundle prefix and stores it in Base.xcconfig,
                which is committed and shared with everyone on the team.

                Nothing checks Base.xcconfig afterwards. If it is built from
                values Xcode is about to overwrite, the wrong prefix ships to
                the whole team and no later command will catch it.

                Close Xcode and run this again.
                If the project Xcode has open is a different one, this is safe:
                  ezconfig init --force
                """)
            }

            let projectPath = Path(try ProjectReader.locate(in: options.path))

            let writer = try ProjectWriter(projectPath: projectPath)
            var outcome = try writer.runInit(overridePrefix: prefix, dryRun: dryRun)

            if !dryRun && !noSetup {
                outcome.setup = runSetup(
                    sourceRoot: projectPath.parent(),
                    projectPath: projectPath.string,
                    team: team
                )
            }

            Report.printInit(outcome, projectName: projectPath.lastComponent, dryRun: dryRun)
        }

        // Setup nggak boleh bikin init gagal. Waktu ini kepanggil, .pbxproj udah
        // ditulis, jadi throw di sini ninggalin project setengah jadi.
        private func runSetup(
            sourceRoot: Path,
            projectPath: String,
            team: String?
        ) -> Result<SetupOutcome, Error> {
            do {
                let identity = try Keychain.resolve(override: team)
                return .success(
                    try LocalConfig.run(
                        sourceRoot: sourceRoot,
                        projectPath: projectPath,
                        identity: identity
                    )
                )
            } catch {
                return .failure(error)
            }
        }
    }
    
    struct Setup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "setup",
            abstract: "Detect Team ID and write Configs/Local.xcconfig."
        )
        
        @OptionGroup var options: ProjectOptions
        
        @Option(name: .long, help: "Force a specific Team ID.")
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
        
        @Flag(name: .long, help: "Strip and re-stage the project when it is dirty.")
        var fix = false

        @Flag(name: .long, help: "Check the staging area instead of the file on disk. Used by the pre-commit hook.")
        var staged = false

        @Flag(name: .long, help: "Also reject literal values in targets ezconfig does not manage.")
        var strict = false
        
        func validate() throws {
            guard !(fix && strict) else {
                throw ValidationError("""
                --strict cannot be combined with --fix.

                --strict rejects literal values in targets ezconfig does not
                manage. Those values have no template, so --fix can never repair
                them. Use --strict on its own to audit, then fix them by hand
                in Xcode.
                """)
            }
        }
        
        func run() throws {
            let ctx = try CheckContext.resolve(path: options.path, staged: staged)
            guard let text = ctx.text else { return }
            
            let suffixes = LocalConfig.knownSuffixes(sourceRoot: ctx.sourceRoot)
            
            // `--strict` cuma nolak nilai literal di target yang nggak diadopsi.
            // Himpunan `unfixable` tetap jalan, kalau nggak `--fix --strict`
            // balik buntu dan printFixFailed bakal nuduh ezconfig bug.
            var allow = CheckPolicy.allowlist(projectPath: ctx.projectPath.string)
            if strict { allow.outsidePrefix = [] }
            
            let split = CheckPolicy.split(
                PbxprojScanner.scan(text, suffixes: suffixes),
                allowlist: allow
            )
            let audit = ConfigAudit.run(
                sourceRoot: ctx.sourceRoot,
                projectPath: ctx.projectPath.string
            )
            
            guard !split.blocking.isEmpty else {
                if !staged {
                    print("✓ \(ctx.projectName) is clean (\(ctx.source.label)), no signing identity in it.")
                    Report.printTolerated(split.tolerated, toStdout: true)
                    Report.printUnfixable(split.unfixable, toStdout: true)
                    Report.printAudit(audit, toStdout: true)
                } else {
                    // Mode hook: ini satu-satunya momen developer liat output ezconfig.
                    Report.printUnfixable(split.unfixable, toStdout: false)
                    Report.printAudit(audit, toStdout: false)
                }
                return
            }
            
            guard fix else {
                Report.printCheck(split.blocking, projectName: ctx.projectName, source: ctx.source)
                Report.printTolerated(split.tolerated, toStdout: false)
                Report.printUnfixable(split.unfixable, toStdout: false)
                throw ExitCode.failure
            }
            
            let writer = try ProjectWriter(projectPath: ctx.projectPath)
            let outcome = try writer.runStrip()
            
            let residue = CheckPolicy.split(
                PbxprojScanner.scan(try ctx.pbxprojPath.read(), suffixes: suffixes),
                allowlist: allow
            )
            guard residue.blocking.isEmpty else {
                Report.printFixFailed(residue.blocking, projectName: ctx.projectName)
                throw ExitCode.failure
            }
            
            guard staged else {
                Report.printFixed(outcome, restaged: false)
                Report.printFixTolerated(residue.tolerated)
                Report.printUnfixable(residue.unfixable, toStdout: false)
                return
            }
            
            if let repoPath = ctx.repoPath {
                Git.add(repoPath, cwd: ctx.sourceRoot)
            }
            Report.printFixed(outcome, restaged: true)
            Report.printFixTolerated(residue.tolerated)
            Report.printUnfixable(residue.unfixable, toStdout: false)
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
            let projectPath = Path(try ProjectReader.locate(in: options.path))
            let writer = try ProjectWriter(projectPath: projectPath)
            let outcome = try writer.runStrip()
            Report.printClean(outcome, projectName: projectPath.lastComponent)
        }
    }
    
    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Read the .xcodeproj and report what is in it. Writes nothing."
        )
        
        @OptionGroup var options: ProjectOptions
        
        func run() throws {
            let path = try ProjectReader.locate(in: options.path)
            let info = try ProjectReader.read(path)
            Report.print(info)
            
            do {
                let plan = try AdoptionPlan.make(
                    info: info,
                    knownSuffixes: LocalConfig.knownSuffixes(
                        sourceRoot: Path(path).parent()
                    )
                )
                Report.printPlan(plan)
            } catch {
                print("▸ Adoption plan")
                print("  Could not be built:")
                print("  \(error)")
                print("")
            }
        }
    }
}
