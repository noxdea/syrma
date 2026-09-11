# frozen_string_literal: true

require_relative "test_helper"
require "syrma/cli"
require "syrma/rake_task"
require "tmpdir"

class EventCodecTest < Minitest::Test
  EVENTS = [
    Zaniah::Input::MouseDown.new(Zaniah::Point.new(1, 2), :left, ["shift"], 1),
    Zaniah::Input::MouseUp.new(Zaniah::Point.new(1, 2), :left, []),
    Zaniah::Input::MouseMove.new(Zaniah::Point.new(3, 4), []),
    Zaniah::Input::ScrollWheel.new(Zaniah::Point.new(1, 2), Zaniah::Point.new(0, 10), nil, []),
    Zaniah::Input::KeyDown.new("ctrl-s", false),
    Zaniah::Input::KeyUp.new("ctrl-s"),
    Zaniah::Input::TextInput.new("text"),
    Zaniah::Input::Composition.new("hel", [0, 3]),
    Zaniah::Input::FileDrop.new(["a.txt"], Zaniah::Point.new(5, 6))
  ].freeze

  def test_all_supported_events_round_trip
    EVENTS.each do |event|
      assert_equal event, Syrma::EventCodec.load(Syrma::EventCodec.dump(event, t: 1.25))
    end
  end

  def test_unknown_events_and_invalid_json_are_rejected
    assert_raises(ArgumentError) { Syrma::EventCodec.dump(Object.new, t: 0) }
    assert_raises(ArgumentError) { Syrma::EventCodec.load('{"type":"Object","fields":{}}') }
    assert_raises(ArgumentError) { Syrma::EventCodec.load("not json") }
  end
end

class RecorderAndCodegenTest < Minitest::Test
  def test_records_target_and_generates_compact_operations
    session = Syrma::Session.new(width: 200, height: 100, text: :none) { |window| CounterApp.mount(window) }
    output = StringIO.new
    recorder = Syrma::Recorder.new(session.driver, output)
    session.test_id("inc").click
    session.type("ab")
    recorder.close
    lines = output.string.lines
    mouse = lines.map { |line| JSON.parse(line) }.find { |record| record["type"] == "MouseDown" }
    assert_equal "inc", mouse.dig("target", "test_id")
    generated = Syrma::Codegen.generate(lines)
    assert_includes generated, 'ui.find(test_id: "inc").click'
    assert_includes generated, 'ui.type("ab")'
    refute_includes generated, 'ui.press("a")'
  ensure
    recorder&.close
    session&.close
  end
end

class ScriptLauncherTest < Minitest::Test
  def test_launches_an_unmodified_run_script_and_finishes_cleanup
    $syrma_legacy_after_run = false
    path = File.expand_path("fixtures/scripts/legacy_app.rb", __dir__)
    session = Syrma::Session.launch_script(path, text: :none)
    session.test_id("legacy").click
    assert_includes session.texts, "Count: 1"
    refute $syrma_legacy_after_run
    session.close
    assert $syrma_legacy_after_run
    assert_equal 0, session.exit_status
  ensure
    session&.close
  end
end

class CliTest < Minitest::Test
  def test_doctor_and_help
    out = StringIO.new
    assert_equal 0, Syrma::CLI.run(["doctor"], out: out, err: StringIO.new)
    assert_includes out.string, "zaniah"
    assert_equal 0, Syrma::CLI.run(["help"], out: out, err: StringIO.new)
  end

  def test_prune_and_report
    Dir.mktmpdir("syrma-cli") do |dir|
      with_paths(dir) do
        store = Syrma::Snapshots::Store.new
        store.reset_usage!(full: true)
        used = store.path(test_file: "a_test.rb", test_class: "A", name: "used", ext: "tree.txt")
        unused = File.join(store.root, "a_test", "A", "unused.tree.txt")
        store.write(used, "used")
        store.write(unused, "unused")
        out = StringIO.new
        assert_equal 0, Syrma::CLI.run(%w[snapshots prune --dry-run], out: out, err: StringIO.new)
        assert File.exist?(unused)
        assert_includes out.string, "unused.tree.txt"
        assert_equal 0, Syrma::CLI.run(%w[snapshots prune], out: StringIO.new, err: StringIO.new)
        refute File.exist?(unused)

        artifact = File.join(dir, "artifacts", "Example", "failure")
        FileUtils.mkdir_p(artifact)
        File.write(File.join(artifact, "summary.md"), "failure <unsafe>", encoding: "UTF-8")
        path = Syrma::Report.generate
        html = File.read(path, encoding: "UTF-8")
        assert_includes html, "failure &lt;unsafe&gt;"

        second = File.join(dir, "artifacts", "Example", "other")
        FileUtils.mkdir_p(second)
        File.write(File.join(second, "summary.md"), "second", encoding: "UTF-8")
        assert_includes File.read(Syrma::Report.generate, encoding: "UTF-8"), "second"
      end
    end
  end

  def test_empty_report
    Dir.mktmpdir("syrma-empty-report") do |dir|
      path = Syrma::Report.generate(root: dir)
      assert_includes File.read(path, encoding: "UTF-8"), "No failures recorded"
    end
  end

  def test_rake_tasks_are_defined
    Syrma::RakeTask.new
    %w[syrma:doctor syrma:snapshots:update syrma:snapshots:prune syrma:report].each do |name|
      assert Rake::Task.task_defined?(name), name
    end
  end

  private

  def with_paths(dir)
    keys = %w[SYRMA_SNAPSHOT_DIR SYRMA_ARTIFACTS]
    old = ENV.to_h.slice(*keys)
    ENV["SYRMA_SNAPSHOT_DIR"] = File.join(dir, "snapshots")
    ENV["SYRMA_ARTIFACTS"] = File.join(dir, "artifacts")
    yield
  ensure
    keys.each { |key| old.key?(key) ? ENV[key] = old[key] : ENV.delete(key) }
  end
end
