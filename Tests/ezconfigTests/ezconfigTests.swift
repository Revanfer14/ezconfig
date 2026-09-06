import Testing
@testable import ezconfigKit

private let suffixes: Set<String> = [".ns8wsvtkad", ".f9g8h7j6k5"]
private let prefix = "com.x.app"
private let token = "$(BUNDLE_PREFIX)"

@Suite("SuffixCleaner.clean, anchored")
struct AnchoredCleaning {

    @Test("suffix tepat setelah prefix literal dibuang")
    func afterLiteralPrefix() {
        let r = SuffixCleaner.clean(
            "com.x.app.ns8wsvtkad.watchkitapp",
            anchors: [prefix, token], suffixes: suffixes
        )
        #expect(r.value == "com.x.app.watchkitapp")
        #expect(r.removed == ".ns8wsvtkad")
    }

    @Test("suffix tepat setelah token variabel dibuang")
    func afterToken() {
        let r = SuffixCleaner.clean(
            "$(BUNDLE_PREFIX).ns8wsvtkad.watchkitapp",
            anchors: [prefix, token], suffixes: suffixes
        )
        #expect(r.value == "$(BUNDLE_PREFIX).watchkitapp")
    }

    @Test("suffix di tengah ekor NGGAK disentuh")
    func midTailUntouched() {
        let r = SuffixCleaner.clean(
            "com.x.app.share.ns8wsvtkad",
            anchors: [prefix, token], suffixes: suffixes
        )
        #expect(r.didClean == false)
        #expect(r.value == "com.x.app.share.ns8wsvtkad")
    }

    @Test("suffix dobel: yang anchored kebuang, yang di ekor tetap")
    func doubled() {
        let r = SuffixCleaner.clean(
            "$(BUNDLE_PREFIX).ns8wsvtkad.share.ns8wsvtkad",
            anchors: [prefix, token], suffixes: suffixes
        )
        #expect(r.value == "$(BUNDLE_PREFIX).share.ns8wsvtkad")
    }

    @Test("nempel tanpa titik tetap kebuang")
    func noLeadingDot() {
        // Xcode bikin test target dengan bundle ID nempel tanpa titik.
        let r = SuffixCleaner.clean(
            "com.x.app.ns8wsvtkadTests",
            anchors: [prefix, token], suffixes: suffixes
        )
        #expect(r.value == "com.x.appTests")
    }

    @Test("himpunan suffix kosong nggak ngapa-ngapain")
    func emptySet() {
        let r = SuffixCleaner.clean(
            "com.x.app.ns8wsvtkad", anchors: [prefix], suffixes: []
        )
        #expect(r.didClean == false)
    }
}

@Suite("SuffixCleaner.looksLikeSuffix")
struct SuffixShape {

    @Test("10 alnum lowercase campur angka itu suffix")
    func teamIDShaped() {
        #expect(SuffixCleaner.looksLikeSuffix("ns8wsvtkad"))
    }

    @Test("varian berawalan t buat Team ID yang mulai angka")
    func tPrefixed() {
        #expect(SuffixCleaner.looksLikeSuffix("t9g8h7j6k5"))
    }

    @Test("kata Inggris 10 huruf tanpa angka bukan suffix")
    func englishWordRejected() {
        // Ini alasan syarat 'wajib ada angka' dibikin.
        #expect(!SuffixCleaner.looksLikeSuffix("extensions"))
        #expect(!SuffixCleaner.looksLikeSuffix("watchkitapp"))
    }

    @Test("panjang salah ditolak")
    func wrongLength() {
        #expect(!SuffixCleaner.looksLikeSuffix("ns8wsvtka"))
        #expect(!SuffixCleaner.looksLikeSuffix("ns8wsvtkade"))
    }

    @Test("huruf besar ditolak")
    func uppercaseRejected() {
        #expect(!SuffixCleaner.looksLikeSuffix("NS8WSVTKAD"))
    }
}

@Suite("SuffixCleaner.cleanAppGroup")
struct AppGroupCleaning {

    @Test("cocok persis sama binding yang udah ada")
    func exactMatch() {
        let r = SuffixCleaner.cleanAppGroup(
            "group.com.x.app.ns8wsvtkad",
            knownCanonicals: ["group.com.x.app"],
            suffixes: suffixes
        )
        #expect(r.value == "group.com.x.app")
        #expect(r.removed == ".ns8wsvtkad")
    }

    @Test("fallback hasSuffix waktu belum ada binding")
    func fallback() {
        let r = SuffixCleaner.cleanAppGroup(
            "group.com.lain.thing.ns8wsvtkad",
            knownCanonicals: [],
            suffixes: suffixes
        )
        #expect(r.value == "group.com.lain.thing")
    }

    @Test("group bersih nggak disentuh")
    func cleanUntouched() {
        let r = SuffixCleaner.cleanAppGroup(
            "group.com.x.app",
            knownCanonicals: ["group.com.x.app"],
            suffixes: suffixes
        )
        #expect(r.didClean == false)
    }
}

@Suite("SuffixCleaner.suspiciousComponent")
struct SuspiciousDetection {

    @Test("komponen berbentuk suffix ketangkep di remainder")
    func caught() {
        #expect(SuffixCleaner.suspiciousComponent(in: ".share.ns8wsvtkad") == "ns8wsvtkad")
    }

    @Test("remainder wajar nggak kena")
    func clean() {
        #expect(SuffixCleaner.suspiciousComponent(in: ".watchkitapp") == nil)
        #expect(SuffixCleaner.suspiciousComponent(in: "-Watch-App-Watch-AppTests") == nil)
        #expect(SuffixCleaner.suspiciousComponent(in: "Tests") == nil)
    }
}
