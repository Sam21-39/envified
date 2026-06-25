Pod::Spec.new do |s|
  s.name             = 'envified'
  s.version          = '4.0.0-alpha.1'
  s.summary          = 'Runtime environment switching for Flutter with native AES-256-GCM security.'
  s.description      = <<-DESC
    Envified v4: hardware-backed secrets (iOS Secure Enclave / Android Keystore),
    zero Flutter-asset-bundle exposure, adapter-aware environment switching.
  DESC
  s.homepage         = 'https://github.com/Sam21-39/envified'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Appamania' => 'dev@appamania.in' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
