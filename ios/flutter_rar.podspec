Pod::Spec.new do |s|
  s.name             = 'flutter_rar'
  s.version          = '0.2.1'
  s.summary          = 'Native UnRAR extraction for Flutter.'
  s.description      = <<-DESC
Extracts RAR archives on iOS with UnrarKit, the official UnRAR library.
                       DESC
  s.homepage         = 'https://github.com/itsdevzam/flutter_rar'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutter_rar' => 'itsdevzam@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_rar/Sources/flutter_rar/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'UnrarKit', '~> 2.9'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
