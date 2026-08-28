#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pitch_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pitch_kit'
  s.version          = '0.0.1'
  s.summary          = 'Real-time guitar, ukulele, and bass tuning and chord detection.'
  s.description      = <<-DESC
A Flutter package for real-time note and chord detection from the device
microphone, with a pure Dart DSP core.
                       DESC
  s.homepage         = 'https://github.com/NicosNicolaou16/pitch_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'pitch_kit/Sources/pitch_kit/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'pitch_kit_privacy' => ['pitch_kit/Sources/pitch_kit/PrivacyInfo.xcprivacy']}
end
