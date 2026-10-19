#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint my_printers_brother.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'my_printers_brother'
  s.version          = '3.0.0'
  s.summary          = 'A flutter plugin project for printing using the Brother printers.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/Blackheart8788/my_printers_brother'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rounin Labs' => 'hernandez.f@rouninlabs.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'#, 'Classes/PtouchPrinterKit-Bridging-Header.h'

  
  #s.preserve_paths = 'Lib/BRLMPrinterKit.framework'
  #s.xcconfig = { 'OTHER_LDFLAGS' => '-framework BRLMPrinterKit.framework' }
  #s.ios.vendored_frameworks = 'Lib/BRLMPrinterKit.framework'
  #s.vendored_frameworks = 'BRLMPrinterKit.framework'
    
  #s.ios.vendored_frameworks = 'Lib/BRPtouchPrinterKit.framework'
  #s.vendored_frameworks = 'BRPtouchPrinterKit.framework'
  
  #s.dependency 'BRLMPrinterKit'
  # Brother Print SDK 4.13.2 (Bluetooth + network build), vendored from Brother's SDK package.
  s.vendored_frameworks = 'Frameworks/BRLMPrinterKit.xcframework'
  s.dependency 'BROTHERSDK'
  
  #s.dependency 'BRLMPrinterKitBind'
  
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # CocoaPods does not link the BROTHERSDK static library into this framework, so link it
    # explicitly. It only has device slices, so TypeB printing is unavailable on the simulator.
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/BROTHERSDK"',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -ObjC -l"BROTHERSDK"'
  }
  s.swift_version = '5.0'
  
  #s.subspec 'BRLMPrinterKit' do |br|
  #  br.source_files = 'Lib/BRLMPrinterKit.framework/**/*'
  #  br.public_header_files = 'Lib/BRLMPrinterKit.framework/**/*.h'
  #end
  
  #s.subspec 'BRLMPrinterKitBind' do |brBind|
  #  brBind.public_header_files = 'Classes/PtouchPrinterKit-Bridging-Header.h'
  #  brBind.dependency 'BRLMPrinterKit'
  #end

  
end
