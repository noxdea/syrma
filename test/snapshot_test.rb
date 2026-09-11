# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class ScreenshotTest < Minitest::Test
  include Syrma::Minitest

  def setup
    @dir = Dir.mktmpdir("syrma-test")
    @environment = ENV.to_h.slice("SYRMA_SNAPSHOT_DIR", "SYRMA_ARTIFACTS", "SYRMA_UPDATE_SNAPSHOTS", "CI")
    ENV["SYRMA_SNAPSHOT_DIR"] = File.join(@dir, "snapshots")
    ENV["SYRMA_ARTIFACTS"] = File.join(@dir, "artifacts")
    ENV.delete("SYRMA_UPDATE_SNAPSHOTS")
    ENV.delete("CI")
    zaniah_session(width: 200, height: 240) { |window| CounterApp.mount(window) }
  end

  def teardown
    %w[SYRMA_SNAPSHOT_DIR SYRMA_ARTIFACTS SYRMA_UPDATE_SNAPSHOTS CI].each do |key|
      @environment.key?(key) ? ENV[key] = @environment[key] : ENV.delete(key)
    end
    FileUtils.remove_entry(@dir) if File.exist?(@dir)
  end

  def golden(name = "counter", extension = "png")
    Dir[File.join(@dir, "snapshots", "**", "#{name}.#{extension}")].first
  end

  def test_create_match_mismatch_and_update
    _output, warning = capture_io { assert_screenshot "counter" }
    assert_match(/created snapshot/, warning)
    assert File.exist?(golden.sub(".png", ".meta.json"))
    assert_screenshot "counter"

    ui.test_id("inc").click
    error = assert_raises(Minitest::Assertion) { assert_screenshot "counter" }
    assert_match(/\d+ differing pixels/, error.message)
    artifacts = Dir[File.join(@dir, "artifacts", "**", "diff.png")].first
    assert artifacts
    assert File.exist?(File.join(File.dirname(artifacts), "expected.png"))
    assert File.exist?(File.join(File.dirname(artifacts), "actual.png"))
    Syrma::Diagnostics.write(ui, File.dirname(artifacts), message: error.message)
    summary = File.read(File.join(File.dirname(artifacts), "summary.md"), encoding: "UTF-8")
    assert_includes summary, "[diff.png](diff.png)"

    ENV["SYRMA_UPDATE_SNAPSHOTS"] = "1"
    capture_io { assert_screenshot "counter" }
    ENV.delete("SYRMA_UPDATE_SNAPSHOTS")
    assert_screenshot "counter"
  end

  def test_region_and_mask
    bounds = ui.test_id("inc").resolve.bounds
    assert_screenshot "region", region: ui.test_id("inc")
    width, height, = Zaniah::PNG.decode(File.binread(golden("region")))
    assert_equal [bounds.right.ceil - bounds.x.floor, bounds.bottom.ceil - bounds.y.floor], [width, height]
    assert_screenshot "masked", mask: [ui.test_id("label")]
    ui.test_id("inc").click
    assert_screenshot "masked", mask: [ui.test_id("label")]
  end

  def test_missing_golden_fails_on_ci_and_names_are_safe
    ENV["CI"] = "true"
    error = assert_raises(Minitest::Assertion) { assert_screenshot "missing" }
    assert_match(/Snapshot not found/, error.message)
    assert_raises(ArgumentError) { assert_screenshot "../escape" }
  end

  def test_tree_and_terminal_snapshots
    assert_tree_snapshot "tree"
    assert File.exist?(golden("tree", "tree.txt"))
    assert_tree_snapshot "tree"
    ui.test_id("inc").click
    assert_raises(Minitest::Assertion) { assert_tree_snapshot "tree" }
    ENV["SYRMA_UPDATE_SNAPSHOTS"] = "1"
    assert_tree_snapshot "tree"
    ENV.delete("SYRMA_UPDATE_SNAPSHOTS")
    assert_tree_snapshot "tree"

    terminal = zaniah_session(backend: :tui, width: 160, height: 60) do |window|
      window.draw { Zaniah::Text.new("Terminal") }
    end
    assert_terminal_snapshot "terminal", session: terminal
    assert File.exist?(golden("terminal", "term.txt"))
    terminal.window.draw { Zaniah::Text.new("Changed") }
    terminal.window.request_frame
    assert_raises(Minitest::Assertion) { assert_terminal_snapshot "terminal", session: terminal }
    ENV["SYRMA_UPDATE_SNAPSHOTS"] = "1"
    assert_terminal_snapshot "terminal", session: terminal
  ensure
    ENV.delete("SYRMA_UPDATE_SNAPSHOTS")
  end
end

class VisualImageTest < Minitest::Test
  def test_crop_clamps_and_mask_fills
    pixels = (0...4 * 3).flat_map { |value| [value, value, value, 255] }.pack("C*")
    width, height, cropped = Syrma::Visual::Image.crop(pixels, 4, 3, Zaniah::Bounds.new(-2, 1, 5, 3))
    assert_equal [3, 2, 24], [width, height, cropped.bytesize]
    Syrma::Visual::Image.mask!(pixels, 4, 3, Zaniah::Bounds.new(1, 1, 2, 1))
    assert_equal [255, 0, 255, 255], pixels.byteslice((1 * 4 + 1) * 4, 4).bytes
  end
end

class DiagnosticsTest < Minitest::Test
  def test_failed_test_writes_artifacts
    Dir.mktmpdir("syrma-diagnostics") do |dir|
      script = File.join(dir, "failing_test.rb")
      File.write(script, <<~RUBY, encoding: "UTF-8")
        require_relative #{File.expand_path("test_helper", __dir__).dump}
        class FailingUiTest < Minitest::Test
          include Syrma::Minitest
          def test_boom
            zaniah_session(width: 160, height: 100, timeout: 0.03) { |window| CounterApp.mount(window) }
            ui.test_id("inc").click
            assert_ui_text "Count: 99"
          end
        end
      RUBY
      env = {
        "SYRMA_ARTIFACTS" => File.join(dir, "out"),
        "RUBYLIB" => [File.expand_path("../lib", __dir__), ENV["RUBYLIB"]].compact.join(File::PATH_SEPARATOR)
      }
      output = IO.popen(env, [RbConfig.ruby, script], err: [:child, :out], external_encoding: "UTF-8", &:read)
      assert_match(/1 failures/, output)
      artifact_dir = File.join(dir, "out", "FailingUiTest", "test_boom")
      %w[screenshot.png tree.txt hits.txt text_runs.txt events.log summary.md].each do |file|
        assert File.exist?(File.join(artifact_dir, file)), "#{file} is missing"
      end
      assert_match(/div @inc/, File.read(File.join(artifact_dir, "tree.txt"), encoding: "UTF-8"))
      assert_match(/MouseDown/, File.read(File.join(artifact_dir, "events.log"), encoding: "UTF-8"))
      assert_match(/Count: 99/, File.read(File.join(artifact_dir, "summary.md"), encoding: "UTF-8"))
    end
  end
end
