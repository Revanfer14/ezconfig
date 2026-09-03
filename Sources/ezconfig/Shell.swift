//
//  Shell.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation

enum Shell {

    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    // Jalanin proses eksternal. Dipakai buat `security`, `openssl`, `git`.

    @discardableResult
    static func run(
        _ launchPath: String,
        _ args: [String],
        stdin: String? = nil,
        cwd: String? = nil
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        var inPipe: Pipe?
        if stdin != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            inPipe = pipe
        }

        do {
            try process.run()
        } catch {
            return Result(status: 127, stdout: "", stderr: "\(error)")
        }

        if let stdin, let inPipe {
            inPipe.fileHandleForWriting.write(Data(stdin.utf8))
            inPipe.fileHandleForWriting.closeFile()
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Result(
            status: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}
