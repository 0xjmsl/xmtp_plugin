Pod::Spec.new do |s|
  s.name             = 'xmtp_plugin'
  s.version          = '1.0.0'
  s.summary          = 'XMTP messaging plugin for Flutter'
  s.description      = <<-DESC
  A Flutter plugin providing XMTP decentralized messaging across Android, iOS, macOS, Windows, and Web.
                       DESC
  s.homepage         = 'https://github.com/0xjmsl/xmtp_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '0xjmsl' => 'jmsl@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'XMTP', '~> 4.0'
  s.platform = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
