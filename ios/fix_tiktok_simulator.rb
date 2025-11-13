#!/usr/bin/env ruby
# Script to remove TikTok SDK framework references from Debug xcconfig for simulator compatibility

require 'fileutils'

xcconfig_path = File.join(File.dirname(__FILE__), 'Pods', 'Target Support Files', 'Pods-Runner', 'Pods-Runner.debug.xcconfig')

unless File.exist?(xcconfig_path)
  puts "xcconfig file not found: #{xcconfig_path}"
  exit 0
end

content = File.read(xcconfig_path)
original_content = content.dup
modified = false

# Remove TikTok SDK from FRAMEWORK_SEARCH_PATHS
if content.include?('TikTokBusinessSDK')
  content.gsub!(/ "${PODS_CONFIGURATION_BUILD_DIR}\/TikTokBusinessSDK"/, '')
  content.gsub!(/ "${PODS_CONFIGURATION_BUILD_DIR}\/tiktok_events_sdk"/, '')
  modified = true
end

# Remove TikTok SDK from HEADER_SEARCH_PATHS
if content.include?('TikTokBusinessSDK')
  content.gsub!(/ "${PODS_CONFIGURATION_BUILD_DIR}\/TikTokBusinessSDK\/TikTokBusinessSDK\.framework\/Headers"/, '')
  content.gsub!(/ "${PODS_CONFIGURATION_BUILD_DIR}\/tiktok_events_sdk\/tiktok_events_sdk\.framework\/Headers"/, '')
  modified = true
end

# Remove TikTok SDK frameworks from OTHER_LDFLAGS
if content.include?('-framework "TikTokBusinessSDK"')
  content.gsub!(/ -framework "TikTokBusinessSDK"/, '')
  content.gsub!(/ -framework "tiktok_events_sdk"/, '')
  modified = true
end

# Remove TikTok SDK from OTHER_MODULE_VERIFIER_FLAGS
if content.include?('TikTokBusinessSDK')
  content.gsub!(/ "-F\$\{PODS_CONFIGURATION_BUILD_DIR\}\/TikTokBusinessSDK"/, '')
  content.gsub!(/ "-F\$\{PODS_CONFIGURATION_BUILD_DIR\}\/tiktok_events_sdk"/, '')
  modified = true
end

# Clean up any double spaces
content.gsub!(/\s{2,}/, ' ')

if modified && content != original_content
  File.write(xcconfig_path, content)
  puts "✅ Removed TikTok SDK framework references from Debug xcconfig"
else
  puts "ℹ️  No TikTok SDK framework references found or already removed"
end

