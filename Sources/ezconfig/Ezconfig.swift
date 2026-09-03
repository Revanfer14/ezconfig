//
//  Ezconfig.swift
//  ezconfigTests
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation
import ArgumentParser

@main
struct Ezconfig: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ezconfig",
        abstract: "Automate multi-developer (with Individual Apple Membership Program) code signing for Xcode projects",
        version: "0.1.0",
        subcommands: [Init.self, Setup.self, Check.self, Clean.self],
    )
        
}
