#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'audiofileplayer'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for audio playback.'
  s.description      = <<-DESC
A Flutter plugin for audio playback.
                       DESC
  s.homepage         = 'http://example.com'
  s.authors          = 'Daniel Iglesia'
  s.license          = { :file => '../LICENSE' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.requires_arc = true
  s.dependency 'Flutter'

  s.platform = :ios, '10.0'
end

