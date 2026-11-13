"""Add a simulator-only UI test target to a temporary CI project copy."""

import plistlib
import subprocess
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
project = root / "MeloX.xcodeproj/project.pbxproj"
with tempfile.TemporaryDirectory() as temp:
    converted = Path(temp) / "project.plist"
    subprocess.run(["plutil", "-convert", "xml1", "-o", str(converted), str(project)], check=True)
    data = plistlib.loads(converted.read_bytes())

objects = data["objects"]
project_id = data["rootObject"]
project_object = objects[project_id]
app_id = next(key for key, value in objects.items() if value.get("isa") == "PBXNativeTarget" and value.get("name") == "MeloX")

ids = {name: f"A11D000000000000000000{index:02X}" for index, name in enumerate(
    ["target", "product", "group", "file", "build_file", "sources", "frameworks", "resources", "config_list", "debug", "release", "dependency", "proxy"], start=1
)}
assert not any(value in objects for value in ids.values())

objects[ids["product"]] = {"isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle", "includeInIndex": "0", "path": "MeloXTabletUITests.xctest", "sourceTree": "BUILT_PRODUCTS_DIR"}
objects[ids["file"]] = {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift", "path": "MeloXTabletUITests.swift", "sourceTree": "<group>"}
objects[ids["group"]] = {"isa": "PBXGroup", "children": [ids["file"]], "path": ".github/ui-tests", "sourceTree": "SOURCE_ROOT"}
objects[project_object["mainGroup"]]["children"].append(ids["group"])
objects[project_object["productRefGroup"]]["children"].append(ids["product"])
objects[ids["build_file"]] = {"isa": "PBXBuildFile", "fileRef": ids["file"]}
objects[ids["sources"]] = {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647", "files": [ids["build_file"]], "runOnlyForDeploymentPostprocessing": "0"}
for name, kind in [("frameworks", "PBXFrameworksBuildPhase"), ("resources", "PBXResourcesBuildPhase")]:
    objects[ids[name]] = {"isa": kind, "buildActionMask": "2147483647", "files": [], "runOnlyForDeploymentPostprocessing": "0"}

settings = {
    "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
    "CODE_SIGNING_ALLOWED": "NO",
    "GENERATE_INFOPLIST_FILE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "local.MeloXTabletUITests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "iphoneos",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "2",
    "TEST_TARGET_NAME": "MeloX",
}
for name in ["debug", "release"]:
    config_settings = dict(settings)
    if name == "debug":
        config_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) DEBUG"
    objects[ids[name]] = {"isa": "XCBuildConfiguration", "buildSettings": config_settings, "name": name.title()}
objects[ids["config_list"]] = {"isa": "XCConfigurationList", "buildConfigurations": [ids["debug"], ids["release"]], "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"}
objects[ids["proxy"]] = {"isa": "PBXContainerItemProxy", "containerPortal": project_id, "proxyType": "1", "remoteGlobalIDString": app_id, "remoteInfo": "MeloX"}
objects[ids["dependency"]] = {"isa": "PBXTargetDependency", "target": app_id, "targetProxy": ids["proxy"]}
objects[ids["target"]] = {
    "isa": "PBXNativeTarget", "name": "MeloXTabletUITests", "productName": "MeloXTabletUITests",
    "productType": "com.apple.product-type.bundle.ui-testing", "productReference": ids["product"],
    "buildConfigurationList": ids["config_list"],
    "buildPhases": [ids["sources"], ids["frameworks"], ids["resources"]],
    "buildRules": [], "dependencies": [ids["dependency"]],
}
project_object["targets"].append(ids["target"])
project_object.setdefault("attributes", {}).setdefault("TargetAttributes", {})[ids["target"]] = {"CreatedOnToolsVersion": "27.1", "TestTargetID": app_id}
project.write_bytes(plistlib.dumps(data, sort_keys=False))

scheme_path = root / "MeloX.xcodeproj/xcshareddata/xcschemes/MeloX.xcscheme"
scheme = ET.parse(scheme_path)
test_action = scheme.getroot().find("TestAction")
testables = ET.SubElement(test_action, "Testables")
testable = ET.SubElement(testables, "TestableReference", skipped="NO")
ET.SubElement(testable, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=ids["target"], BuildableName="MeloXTabletUITests.xctest", BlueprintName="MeloXTabletUITests", ReferencedContainer="container:MeloX.xcodeproj")
entries = scheme.getroot().find("BuildAction/BuildActionEntries")
entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="NO", buildForProfiling="NO", buildForArchiving="NO", buildForAnalyzing="NO")
ET.SubElement(entry, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=ids["target"], BuildableName="MeloXTabletUITests.xctest", BlueprintName="MeloXTabletUITests", ReferencedContainer="container:MeloX.xcodeproj")
ET.indent(scheme, space="   ")
scheme.write(scheme_path, encoding="utf-8", xml_declaration=True)
print("Prepared simulator-only MeloXTabletUITests target.")
