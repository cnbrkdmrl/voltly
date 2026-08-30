require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'Voltly.xcodeproj')

FileUtils.rm_rf(PROJECT_PATH) if File.exist?(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

project.root_object.attributes['LastSwiftUpdateCheck'] = '1600'
project.root_object.attributes['LastUpgradeCheck'] = '1600'
development_team = ENV['DEVELOPMENT_TEAM']&.strip

def add_swift_package_product_dependency(project:, target:, package_ref:, product_name:)
  product_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.package = package_ref
  product_dependency.product_name = product_name
  target.package_product_dependencies << product_dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency
  target.frameworks_build_phase.files << build_file
end

sources_group = project.main_group.new_group('Sources', 'Sources')
ios_app_group = project.main_group.new_group('iOSApp', 'iOSApp')
widget_group = project.main_group.new_group('WidgetExtension', 'WidgetExtension')
resources_group = project.main_group.new_group('Resources', 'Resources')

voltly_kit = project.new_target(:framework, 'VoltlyKit', :ios, '17.0')
voltly_app = project.new_target(:application, 'VoltlyiOS', :ios, '17.0')
voltly_widget = project.new_target(:app_extension, 'VoltlyWidgetsExtension', :ios, '17.0')

firebase_package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
firebase_package.repositoryURL = 'https://github.com/firebase/firebase-ios-sdk.git'
firebase_package.requirement = {
  'kind' => 'upToNextMajorVersion',
  'minimumVersion' => '11.0.0'
}
project.root_object.package_references << firebase_package

[voltly_kit, voltly_app, voltly_widget].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '5.10'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['MARKETING_VERSION'] = '1.0'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  end
end

voltly_kit.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.voltly.kit'
  config.build_settings['DEFINES_MODULE'] = 'YES'
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) VOLTLY_ENABLE_SWIFTDATA'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VoltlyKit'
end

voltly_app.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.voltly.app'
  config.build_settings['PRODUCT_NAME'] = 'Voltly'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'iOSApp/VoltlyiOS.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Development'
  config.build_settings['CODE_SIGNING_ALLOWED[sdk=iphoneos*]'] = 'YES'
  config.build_settings['CODE_SIGNING_REQUIRED[sdk=iphoneos*]'] = 'YES'
  if development_team && !development_team.empty?
    config.build_settings['DEVELOPMENT_TEAM'] = development_team
  end
  if config.name == 'Debug'
    config.build_settings['CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]'] = 'NO'
    config.build_settings['CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]'] = 'NO'
  end
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Voltly'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
end

voltly_widget.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.voltly.app.widget'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = ''
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'WidgetExtension/VoltlyWidgetsExtension.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Development'
  config.build_settings['CODE_SIGNING_ALLOWED[sdk=iphoneos*]'] = 'YES'
  config.build_settings['CODE_SIGNING_REQUIRED[sdk=iphoneos*]'] = 'YES'
  if development_team && !development_team.empty?
    config.build_settings['DEVELOPMENT_TEAM'] = development_team
  end
  if config.name == 'Debug'
    config.build_settings['CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]'] = 'NO'
    config.build_settings['CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]'] = 'NO'
  end
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'WidgetExtension/Info.plist'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

# Add VoltlyKit sources
Dir.glob(File.join(ROOT, 'Sources/Voltly/**/*.swift')).sort.each do |file|
  relative = file.sub("#{ROOT}/", '')
  parent_rel = File.dirname(relative)
  group = sources_group.find_subpath(parent_rel.sub('Sources/', ''), true)
  # Keep paths rooted at project root so nested groups don't duplicate/strip segments.
  file_ref = group.new_file(relative)
  file_ref.source_tree = 'SOURCE_ROOT'
  voltly_kit.add_file_references([file_ref])
end

# Add VoltlyKit resources
Dir.glob(File.join(ROOT, 'Sources/Voltly/Resources/**/*')).sort.each do |file|
  next unless File.file?(file)

  relative = file.sub("#{ROOT}/", '')
  parent_rel = File.dirname(relative)
  group = sources_group.find_subpath(parent_rel.sub('Sources/', ''), true)
  file_ref = group.new_file(relative)
  file_ref.source_tree = 'SOURCE_ROOT'
  voltly_kit.resources_build_phase.add_file_reference(file_ref, true)
end

# Add app sources
Dir.glob(File.join(ROOT, 'iOSApp/**/*.swift')).sort.each do |file|
  relative = file.sub("#{ROOT}/", '')
  parent_rel = File.dirname(relative)
  group = ios_app_group.find_subpath(parent_rel.sub('iOSApp/', ''), true)
  file_ref = group.new_file(relative)
  file_ref.source_tree = 'SOURCE_ROOT'
  voltly_app.add_file_references([file_ref])
end

# Add widget sources
Dir.glob(File.join(ROOT, 'WidgetExtension/**/*.swift')).sort.each do |file|
  relative = file.sub("#{ROOT}/", '')
  parent_rel = File.dirname(relative)
  group = widget_group.find_subpath(parent_rel.sub('WidgetExtension/', ''), true)
  file_ref = group.new_file(relative)
  file_ref.source_tree = 'SOURCE_ROOT'
  voltly_widget.add_file_references([file_ref])
end

# Add resources to app
assets_ref = resources_group.new_file('Assets.xcassets')
localizable_ref = resources_group.new_file('Localizable')
voltly_app.resources_build_phase.add_file_reference(assets_ref, true)
voltly_app.resources_build_phase.add_file_reference(localizable_ref, true)

# Target dependencies and linkage
voltly_app.add_dependency(voltly_kit)
voltly_widget.add_dependency(voltly_kit)

voltly_app.frameworks_build_phase.add_file_reference(voltly_kit.product_reference, true)
voltly_widget.frameworks_build_phase.add_file_reference(voltly_kit.product_reference, true)

embed_frameworks_phase = voltly_app.copy_files_build_phases.find { |p| p.name == 'Embed Frameworks' } || voltly_app.new_copy_files_build_phase('Embed Frameworks')
embed_frameworks_phase.dst_subfolder_spec = '10' # Frameworks
embed_frameworks_phase.add_file_reference(voltly_kit.product_reference, true)

embed_extensions_phase = voltly_app.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } || voltly_app.new_copy_files_build_phase('Embed App Extensions')
embed_extensions_phase.dst_subfolder_spec = '13' # PlugIns
embed_extensions_phase.add_file_reference(voltly_widget.product_reference, true)
voltly_app.add_dependency(voltly_widget)

%w[FirebaseCore FirebaseAnalytics FirebaseCrashlytics].each do |product_name|
  add_swift_package_product_dependency(
    project: project,
    target: voltly_kit,
    package_ref: firebase_package,
    product_name: product_name
  )
end

project.recreate_user_schemes
project.save
puts "Generated: #{PROJECT_PATH}"
