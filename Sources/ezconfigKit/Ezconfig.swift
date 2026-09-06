//
//  Ezconfig.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//

import ArgumentParser
import Foundation

public struct Ezconfig: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ezconfig",
        abstract: "Automate multi-developer (with Individual Apple Membership Program) code signing for Xcode projects",
        version: EzconfigVersion.current,
        subcommands: [InitCommand.self, Setup.self, Check.self, Clean.self, Inspect.self]
    )

    public init() {}
}
