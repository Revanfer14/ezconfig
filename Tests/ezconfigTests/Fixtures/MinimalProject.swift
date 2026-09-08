//
//  MinimalProject.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 07/09/26.
//

import Foundation
import PathKit

// Diturunin dari sandbox SignTest: satu target application, udah ke-link ke
// Base.xcconfig, plus DEVELOPMENT_TEAM yang nempel biar strip ada kerjaan.
enum MinimalProject {

    static let bundleID = "com.revan.fixture"
    static let teamID = "ABCDE12345"
    static let bundleIDToken = "$(BUNDLE_PREFIX)"

    private static func pbxproj(bundleIDValue: String, entitlementsPath: String? = nil) -> String {
        let entitlementsLine = entitlementsPath.map { "\t\t\t\tCODE_SIGN_ENTITLEMENTS = \($0);\n" } ?? ""
        return """
    // !$*UTF8*$!
    {
    \tarchiveVersion = 1;
    \tclasses = {
    \t};
    \tobjectVersion = 77;
    \tobjects = {

    /* Begin PBXFileReference section */
    \t\t7655446C30491CB000EC4661 /* Fixture.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Fixture.app; sourceTree = BUILT_PRODUCTS_DIR; };
    \t\t82E3D3454D94E554A1BCD4DA /* Base.xcconfig */ = {isa = PBXFileReference; explicitFileType = text.xcconfig; name = Base.xcconfig; path = Configs/Base.xcconfig; sourceTree = "<group>"; };
    /* End PBXFileReference section */

    /* Begin PBXFileSystemSynchronizedRootGroup section */
    \t\t7655446E30491CB000EC4661 /* Fixture */ = {
    \t\t\tisa = PBXFileSystemSynchronizedRootGroup;
    \t\t\tpath = Fixture;
    \t\t\tsourceTree = "<group>";
    \t\t};
    /* End PBXFileSystemSynchronizedRootGroup section */

    /* Begin PBXFrameworksBuildPhase section */
    \t\t7655446930491CB000EC4661 /* Frameworks */ = {
    \t\t\tisa = PBXFrameworksBuildPhase;
    \t\t\tbuildActionMask = 2147483647;
    \t\t\tfiles = (
    \t\t\t);
    \t\t\trunOnlyForDeploymentPostprocessing = 0;
    \t\t};
    /* End PBXFrameworksBuildPhase section */

    /* Begin PBXGroup section */
    \t\t7655446330491CB000EC4661 = {
    \t\t\tisa = PBXGroup;
    \t\t\tchildren = (
    \t\t\t\t7655446E30491CB000EC4661 /* Fixture */,
    \t\t\t\t7655446D30491CB000EC4661 /* Products */,
    \t\t\t\t82E3D3454D94E554A1BCD4DA /* Base.xcconfig */,
    \t\t\t);
    \t\t\tsourceTree = "<group>";
    \t\t};
    \t\t7655446D30491CB000EC4661 /* Products */ = {
    \t\t\tisa = PBXGroup;
    \t\t\tchildren = (
    \t\t\t\t7655446C30491CB000EC4661 /* Fixture.app */,
    \t\t\t);
    \t\t\tname = Products;
    \t\t\tsourceTree = "<group>";
    \t\t};
    /* End PBXGroup section */

    /* Begin PBXNativeTarget section */
    \t\t7655446B30491CB000EC4661 /* Fixture */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tbuildConfigurationList = 7655447730491CB100EC4661 /* Build configuration list for PBXNativeTarget "Fixture" */;
    \t\t\tbuildPhases = (
    \t\t\t\t7655446830491CB000EC4661 /* Sources */,
    \t\t\t\t7655446930491CB000EC4661 /* Frameworks */,
    \t\t\t\t7655446A30491CB000EC4661 /* Resources */,
    \t\t\t);
    \t\t\tbuildRules = (
    \t\t\t);
    \t\t\tdependencies = (
    \t\t\t);
    \t\t\tfileSystemSynchronizedGroups = (
    \t\t\t\t7655446E30491CB000EC4661 /* Fixture */,
    \t\t\t);
    \t\t\tname = Fixture;
    \t\t\tpackageProductDependencies = (
    \t\t\t);
    \t\t\tproductName = Fixture;
    \t\t\tproductReference = 7655446C30491CB000EC4661 /* Fixture.app */;
    \t\t\tproductType = "com.apple.product-type.application";
    \t\t};
    /* End PBXNativeTarget section */

    /* Begin PBXProject section */
    \t\t7655446430491CB000EC4661 /* Project object */ = {
    \t\t\tisa = PBXProject;
    \t\t\tattributes = {
    \t\t\t\tBuildIndependentTargetsInParallel = 1;
    \t\t\t\tLastSwiftUpdateCheck = 2660;
    \t\t\t\tLastUpgradeCheck = 2660;
    \t\t\t\tTargetAttributes = {
    \t\t\t\t\t7655446B30491CB000EC4661 = {
    \t\t\t\t\t\tCreatedOnToolsVersion = 26.6;
    \t\t\t\t\t};
    \t\t\t\t};
    \t\t\t};
    \t\t\tbuildConfigurationList = 7655446730491CB000EC4661 /* Build configuration list for PBXProject "Fixture" */;
    \t\t\tdevelopmentRegion = en;
    \t\t\thasScannedForEncodings = 0;
    \t\t\tknownRegions = (
    \t\t\t\ten,
    \t\t\t\tBase,
    \t\t\t);
    \t\t\tmainGroup = 7655446330491CB000EC4661;
    \t\t\tminimizedProjectReferenceProxies = 1;
    \t\t\tpreferredProjectObjectVersion = 77;
    \t\t\tproductRefGroup = 7655446D30491CB000EC4661 /* Products */;
    \t\t\tprojectDirPath = "";
    \t\t\tprojectRoot = "";
    \t\t\ttargets = (
    \t\t\t\t7655446B30491CB000EC4661 /* Fixture */,
    \t\t\t);
    \t\t};
    /* End PBXProject section */

    /* Begin PBXResourcesBuildPhase section */
    \t\t7655446A30491CB000EC4661 /* Resources */ = {
    \t\t\tisa = PBXResourcesBuildPhase;
    \t\t\tbuildActionMask = 2147483647;
    \t\t\tfiles = (
    \t\t\t);
    \t\t\trunOnlyForDeploymentPostprocessing = 0;
    \t\t};
    /* End PBXResourcesBuildPhase section */

    /* Begin PBXSourcesBuildPhase section */
    \t\t7655446830491CB000EC4661 /* Sources */ = {
    \t\t\tisa = PBXSourcesBuildPhase;
    \t\t\tbuildActionMask = 2147483647;
    \t\t\tfiles = (
    \t\t\t);
    \t\t\trunOnlyForDeploymentPostprocessing = 0;
    \t\t};
    /* End PBXSourcesBuildPhase section */

    /* Begin XCBuildConfiguration section */
    \t\t7655447530491CB100EC4661 /* Debug */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbuildSettings = {
    \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t};
    \t\t\tname = Debug;
    \t\t};
    \t\t7655447630491CB100EC4661 /* Release */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbuildSettings = {
    \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t};
    \t\t\tname = Release;
    \t\t};
    \t\t7655447830491CB100EC4661 /* Debug */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = 82E3D3454D94E554A1BCD4DA /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \(entitlementsLine)\t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = \(teamID);
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(bundleIDValue)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
    \t\t\t};
    \t\t\tname = Debug;
    \t\t};
    \t\t7655447930491CB100EC4661 /* Release */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = 82E3D3454D94E554A1BCD4DA /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \(entitlementsLine)\t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = \(teamID);
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(bundleIDValue)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
    \t\t\t};
    \t\t\tname = Release;
    \t\t};
    /* End XCBuildConfiguration section */

    /* Begin XCConfigurationList section */
    \t\t7655446730491CB000EC4661 /* Build configuration list for PBXProject "Fixture" */ = {
    \t\t\tisa = XCConfigurationList;
    \t\t\tbuildConfigurations = (
    \t\t\t\t7655447530491CB100EC4661 /* Debug */,
    \t\t\t\t7655447630491CB100EC4661 /* Release */,
    \t\t\t);
    \t\t\tdefaultConfigurationIsVisible = 0;
    \t\t\tdefaultConfigurationName = Release;
    \t\t};
    \t\t7655447730491CB100EC4661 /* Build configuration list for PBXNativeTarget "Fixture" */ = {
    \t\t\tisa = XCConfigurationList;
    \t\t\tbuildConfigurations = (
    \t\t\t\t7655447830491CB100EC4661 /* Debug */,
    \t\t\t\t7655447930491CB100EC4661 /* Release */,
    \t\t\t);
    \t\t\tdefaultConfigurationIsVisible = 0;
    \t\t\tdefaultConfigurationName = Release;
    \t\t};
    /* End XCConfigurationList section */
    \t};
    \trootObject = 7655446430491CB000EC4661 /* Project object */;
    }

    """
    }

    static let entitlementsFile = "Fixture.entitlements"

    private static func entitlementsPlist(appGroups: [String]) -> String {
        let items = appGroups.map { "\t\t<string>\($0)</string>\n" }.joined()
        return """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>com.apple.security.application-groups</key>
    \t<array>
    \(items)\t</array>
    </dict>
    </plist>

    """
    }

    // Taro di folder temp, isinya Fixture.xcodeproj/project.pbxproj. Base.xcconfig
    // dibikin opsional biar tiap test bisa nyoba skenario belum-diinit-nya.
    // `templated: true` mensimulasikan project yang udah pernah di-init, jadi
    // PRODUCT_BUNDLE_IDENTIFIER-nya udah $(BUNDLE_PREFIX), bukan literal.
    // `entitlementsAppGroups` nulis Fixture.entitlements dengan array App Group
    // itu apa adanya — isi sama dua kali buat mensimulasikan entry duplikat.
    @discardableResult
    static func materialize(
        in root: Path,
        withBaseConfig: Bool = true,
        templated: Bool = false,
        entitlementsAppGroups: [String]? = nil
    ) throws -> Path {
        let projectPath = root + "Fixture.xcodeproj"
        try projectPath.mkpath()
        let value = templated ? bundleIDToken : bundleID
        let entitlementsPath = entitlementsAppGroups != nil ? entitlementsFile : nil
        try (projectPath + "project.pbxproj")
            .write(pbxproj(bundleIDValue: value, entitlementsPath: entitlementsPath))

        if withBaseConfig {
            let configsDir = root + "Configs"
            try configsDir.mkpath()
            try (configsDir + "Base.xcconfig").write("BUNDLE_PREFIX = \(bundleID)\n")
        }

        if let appGroups = entitlementsAppGroups {
            try (root + entitlementsFile).write(entitlementsPlist(appGroups: appGroups))
        }

        return projectPath
    }
}
