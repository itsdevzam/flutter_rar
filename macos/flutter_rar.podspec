Pod::Spec.new do |s|
  s.name             = 'flutter_rar'
  s.version          = '0.2.1'
  s.summary          = 'Native UnRAR extraction for Flutter.'
  s.description      = <<-DESC
Extracts RAR archives with the official UnRAR library.
                       DESC
  s.homepage         = 'https://github.com/itsdevzam/flutter_rar'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BookNest' => 'dev@booknest.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.exclude_files    = [
    'Classes/unrar/arccmt.cpp',
    'Classes/unrar/blake2s_sse.cpp',
    'Classes/unrar/blake2sp.cpp',
    'Classes/unrar/cmdfilter.cpp',
    'Classes/unrar/cmdmix.cpp',
    'Classes/unrar/coder.cpp',
    'Classes/unrar/crypt1.cpp',
    'Classes/unrar/crypt2.cpp',
    'Classes/unrar/crypt3.cpp',
    'Classes/unrar/crypt5.cpp',
    'Classes/unrar/hardlinks.cpp',
    'Classes/unrar/log.cpp',
    'Classes/unrar/model.cpp',
    'Classes/unrar/recvol3.cpp',
    'Classes/unrar/recvol5.cpp',
    'Classes/unrar/suballoc.cpp',
    'Classes/unrar/threadmisc.cpp',
    'Classes/unrar/uicommon.cpp',
    'Classes/unrar/uiconsole.cpp',
    'Classes/unrar/uisilent.cpp',
    'Classes/unrar/ulinks.cpp',
    'Classes/unrar/unpack15.cpp',
    'Classes/unrar/unpack20.cpp',
    'Classes/unrar/unpack30.cpp',
    'Classes/unrar/unpack50.cpp',
    'Classes/unrar/unpack50frag.cpp',
    'Classes/unrar/unpack50mt.cpp',
    'Classes/unrar/unpackinline.cpp',
    'Classes/unrar/uowners.cpp',
    'Classes/unrar/win32acl.cpp',
    'Classes/unrar/win32lnk.cpp',
    'Classes/unrar/win32stm.cpp',
  ]
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES',
    'GCC_ENABLE_CPP_RTTI' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes/unrar" "$(PODS_TARGET_SRCROOT)/../src"',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -O2 -DRARDLL -DSILENT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fexceptions -frtti -fvisibility=hidden',
    'GCC_OPTIMIZATION_LEVEL' => '2',
  }
  s.swift_version = '5.0'
end
