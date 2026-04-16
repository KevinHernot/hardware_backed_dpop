#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hardware_backed_dpop.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hardware_backed_dpop'
  s.version          = '0.1.0'
  s.summary          = 'Hardware-backed DPoP binding and proof-signing for Flutter.'
  s.description      = <<-DESC
Hardware-backed DPoP binding and proof-signing primitives for Flutter.
                       DESC
  s.homepage         = 'https://github.com/KevinHernot/hardware_backed_dpop'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Kevin Hernot'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
