//
//  WatchProject.swift
//  ezconfig
//
//  Created by Revan Ferdinand on 10/09/26.
//

import Foundation
import PathKit

// Modern single-target watchOS app embedded in an iOS app, both already
// linked to Base.xcconfig, both still carrying literal signing values. Used
// to reproduce the Vitals WKCompanionAppBundleIdentifier defect end to end.
enum WatchProject {

    static let appBundleID = "com.x.app"
    static let watchBundleID = "com.x.app.watch"
    static let staleCompanion = "com.x"

    private static func pbxproj(companionValue: String) -> String {
        """
    // !$*UTF8*$!
    {
    \tarchiveVersion = 1;
    \tclasses = {
    \t};
    \tobjectVersion = 77;
    \tobjects = {

    /* Begin PBXFileReference section */
    \t\tAAAAAAAAAAAAAAAAAAAA0001 /* App.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = App.app; sourceTree = BUILT_PRODUCTS_DIR; };
    \t\tAAAAAAAAAAAAAAAAAAAA0002 /* Watch.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Watch.app; sourceTree = BUILT_PRODUCTS_DIR; };
    \t\tAAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */ = {isa = PBXFileReference; explicitFileType = text.xcconfig; name = Base.xcconfig; path = Configs/Base.xcconfig; sourceTree = "<group>"; };
    /* End PBXFileReference section */

    /* Begin PBXFrameworksBuildPhase section */
    \t\tAAAAAAAAAAAAAAAAAAAA0004 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    \t\tAAAAAAAAAAAAAAAAAAAA0007 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    /* End PBXFrameworksBuildPhase section */

    /* Begin PBXSourcesBuildPhase section */
    \t\tAAAAAAAAAAAAAAAAAAAA0005 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    \t\tAAAAAAAAAAAAAAAAAAAA0008 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    /* End PBXSourcesBuildPhase section */

    /* Begin PBXResourcesBuildPhase section */
    \t\tAAAAAAAAAAAAAAAAAAAA0006 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    \t\tAAAAAAAAAAAAAAAAAAAA0009 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
    /* End PBXResourcesBuildPhase section */

    /* Begin PBXGroup section */
    \t\tAAAAAAAAAAAAAAAAAAAA000A = {
    \t\t\tisa = PBXGroup;
    \t\t\tchildren = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA000B /* Products */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */,
    \t\t\t);
    \t\t\tsourceTree = "<group>";
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA000B /* Products */ = {
    \t\t\tisa = PBXGroup;
    \t\t\tchildren = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0001 /* App.app */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0002 /* Watch.app */,
    \t\t\t);
    \t\t\tname = Products;
    \t\t\tsourceTree = "<group>";
    \t\t};
    /* End PBXGroup section */

    /* Begin PBXNativeTarget section */
    \t\tAAAAAAAAAAAAAAAAAAAA000C /* App */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tbuildConfigurationList = AAAAAAAAAAAAAAAAAAAA0016 /* Build configuration list for PBXNativeTarget "App" */;
    \t\t\tbuildPhases = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0005 /* Sources */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0004 /* Frameworks */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0006 /* Resources */,
    \t\t\t);
    \t\t\tbuildRules = (
    \t\t\t);
    \t\t\tdependencies = (
    \t\t\t);
    \t\t\tname = App;
    \t\t\tproductName = App;
    \t\t\tproductReference = AAAAAAAAAAAAAAAAAAAA0001 /* App.app */;
    \t\t\tproductType = "com.apple.product-type.application";
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA000D /* Watch */ = {
    \t\t\tisa = PBXNativeTarget;
    \t\t\tbuildConfigurationList = AAAAAAAAAAAAAAAAAAAA0017 /* Build configuration list for PBXNativeTarget "Watch" */;
    \t\t\tbuildPhases = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0008 /* Sources */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0007 /* Frameworks */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0009 /* Resources */,
    \t\t\t);
    \t\t\tbuildRules = (
    \t\t\t);
    \t\t\tdependencies = (
    \t\t\t);
    \t\t\tname = Watch;
    \t\t\tproductName = Watch;
    \t\t\tproductReference = AAAAAAAAAAAAAAAAAAAA0002 /* Watch.app */;
    \t\t\tproductType = "com.apple.product-type.application";
    \t\t};
    /* End PBXNativeTarget section */

    /* Begin PBXProject section */
    \t\tAAAAAAAAAAAAAAAAAAAA000E /* Project object */ = {
    \t\t\tisa = PBXProject;
    \t\t\tattributes = {
    \t\t\t\tBuildIndependentTargetsInParallel = 1;
    \t\t\t\tLastSwiftUpdateCheck = 2660;
    \t\t\t\tLastUpgradeCheck = 2660;
    \t\t\t\tTargetAttributes = {
    \t\t\t\t\tAAAAAAAAAAAAAAAAAAAA000C = {
    \t\t\t\t\t\tCreatedOnToolsVersion = 26.6;
    \t\t\t\t\t};
    \t\t\t\t\tAAAAAAAAAAAAAAAAAAAA000D = {
    \t\t\t\t\t\tCreatedOnToolsVersion = 26.6;
    \t\t\t\t\t};
    \t\t\t\t};
    \t\t\t};
    \t\t\tbuildConfigurationList = AAAAAAAAAAAAAAAAAAAA0015 /* Build configuration list for PBXProject "WatchFixture" */;
    \t\t\tdevelopmentRegion = en;
    \t\t\thasScannedForEncodings = 0;
    \t\t\tknownRegions = (
    \t\t\t\ten,
    \t\t\t\tBase,
    \t\t\t);
    \t\t\tmainGroup = AAAAAAAAAAAAAAAAAAAA000A;
    \t\t\tminimizedProjectReferenceProxies = 1;
    \t\t\tpreferredProjectObjectVersion = 77;
    \t\t\tproductRefGroup = AAAAAAAAAAAAAAAAAAAA000B /* Products */;
    \t\t\tprojectDirPath = "";
    \t\t\tprojectRoot = "";
    \t\t\ttargets = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA000C /* App */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA000D /* Watch */,
    \t\t\t);
    \t\t};
    /* End PBXProject section */

    /* Begin XCBuildConfiguration section */
    \t\tAAAAAAAAAAAAAAAAAAAA000F /* Debug */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbuildSettings = {
    \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t};
    \t\t\tname = Debug;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0010 /* Release */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbuildSettings = {
    \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t};
    \t\t\tname = Release;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0011 /* Debug */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = AAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(appBundleID)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
    \t\t\t};
    \t\t\tname = Debug;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0012 /* Release */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = AAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(appBundleID)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSDKROOT = iphoneos;
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
    \t\t\t};
    \t\t\tname = Release;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0013 /* Debug */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = AAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tINFOPLIST_KEY_WKCompanionAppBundleIdentifier = "\(companionValue)";
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(watchBundleID)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSDKROOT = watchos;
    \t\t\t\tSKIP_INSTALL = YES;
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = 4;
    \t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t};
    \t\t\tname = Debug;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0014 /* Release */ = {
    \t\t\tisa = XCBuildConfiguration;
    \t\t\tbaseConfigurationReference = AAAAAAAAAAAAAAAAAAAA0003 /* Base.xcconfig */;
    \t\t\tbuildSettings = {
    \t\t\t\tCODE_SIGN_STYLE = Automatic;
    \t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;
    \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
    \t\t\t\tINFOPLIST_KEY_WKCompanionAppBundleIdentifier = "\(companionValue)";
    \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "\(watchBundleID)";
    \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
    \t\t\t\tSDKROOT = watchos;
    \t\t\t\tSKIP_INSTALL = YES;
    \t\t\t\tSWIFT_VERSION = 5.0;
    \t\t\t\tTARGETED_DEVICE_FAMILY = 4;
    \t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 26.5;
    \t\t\t};
    \t\t\tname = Release;
    \t\t};
    /* End XCBuildConfiguration section */

    /* Begin XCConfigurationList section */
    \t\tAAAAAAAAAAAAAAAAAAAA0015 /* Build configuration list for PBXProject "WatchFixture" */ = {
    \t\t\tisa = XCConfigurationList;
    \t\t\tbuildConfigurations = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA000F /* Debug */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0010 /* Release */,
    \t\t\t);
    \t\t\tdefaultConfigurationIsVisible = 0;
    \t\t\tdefaultConfigurationName = Release;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0016 /* Build configuration list for PBXNativeTarget "App" */ = {
    \t\t\tisa = XCConfigurationList;
    \t\t\tbuildConfigurations = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0011 /* Debug */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0012 /* Release */,
    \t\t\t);
    \t\t\tdefaultConfigurationIsVisible = 0;
    \t\t\tdefaultConfigurationName = Release;
    \t\t};
    \t\tAAAAAAAAAAAAAAAAAAAA0017 /* Build configuration list for PBXNativeTarget "Watch" */ = {
    \t\t\tisa = XCConfigurationList;
    \t\t\tbuildConfigurations = (
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0013 /* Debug */,
    \t\t\t\tAAAAAAAAAAAAAAAAAAAA0014 /* Release */,
    \t\t\t);
    \t\t\tdefaultConfigurationIsVisible = 0;
    \t\t\tdefaultConfigurationName = Release;
    \t\t};
    /* End XCConfigurationList section */
    \t};
    \trootObject = AAAAAAAAAAAAAAAAAAAA000E /* Project object */;
    }

    """
    }

    // Taro di folder temp, isinya WatchFixture.xcodeproj/project.pbxproj.
    // Base.xcconfig sengaja nggak ditulis ke disk biar prefix diturunin dari
    // literal App target, kayak init pertama kali.
    @discardableResult
    static func materialize(in root: Path, companionValue: String) throws -> Path {
        let projectPath = root + "WatchFixture.xcodeproj"
        try projectPath.mkpath()
        try (projectPath + "project.pbxproj")
            .write(pbxproj(companionValue: companionValue))
        return projectPath
    }
}
