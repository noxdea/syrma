<h1 align="center">Syrma</h1>

<p align="center">
  <strong>Drive and assert <a href="https://github.com/noxdea/zaniah">Zaniah</a> GUI and TUI applications from Ruby tests.</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/syrma"><img src="https://img.shields.io/gem/v/syrma.svg" alt="Gem version"></a>
  <a href="https://github.com/noxdea/syrma/actions/workflows/main.yml"><img src="https://github.com/noxdea/syrma/actions/workflows/main.yml/badge.svg" alt="CI"></a>
  <a href="https://www.ruby-lang.org/"><img src="https://img.shields.io/badge/ruby-3.1%2B-CC342D.svg" alt="Ruby 3.1+"></a>
  <a href="LICENSE.txt"><img src="https://img.shields.io/github/license/noxdea/syrma.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="https://noxdea.github.io/syrma/">Website</a> ·
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="#snapshots-and-diagnostics">Snapshots</a> ·
  <a href="#documentation">Documentation</a>
</p>

---

Syrma locates rendered elements, sends input through Zaniah's real event path, waits for redraws, and compares the observable result. Tests can inspect text, element trees, terminal output, pixels, screenshots, menus, and tooltips without bypassing application input handling.

## Features

- Drive GUI and TUI sessions with pointer, keyboard, clipboard, composition, file-drop, resize, and terminal input
- Locate elements by text, test ID, actionability, or nested queries resolved against the latest frame
- Assert semantic output first, with tree, terminal, pixel, and screenshot snapshots when needed
- Keep timing deterministic with a session-scoped virtual clock and explicit frame settling
- Test with Minitest assertions or RSpec matchers
- Capture screenshots, hit regions, text runs, and recent events when a test fails
- Record deterministic APNG/GIF frames and asciinema events from the virtual clock

## Installation

Add Syrma and your test framework to the test group in your `Gemfile`:

```ruby
group :test do
  gem "minitest", "~> 5.0"
  gem "syrma"
end
```

Then install the bundle and verify the test environment:

```sh
bundle install
bundle exec syrma doctor
```

Syrma requires Ruby 3.1 or later and supports Zaniah `>= 0.2, < 0.6`. RSpec users can replace Minitest with RSpec in the test group.

### Demo recording

Install `wezen` alongside Syrma to export a virtual-clock recording:

```ruby
result = session.record(fps: 12, seed: 42) do |recording|
  recording.cursor
  recording.caption("Open the file")
  recording.type_humanly("README.md")
  recording.pause(1.0)
end
result.write_apng("docs/media/overview.apng")
```

Recordings require a virtual clock and headless session for repeatable pixels.
Use `session.record_cast` with a TUI session for asciinema v2 output.

## Quick start

Keep window creation separate from the code that mounts the interface:

```ruby
module Counter
  def self.mount(window)
    count = 0
    window.draw do
      Zaniah::Div.new
        .child(Zaniah::Text.new("Count: #{count}"))
        .child(Zaniah::Div.new.test_id("increment").on_click { count += 1 })
    end
  end
end
```

### Minitest

```ruby
require "syrma/minitest"

class CounterTest < Minitest::Test
  include Syrma::Minitest

  def setup
    zaniah_session(width: 320, height: 200) { |window| Counter.mount(window) }
  end

  def test_increment
    ui.test_id("increment").click
    assert_ui_text "Count: 1"
  end
end
```

### RSpec

```ruby
require "syrma/rspec"

RSpec.describe "Counter", type: :zaniah do
  before { zaniah_session(width: 320, height: 200) { |window| Counter.mount(window) } }

  it "increments the count" do
    ui.test_id("increment").click
    expect(ui).to have_ui_text("Count: 1")
  end
end
```

`test_id` is provided by Zaniah 0.2 and is safe to use in application code.

## API at a glance

| Task | API |
| --- | --- |
| Locate | `find`, `all`, `test_id`, `text`, `button`, nested `find`, `nth`, `first`, `last` |
| Pointer | `click`, `double_click`, `right_click`, `hover`, `drag`, `scroll` |
| Keyboard/text | `press`, `type`, `paste`, `compose`, `commit` |
| Window/input | `resize`, `close`, `drop_files`, `feed_terminal` |
| Synchronize | `settle`, `wait_for`, `advance` |
| Inspect | `tree`, `texts`, `at`, `pixel`, `screenshot`, `terminal_lines`, `menu`, `tooltip` |
| Assert | Text, element, visibility, panels, decorations, background, pixel, tooltip, menu, tree/terminal/image snapshots |

Locators are lazy: every operation resolves them against the latest rendered frame. Actions wait for visibility and an unobscured matching event handler, then send events through `Window#input`.

Panel and decoration assertions use rendered `test_id` instrumentation, so application code does not need a Syrma or Canopus runtime dependency:

```ruby
assert_panel_visible :problems
assert_panel_badge :problems, 3
assert_inline_overlay line: 10, text: ": String"
assert_gutter_marker line: 5, kind: :breakpoint
assert_line_highlight line: 12, kind: :debug_position
```

The corresponding IDs are `syrma:panel:problems`, `syrma:panel:problems:badge`, `syrma:decoration:inline:10`, `syrma:decoration:gutter:5:breakpoint`, and `syrma:decoration:line:12:debug_position`. Lines are zero-based. Instrument the element that was actually laid out and painted; assertions require positive visible bounds. RSpec provides the same names with `have_` in place of `assert_`.

## Snapshots and diagnostics

```ruby
assert_tree_snapshot "sidebar"
assert_screenshot "saved", region: ui.test_id("panel"), mask: [ui.test_id("clock")]
assert_terminal_snapshot "main"
```

New goldens are created locally and rejected on CI. Set `SYRMA_UPDATE_SNAPSHOTS=1` to update them. A failed UI test writes its screenshot, element tree, hit regions, text runs, recent events, and summary below `tmp/syrma`.

```sh
bundle exec syrma snapshots update
bundle exec syrma snapshots prune --dry-run
bundle exec syrma report
```

## Determinism and performance

The default text renderer uses only Zaniah's bundled Abel font plus files passed in `fonts:`. Add a repository-owned font for non-Latin screenshot tests. `text: :none` is faster but does not draw glyphs.

On Ruby 4.0 arm64 macOS, the included 101-element benchmark measured `event_frames: :gesture` at 3.1 ms per click/check with `text: :none` and 7.9 ms with deterministic text; Syrma's tree build plus locator resolution was about 0.28 ms. Run `bundle exec ruby -Ilib bench/click_bench.rb gesture` on the target CI host for relevant numbers.

## Documentation

- [Guide](docs/guide.md): application structure, sessions, CI, configuration, and troubleshooting
- [Recipes](docs/recipes.md): interactions, screenshots, TUI sessions, and multiple windows
- [Changelog](CHANGELOG.md): release history

## Development

```sh
bundle install
bundle exec rake
bundle exec ruby -Ilib:test script/test_gesture.rb
bundle exec rbs -I sig validate
gem build --strict syrma.gemspec
```

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/noxdea/syrma).

## License

Syrma is available under the [MIT License](LICENSE.txt).
