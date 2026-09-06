//
//  Xcode.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 06/09/26.
//


import Foundation

enum Xcode {

    // Xcode nyimpen nilai build setting yang udah ke-resolve di memori. Kalau dia
    // lagi buka project waktu `init` jalan, nilai lama itu bisa ditulis balik ke
    // .pbxproj sesudahnya, lengkap sama suffix lokal.
    
    static var isRunning: Bool {
        Shell.run("/usr/bin/pgrep", ["-x", "Xcode"]).ok
    }
}
