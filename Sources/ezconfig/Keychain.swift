//
//  Keychain.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 03/09/26.
//

import Foundation

struct SigningIdentity {
    let teamID: String        // OU
    let commonName: String    // CN
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    // "Apple Development: revan@icloud.com (XXXXXXXXXX)" → "revan@icloud.com"
    var displayName: String {
        guard let colon = commonName.firstIndex(of: ":") else { return commonName }
        var s = commonName[commonName.index(after: colon)...]
            .trimmingCharacters(in: .whitespaces)
        if let paren = s.firstIndex(of: "(") {
            s = String(s[s.startIndex..<paren]).trimmingCharacters(in: .whitespaces)
        }
        return s
    }
}

enum KeychainError: Error, CustomStringConvertible {
    case noCertificate
    case allExpired([SigningIdentity])
    case ambiguous([SigningIdentity])

    var description: String {
        switch self {
        case .noCertificate:
            return """
            Nggak nemu sertifikat 'Apple Development' di keychain.
            Buka Xcode → Settings → Accounts, sign in pakai Apple ID lo,
            lalu 'Manage Certificates' → '+' → 'Apple Development'.
            """
        case let .allExpired(list):
            let lines = list.map { "  \($0.teamID)  \($0.displayName)  (expired)" }
            return """
            Semua sertifikat Apple Development udah expired:
            \(lines.joined(separator: "\n"))
            Bikin yang baru lewat Xcode → Settings → Accounts → Manage Certificates.
            """
        case let .ambiguous(list):
            let lines = list.map { "  \($0.teamID)  \($0.displayName)" }
            return """
            Ada \(list.count) Team ID di keychain lo:
            \(lines.joined(separator: "\n"))
            Tentuin yang mana: ezconfig setup --team <ID>
            """
        }
    }
}

enum Keychain {

    private static let certificateNames = ["Apple Development", "iPhone Developer"]

    static func identities() throws -> [SigningIdentity] {
        var pemBlocks: [String] = []

        for name in certificateNames {
            let result = Shell.run(
                "/usr/bin/security",
                ["find-certificate", "-a", "-c", name, "-p"]
            )
            guard result.ok else { continue }
            pemBlocks.append(contentsOf: splitPEM(result.stdout))
        }

        guard !pemBlocks.isEmpty else { throw KeychainError.noCertificate }

        var byTeam: [String: SigningIdentity] = [:]
        for block in pemBlocks {
            guard let identity = parse(block) else { continue }
            if let existing = byTeam[identity.teamID] {
                let a = existing.expiresAt ?? .distantPast
                let b = identity.expiresAt ?? .distantPast
                if b <= a { continue }
            }
            byTeam[identity.teamID] = identity
        }

        guard !byTeam.isEmpty else { throw KeychainError.noCertificate }
        return byTeam.values.sorted { $0.teamID < $1.teamID }
    }

    static func resolve(override: String?) throws -> SigningIdentity {
        if let override {
            let all = (try? identities()) ?? []
            if let match = all.first(where: { $0.teamID == override }) {
                return match
            }
            // Team ID yang nggak ada sertifikatnya tetap diizinin —
            // mungkin sertifikatnya di mesin lain. Build-nya yang bakal protes.
            return SigningIdentity(
                teamID: override,
                commonName: "(dari --team, nggak ada di keychain)",
                expiresAt: nil
            )
        }

        let all = try identities()
        let valid = all.filter { !$0.isExpired }

        guard !valid.isEmpty else { throw KeychainError.allExpired(all) }
        guard valid.count == 1 else { throw KeychainError.ambiguous(valid) }
        return valid[0]
    }

    // Parsing

    private static func splitPEM(_ text: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        var inside = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("-----BEGIN CERTIFICATE-----") {
                inside = true
                current = [line]
                continue
            }
            guard inside else { continue }
            current.append(line)
            if line.hasPrefix("-----END CERTIFICATE-----") {
                inside = false
                blocks.append(current.joined(separator: "\n") + "\n")
            }
        }
        return blocks
    }

    private static func parse(_ pem: String) -> SigningIdentity? {
        let result = Shell.run(
            "/usr/bin/openssl",
            ["x509", "-noout", "-subject", "-enddate", "-nameopt", "sep_multiline"],
            stdin: pem
        )
        guard result.ok else { return nil }

        var teamID: String?
        var commonName: String?
        var notAfter: String?

        for rawLine in result.stdout.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("OU=")        { teamID     = String(line.dropFirst(3)) }
            if line.hasPrefix("CN=")        { commonName = String(line.dropFirst(3)) }
            if line.hasPrefix("notAfter=")  { notAfter   = String(line.dropFirst(9)) }
        }

        guard let teamID, !teamID.isEmpty else { return nil }

        return SigningIdentity(
            teamID: teamID,
            commonName: commonName ?? "—",
            expiresAt: notAfter.flatMap(parseOpenSSLDate)
        )
    }

    // "Sep  1 12:00:00 2027 GMT" -> Remove double whitespaces.
    private static func parseOpenSSLDate(_ raw: String) -> Date? {
        let collapsed = raw
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
        return formatter.date(from: collapsed)
    }
}
