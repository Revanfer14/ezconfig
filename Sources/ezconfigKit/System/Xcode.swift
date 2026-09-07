//
//  Xcode.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//


import Foundation

enum Xcode {

    // Xcode nyimpen nilai build setting yang udah ke-resolve di memori dan bisa
    // nulis balik ke .pbxproj kapan aja. `init` nggak nunggu Xcode ditutup lagi,
    // jadi ini cuma dipake buat ngasih tau developer di report kalau reload bisa
    // kejadian sesudah init selesai.

    static var isRunning: Bool {
        Shell.run("/usr/bin/pgrep", ["-x", "Xcode"]).ok
    }
}
