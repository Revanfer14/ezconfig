//
//  PlistText.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 04/09/26.
//


import Foundation

enum PlistText {

    static func isXML(_ text: String) -> Bool {
        let head = text.prefix(200)
        return head.contains("<?xml") || head.contains("<!DOCTYPE plist")
    }

    // Ganti isi <string> yang persis nempel setelah <key>NAMA</key>.
    static func replaceStringValue(
        key: String,
        with newValue: String,
        in text: String
    ) -> (text: String, replaced: Int) {

        let marker = "<key>\(key)</key>"
        var out = ""
        var rest = Substring(text)
        var count = 0

        while let keyRange = rest.range(of: marker) {
            out += rest[rest.startIndex..<keyRange.upperBound]
            var tail = rest[keyRange.upperBound...]

            if let open = tail.range(of: "<string>"),
               let close = tail.range(of: "</string>",
                                      range: open.upperBound..<tail.endIndex),
               tail[tail.startIndex..<open.lowerBound].allSatisfy(\.isWhitespace) {

                out += tail[tail.startIndex..<open.upperBound]
                out += escape(newValue)
                out += "</string>"
                count += 1
                tail = tail[close.upperBound...]
            }

            rest = tail
        }

        out += rest
        return (out, count)
    }
    
    // Ganti <string> di dalam <array> yang ngikutin <key>NAMA</key>
    static func replaceArrayStrings(
        key: String,
        in text: String,
        transform: (String) -> String?
    ) -> (text: String, replaced: Int) {

        let marker = "<key>\(key)</key>"
        var out = ""
        var rest = Substring(text)
        var count = 0

        while let keyRange = rest.range(of: marker) {
            out += rest[rest.startIndex..<keyRange.upperBound]
            var tail = rest[keyRange.upperBound...]

            guard let open = tail.range(of: "<array>"),
                  let close = tail.range(of: "</array>",
                                         range: open.upperBound..<tail.endIndex),
                  tail[tail.startIndex..<open.lowerBound].allSatisfy(\.isWhitespace)
            else {
                rest = tail
                continue
            }

            out += tail[tail.startIndex..<open.upperBound]

            let body = String(tail[open.upperBound..<close.lowerBound])
            let r = rewriteStrings(in: body, transform: transform)
            out += r.text
            count += r.replaced

            out += "</array>"
            tail = tail[close.upperBound...]
            rest = tail
        }

        out += rest
        return (out, count)
    }

    private static func rewriteStrings(
        in body: String,
        transform: (String) -> String?
    ) -> (text: String, replaced: Int) {

        var out = ""
        var rest = Substring(body)
        var count = 0

        while let open = rest.range(of: "<string>"),
              let close = rest.range(of: "</string>",
                                     range: open.upperBound..<rest.endIndex) {

            out += rest[rest.startIndex..<open.upperBound]
            let current = unescape(String(rest[open.upperBound..<close.lowerBound]))

            if let replacement = transform(current) {
                out += escape(replacement)
                count += 1
            } else {
                out += rest[open.upperBound..<close.lowerBound]
            }

            out += "</string>"
            rest = rest[close.upperBound...]
        }

        out += rest
        return (out, count)
    }

    static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
