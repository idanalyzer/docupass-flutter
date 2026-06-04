Pod::Spec.new do |s|
  s.name             = 'docupass_flutter'
  s.version          = '0.1.1'
  s.summary          = 'Native in-app ID verification & KYC for Flutter (ID Analyzer DocuPass).'
  s.description      = 'Embeds the native iOS DocuPass SDK (AVFoundation + MediaPipe liveness) as a Flutter platform view. No WebView.'
  s.homepage         = 'https://github.com/idanalyzer/docupass-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'ID Analyzer' => 'support@idanalyzer.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'

  s.dependency 'Flutter'
  # The native iOS DocuPass core (wraps MediaPipeTasksVision).
  s.dependency 'DocuPass', '~> 0.1'
end
