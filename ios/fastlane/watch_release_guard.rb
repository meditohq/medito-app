require "open3"

module WatchReleaseGuard
  WATCH_INFO_PATH = %r{\APayload/[^/]+\.app/Watch/[^/]+\.app/Info\.plist\z}

  def self.ipa_contains_watch_app?(ipa)
    return false unless ipa && File.file?(ipa)

    listing, status = Open3.capture2e("unzip", "-Z1", ipa)
    status.success? && listing.lines.any? { |path| WATCH_INFO_PATH.match?(path.strip) }
  end

  def self.build_contains_watch_app?(build, watch_bundle_id)
    build && build.processing_state == "VALID" &&
      Array(build.build_bundles).any? { |bundle| bundle.bundle_id == watch_bundle_id }
  end
end
