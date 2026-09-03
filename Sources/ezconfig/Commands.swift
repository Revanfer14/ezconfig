//
//  Commands.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import ArgumentParser
import Foundation

struct ProjectOptions: ParsableArguments {
    @Option(name: .long, help: "Path ke folder project. Default: folder sekarang.")
    var path: String = FileManager.default.currentDirectoryPath
}

extension Ezconfig {
    
    struct Init: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Extract signing identity from .pbxproj and create Base.xcconfig."
        )
        
        @OptionGroup var options: ProjectOptions
        
        func run() throws {
            print("ezconfig init — belum diimplementasi")
            print("  path: \(options.path)")
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
            print("ezconfig setup — belum diimplementasi")
            print("  path: \(options.path)")
            print("  team: \(team ?? "auto-detect")")
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
        
        func run() throws {
            print("ezconfig check — belum diimplementasi")
            print("  fix: \(fix)")
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
