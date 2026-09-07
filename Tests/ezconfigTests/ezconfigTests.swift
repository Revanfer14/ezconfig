import Foundation
import PathKit
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

// Helper

private func makeConfig(
    name: String,
    bundleID: String?,
    baseConfigFile: String?
) -> ConfigInfo {
    ConfigInfo(
        name: name,
        bundleID: bundleID.map { SettingValue(value: $0, source: .target) },
        team: nil,
        baseConfigFile: baseConfigFile,
        sdkroot: "iphoneos",
        entitlements: nil,
        companionBundleID: nil,
        infoPlistFile: nil,
        generatesInfoPlist: true
    )
}

private func makeInfo(_ targets: [(String, [ConfigInfo])]) -> ProjectInfo {
    ProjectInfo(
        path: "/tmp/T.xcodeproj",
        name: "T",
        targets: targets.map {
            TargetInfo(
                name: $0.0,
                productType: "app",
                rawProductType: "com.apple.product-type.application",
                platform: .iOS,
                attributeTeam: nil,
                configs: $0.1
            )
        }
    )
}

@Suite("template tanpa link ketangkep")
struct DanglingTemplate {

    @Test("target ke-link nggak dilaporin")
    func linkedIsClean() {
        let info = makeInfo([("App", [
            makeConfig(name: "Debug", bundleID: "$(BUNDLE_PREFIX)", baseConfigFile: "Base.xcconfig"),
            makeConfig(name: "Release", bundleID: "$(BUNDLE_PREFIX)", baseConfigFile: "Base.xcconfig"),
        ])])
        #expect(ConfigAudit.dangling(info: info).isEmpty)
    }

    @Test("template tanpa link ketangkep di semua config")
    func unlinkedCaught() {
        let info = makeInfo([("Notif", [
            makeConfig(name: "Debug", bundleID: "$(BUNDLE_PREFIX).Notif", baseConfigFile: nil),
            makeConfig(name: "Release", bundleID: "$(BUNDLE_PREFIX).Notif", baseConfigFile: nil),
        ])])
        #expect(ConfigAudit.dangling(info: info).count == 2)
    }

    // Kasus yang bikin cek per-target bakal lolos diem-diem.
    @Test("Debug ke-link tapi Release nggak, tetap ketangkep")
    func halfLinked() {
        let info = makeInfo([("App", [
            makeConfig(name: "Debug", bundleID: "$(BUNDLE_PREFIX)", baseConfigFile: "Base.xcconfig"),
            makeConfig(name: "Release", bundleID: "$(BUNDLE_PREFIX)", baseConfigFile: nil),
        ])])
        let d = ConfigAudit.dangling(info: info)
        #expect(d.count == 1)
        #expect(d.first?.config == "Release")
    }

    @Test("literal tanpa link bukan urusan dangling")
    func literalIgnored() {
        let info = makeInfo([("Notif", [
            makeConfig(name: "Debug", bundleID: "com.revan.T.Notif", baseConfigFile: nil),
        ])])
        #expect(ConfigAudit.dangling(info: info).isEmpty)
    }
}

@Suite("nilai di target nggak ke-link nggak masuk blocking")
struct UnlinkedRouting {

    private func finding(_ value: String) -> Finding {
        Finding(key: .bundleID, kind: .literal, value: value, line: 1)
    }

    @Test("dirutein ke unlinked, bukan blocking")
    func routedAway() {
        var allow = CheckPolicy.Allowlist()
        allow.unlinked = ["com.revan.T.Notif"]

        let s = CheckPolicy.split([finding("com.revan.T.Notif")], allowlist: allow)
        #expect(s.blocking.isEmpty)
        #expect(s.unlinked.count == 1)
    }

    @Test("outsidePrefix menang atas unlinked")
    func toleratedWins() {
        var allow = CheckPolicy.Allowlist()
        allow.outsidePrefix = ["com.lain.widget"]
        allow.unlinked = ["com.lain.widget"]

        let s = CheckPolicy.split([finding("com.lain.widget")], allowlist: allow)
        #expect(s.tolerated.count == 1)
        #expect(s.unlinked.isEmpty)
    }

    @Test("Team ID tetap blocking walau targetnya nggak ke-link")
    func teamStillBlocks() {
        var allow = CheckPolicy.Allowlist()
        allow.unlinked = ["ABCDE12345"]

        let f = Finding(key: .developmentTeam, kind: .literal, value: "ABCDE12345", line: 1)
        #expect(CheckPolicy.split([f], allowlist: allow).blocking.count == 1)
    }
}

private func withTempRoot(_ body: (Path) throws -> Void) throws {
    let root = Path(NSTemporaryDirectory()) + "ezconfig-writer-\(UUID().uuidString)"
    try root.mkpath()
    defer { try? root.delete() }
    try body(root)
}

private func mutate(_ pbxprojPath: Path) throws {
    let text: String = try pbxprojPath.read()
    try pbxprojPath.write(text + "\n")
}

@Suite("ProjectWriter menolak nulis pas project.pbxproj berubah di bawahnya")
struct ProjectWriterDigestGuard {

    @Test("runStrip nolak kalau file berubah setelah writer dibikin")
    func runStripDetectsChange() throws {
        try withTempRoot { root in
            let projectPath = try MinimalProject.materialize(in: root)
            let writer = try ProjectWriter(projectPath: projectPath)

            try mutate(projectPath + "project.pbxproj")

            let before = try (projectPath + "project.pbxproj").read() as String
            #expect(throws: WriteError.self) { try writer.runStrip() }
            let after = try (projectPath + "project.pbxproj").read() as String
            #expect(before == after)
        }
    }

    @Test("runInit nolak sebelum Base.xcconfig ditulis")
    func runInitAbortsBeforeBaseConfigWrite() throws {
        try withTempRoot { root in
            let projectPath = try MinimalProject.materialize(in: root, withBaseConfig: false)
            let writer = try ProjectWriter(projectPath: projectPath)

            try mutate(projectPath + "project.pbxproj")

            #expect(throws: WriteError.self) {
                try writer.runInit(overridePrefix: nil, dryRun: false)
            }
            #expect(!(root + "Configs" + "Base.xcconfig").exists)
        }
    }

    @Test("runInit --dry-run nggak kepengaruh, nggak nulis apa-apa")
    func runInitDryRunIgnoresChange() throws {
        try withTempRoot { root in
            let projectPath = try MinimalProject.materialize(in: root, withBaseConfig: false)
            let writer = try ProjectWriter(projectPath: projectPath)

            try mutate(projectPath + "project.pbxproj")

            #expect(throws: Never.self) {
                try writer.runInit(overridePrefix: nil, dryRun: true)
            }
            #expect(!(root + "Configs" + "Base.xcconfig").exists)
        }
    }

    @Test("fixture yang nggak disentuh tetap strip normal")
    func untouchedFixtureStripsNormally() throws {
        try withTempRoot { root in
            let projectPath = try MinimalProject.materialize(in: root)
            let writer = try ProjectWriter(projectPath: projectPath)

            let outcome = try writer.runStrip()
            #expect(outcome.teamsRemoved == 2)
            #expect(outcome.bundleIDsRewritten == 2)
        }
    }

    @Test("plan(_:) gagal di runStrip nyebar, bukan strip separuh jadi")
    func runStripPropagatesPlanFailure() throws {
        try withTempRoot { root in
            let projectPath = try MinimalProject.materialize(in: root, templated: true)
            try (root + "Configs" + "Base.xcconfig").write("// tanpa BUNDLE_PREFIX\n")

            let writer = try ProjectWriter(projectPath: projectPath)
            let before = try (projectPath + "project.pbxproj").read() as String

            #expect(throws: PlanError.self) { try writer.runStrip() }

            let after = try (projectPath + "project.pbxproj").read() as String
            #expect(before == after)
        }
    }
}
