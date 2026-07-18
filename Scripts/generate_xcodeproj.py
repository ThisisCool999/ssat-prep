#!/usr/bin/env python3
"""Generates SSATPrep.xcodeproj from the source tree.

Three native targets mirroring the SwiftPM layout so both build systems work:
  - SSATCore      (static library, module `SSATCore`)  ← all logic, testable
  - SSATPrep      (macOS app)                           ← SwiftUI views, links SSATCore
  - SSATCoreTests (unit-test bundle)                    ← @testable import SSATCore

Re-run after adding/removing source files:  python3 Scripts/generate_xcodeproj.py
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "SSATPrep.xcodeproj"

_counter = [0]
def oid():
    _counter[0] += 1
    return f"{_counter[0]:024X}"

def swift_files(rel):
    base = ROOT / rel
    return sorted(str(p.relative_to(ROOT)) for p in base.rglob("*.swift"))

core_files = swift_files("Sources/SSATCore")
app_files = swift_files("Sources/SSATPrep")
test_files = swift_files("Tests/SSATCoreTests")

objects = []
def add(oid_, body):
    objects.append(f"\t\t{oid_} = {{{body}}};")

# ---- file references for sources -------------------------------------------
file_ref = {}
def source_ref(path):
    i = oid()
    name = os.path.basename(path)
    file_ref[path] = i
    add(i, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
           f'name = "{name}"; path = "{path}"; sourceTree = "<group>";')
    return i

for f in core_files + app_files + test_files:
    source_ref(f)

info_ref = oid()
add(info_ref, 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
              'name = "Info.plist"; path = "Scripts/Info.plist"; sourceTree = "<group>";')
icon_ref = oid()
add(icon_ref, 'isa = PBXFileReference; lastKnownFileType = image.icns; '
              'name = "AppIcon.icns"; path = "Scripts/AppIcon.icns"; sourceTree = "<group>";')

# ---- product references ----------------------------------------------------
app_product = oid()
add(app_product, 'isa = PBXFileReference; explicitFileType = wrapper.application; '
                 'includeInIndex = 0; path = SSATPrep.app; sourceTree = BUILT_PRODUCTS_DIR;')
core_product = oid()
add(core_product, 'isa = PBXFileReference; explicitFileType = archive.ar; '
                  'includeInIndex = 0; path = libSSATCore.a; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = oid()
add(test_product, 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; '
                  'includeInIndex = 0; path = SSATCoreTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')

# ---- build files (sources) -------------------------------------------------
def build_files(paths):
    ids = []
    for p in paths:
        i = oid()
        add(i, f'isa = PBXBuildFile; fileRef = {file_ref[p]};')
        ids.append(i)
    return ids

core_build = build_files(core_files)
app_build = build_files(app_files)
test_build = build_files(test_files)

icon_build = oid()
add(icon_build, f'isa = PBXBuildFile; fileRef = {icon_ref};')

# app links libSSATCore.a ; tests link libSSATCore.a
app_link = oid()
add(app_link, f'isa = PBXBuildFile; fileRef = {core_product};')
test_link = oid()
add(test_link, f'isa = PBXBuildFile; fileRef = {core_product};')

# ---- groups ----------------------------------------------------------------
def group(name, children):
    i = oid()
    kids = " ".join(f"{c}," for c in children)
    add(i, f'isa = PBXGroup; children = ({kids}); name = "{name}"; sourceTree = "<group>";')
    return i

core_group = group("SSATCore", [file_ref[f] for f in core_files])
app_group = group("SSATPrep", [file_ref[f] for f in app_files])
tests_group = group("SSATCoreTests", [file_ref[f] for f in test_files])
support_group = group("Support", [info_ref, icon_ref])
products_group = group("Products", [app_product, core_product, test_product])
main_group = group("SSATPrep", [core_group, app_group, tests_group, support_group, products_group])

# ---- build phases ----------------------------------------------------------
def sources_phase(ids):
    i = oid()
    files = " ".join(f"{x}," for x in ids)
    add(i, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; '
           f'files = ({files}); runOnlyForDeploymentPostprocessing = 0;')
    return i

def frameworks_phase(ids):
    i = oid()
    files = " ".join(f"{x}," for x in ids)
    add(i, f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; '
           f'files = ({files}); runOnlyForDeploymentPostprocessing = 0;')
    return i

def resources_phase(ids):
    i = oid()
    files = " ".join(f"{x}," for x in ids)
    add(i, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; '
           f'files = ({files}); runOnlyForDeploymentPostprocessing = 0;')
    return i

core_sources = sources_phase(core_build)
core_frameworks = frameworks_phase([])
app_sources = sources_phase(app_build)
app_frameworks = frameworks_phase([app_link])
app_resources = resources_phase([icon_build])
test_sources = sources_phase(test_build)
test_frameworks = frameworks_phase([test_link])

# ---- target dependencies ---------------------------------------------------
project_id = oid()

def dependency(target_id, product_name):
    proxy = oid()
    add(proxy, f'isa = PBXContainerItemProxy; containerPortal = {project_id}; '
               f'proxyType = 1; remoteGlobalIDString = {target_id}; '
               f'remoteInfo = "{product_name}";')
    dep = oid()
    add(dep, f'isa = PBXTargetDependency; target = {target_id}; targetProxy = {proxy};')
    return dep

# ---- build configurations --------------------------------------------------
def config(name, settings):
    i = oid()
    lines = "".join(f"\n\t\t\t\t{k} = {v};" for k, v in settings.items())
    add(i, f'isa = XCBuildConfiguration; buildSettings = {{{lines}\n\t\t\t}}; name = {name};')
    return i

def config_list(debug, release):
    i = oid()
    add(i, f'isa = XCConfigurationList; buildConfigurations = ({debug}, {release}); '
           f'defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    return i

PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CODE_SIGN_IDENTITY": '"-"',
    "CODE_SIGN_STYLE": "Manual",
    "CODE_SIGNING_REQUIRED": "NO",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "macosx",
    "SWIFT_VERSION": "5.0",
}
proj_debug = config("Debug", {**PROJECT_COMMON,
    "GCC_OPTIMIZATION_LEVEL": "0",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "ENABLE_TESTABILITY": "YES"})
proj_release = config("Release", {**PROJECT_COMMON,
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"'})
proj_list = config_list(proj_debug, proj_release)

CORE_COMMON = {
    "PRODUCT_NAME": "SSATCore",
    "PRODUCT_MODULE_NAME": "SSATCore",
    "DEFINES_MODULE": "YES",
    "SKIP_INSTALL": "YES",
    "CODE_SIGNING_ALLOWED": "NO",
    "EXECUTABLE_PREFIX": "lib",
}
core_debug = config("Debug", {**CORE_COMMON, "ENABLE_TESTABILITY": "YES"})
core_release = config("Release", dict(CORE_COMMON))
core_list = config_list(core_debug, core_release)

APP_COMMON = {
    "PRODUCT_NAME": "SSATPrep",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.ssatprep.app",
    "INFOPLIST_FILE": "Scripts/Info.plist",
    "GENERATE_INFOPLIST_FILE": "NO",
    # Hardened Runtime + entitlements: required for Developer ID notarization, and
    # harmless under ad-hoc for local runs. Release signing identity is supplied by
    # Scripts/make_app.sh (SIGN_ID), so the project itself stays ad-hoc.
    "ENABLE_HARDENED_RUNTIME": "YES",
    "CODE_SIGN_ENTITLEMENTS": "Scripts/SSATPrep.entitlements",
    "COMBINE_HIDPI_IMAGES": "YES",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/../Frameworks"',
    "ASSETCATALOG_COMPILER_APPICON_NAME": '""',
}
app_debug = config("Debug", dict(APP_COMMON))
app_release = config("Release", dict(APP_COMMON))
app_list = config_list(app_debug, app_release)

TEST_COMMON = {
    "PRODUCT_NAME": "SSATCoreTests",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.ssatprep.core.tests",
    "GENERATE_INFOPLIST_FILE": "YES",
    "CODE_SIGNING_ALLOWED": "NO",
}
test_debug = config("Debug", dict(TEST_COMMON))
test_release = config("Release", dict(TEST_COMMON))
test_list = config_list(test_debug, test_release)

# ---- native targets --------------------------------------------------------
core_target = oid()
app_target = oid()
test_target = oid()

app_dep = dependency(core_target, "SSATCore")
test_dep = dependency(core_target, "SSATCore")

add(core_target,
    f'isa = PBXNativeTarget; buildConfigurationList = {core_list}; '
    f'buildPhases = ({core_sources}, {core_frameworks}); buildRules = (); '
    f'dependencies = (); name = SSATCore; productName = SSATCore; '
    f'productReference = {core_product}; productType = "com.apple.product-type.library.static";')

add(app_target,
    f'isa = PBXNativeTarget; buildConfigurationList = {app_list}; '
    f'buildPhases = ({app_sources}, {app_frameworks}, {app_resources}); buildRules = (); '
    f'dependencies = ({app_dep}); name = SSATPrep; productName = SSATPrep; '
    f'productReference = {app_product}; productType = "com.apple.product-type.application";')

add(test_target,
    f'isa = PBXNativeTarget; buildConfigurationList = {test_list}; '
    f'buildPhases = ({test_sources}, {test_frameworks}); buildRules = (); '
    f'dependencies = ({test_dep}); name = SSATCoreTests; productName = SSATCoreTests; '
    f'productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')

# ---- project ---------------------------------------------------------------
add(project_id,
    f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2600; '
    f'TargetAttributes = {{ {core_target} = {{CreatedOnToolsVersion = 26.0;}}; '
    f'{app_target} = {{CreatedOnToolsVersion = 26.0;}}; '
    f'{test_target} = {{CreatedOnToolsVersion = 26.0;}}; }}; }}; '
    f'buildConfigurationList = {proj_list}; compatibilityVersion = "Xcode 14.0"; '
    f'developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); '
    f'mainGroup = {main_group}; productRefGroup = {products_group}; '
    f'projectDirPath = ""; projectRoot = ""; '
    f'targets = ({app_target}, {core_target}, {test_target});')

# ---- emit pbxproj ----------------------------------------------------------
PROJECT.mkdir(parents=True, exist_ok=True)
objects.sort()
pbx = ("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n"
       "\tobjectVersion = 56;\n\tobjects = {\n"
       + "\n".join(objects)
       + f"\n\t}};\n\trootObject = {project_id};\n}}\n")
(PROJECT / "project.pbxproj").write_text(pbx)

# ---- workspace so it opens by double-click ---------------------------------
ws = PROJECT / "project.xcworkspace"
ws.mkdir(parents=True, exist_ok=True)
(ws / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<Workspace version = "1.0">\n'
    '   <FileRef location = "self:">\n'
    '   </FileRef>\n'
    '</Workspace>\n')

# ---- shared scheme: build+run app, test the unit bundle --------------------
schemes = PROJECT / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
(schemes / "SSATPrep.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "SSATPrep.app"
               BlueprintName = "SSATPrep"
               ReferencedContainer = "container:SSATPrep.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "SSATCoreTests.xctest"
               BlueprintName = "SSATCoreTests"
               ReferencedContainer = "container:SSATPrep.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "SSATPrep.app"
            BlueprintName = "SSATPrep"
            ReferencedContainer = "container:SSATPrep.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "SSATPrep.app"
            BlueprintName = "SSATPrep"
            ReferencedContainer = "container:SSATPrep.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
''')

print(f"Generated {PROJECT}")
print(f"  SSATCore: {len(core_files)} files, SSATPrep: {len(app_files)} files, Tests: {len(test_files)} files")
