require "open3"

module WatchReleaseGuard
  WATCH_INFO_PATH = %r{\APayload/[^/]+\.app/Watch/[^/]+\.app/Info\.plist\z}

  def self.ipa_contains_watch_app?(ipa)
    return false unless ipa && File.file?(ipa)

    listing, status = Open3.capture2e("unzip", "-Z1", ipa)
    status.success? && listing.lines.any? { |path| WATCH_INFO_PATH.match?(path.strip) }
  end

  # For a build already on App Store Connect there is no IPA to inspect, and
  # ASC's build_bundles omits the nested Watch app. The dSYMs the build job
  # kept (artifact ios-dsyms-<version>-<build>) are from that exact archive: a
  # watchOS app binary among them proves the Watch app was built into it.
  def self.dsyms_contain_watch_app?(dir)
    return false unless dir && !dir.empty? && File.directory?(dir)

    Dir.glob(File.join(dir, "*.app.dSYM", "Contents", "Resources", "DWARF", "*")).any? do |binary|
      out, status = Open3.capture2e("xcrun", "vtool", "-show-build", binary)
      status.success? && out.match?(/platform WATCHOS/)
    end
  end

  def self.build_contains_watch_app?(build, watch_bundle_id)
    build && build.processing_state == "VALID" &&
      Array(build.build_bundles).any? { |bundle| bundle.bundle_id == watch_bundle_id }
  end
end
