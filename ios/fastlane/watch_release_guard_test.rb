require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "ostruct"
require_relative "watch_release_guard"

class WatchReleaseGuardTest < Minitest::Test
  def ipa_with(path)
    Dir.mktmpdir("watch-release-guard-") do |dir|
      FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
      File.write(File.join(dir, path), "fixture")
      ipa = File.join(dir, "fixture.ipa")
      _, status = Open3.capture2e("zip", "-qr", ipa, "Payload", chdir: dir)
      assert status.success?
      yield ipa
    end
  end

  def test_accepts_embedded_watch_app
    ipa_with("Payload/Medito.app/Watch/MeditoWatch.app/Info.plist") do |ipa|
      assert WatchReleaseGuard.ipa_contains_watch_app?(ipa)
    end
  end

  def test_rejects_phone_only_ipa
    ipa_with("Payload/Medito.app/Info.plist") do |ipa|
      refute WatchReleaseGuard.ipa_contains_watch_app?(ipa)
    end
  end

  def test_rejects_watch_name_outside_embedded_watch_folder
    ipa_with("Payload/Medito.app/Resources/MeditoWatch.app/Info.plist") do |ipa|
      refute WatchReleaseGuard.ipa_contains_watch_app?(ipa)
    end
  end

  def test_rejects_missing_or_corrupt_ipa
    refute WatchReleaseGuard.ipa_contains_watch_app?(nil)
    refute WatchReleaseGuard.ipa_contains_watch_app?("/missing/medito.ipa")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bad.ipa")
      File.write(path, "not an archive")
      refute WatchReleaseGuard.ipa_contains_watch_app?(path)
    end
  end

  def test_dsyms_without_a_watch_app_are_rejected
    refute WatchReleaseGuard.dsyms_contain_watch_app?(nil)
    refute WatchReleaseGuard.dsyms_contain_watch_app?("")
    refute WatchReleaseGuard.dsyms_contain_watch_app?("/missing/dsyms")
    Dir.mktmpdir do |dir|
      refute WatchReleaseGuard.dsyms_contain_watch_app?(dir)
      dwarf = File.join(dir, "MeditoWatch.app.dSYM", "Contents", "Resources", "DWARF")
      FileUtils.mkdir_p(dwarf)
      File.write(File.join(dwarf, "MeditoWatch"), "not a Mach-O")
      refute WatchReleaseGuard.dsyms_contain_watch_app?(dir)
    end
  end

  def test_existing_build_must_be_processed_and_include_the_exact_watch_bundle
    watch = OpenStruct.new(bundle_id: "org.meditofoundation.watchkitapp")
    build = OpenStruct.new(processing_state: "VALID", build_bundles: [watch])
    assert WatchReleaseGuard.build_contains_watch_app?(build, watch.bundle_id)
    refute WatchReleaseGuard.build_contains_watch_app?(build, "other.watchkitapp")
    build.processing_state = "PROCESSING"
    refute WatchReleaseGuard.build_contains_watch_app?(build, watch.bundle_id)
    build.processing_state = "VALID"
    build.build_bundles = nil
    refute WatchReleaseGuard.build_contains_watch_app?(build, watch.bundle_id)
    refute WatchReleaseGuard.build_contains_watch_app?(nil, watch.bundle_id)
  end
end
