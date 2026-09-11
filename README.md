# Syrma

Syrma drives [Zaniah](https://github.com/noxdea/zaniah) GUI and TUI applications from Ruby tests. It locates rendered elements, sends input through Zaniah's real event path, waits for redraws, and compares text, trees, terminal output, pixels, and screenshots.

## Installation

Add Syrma to the test group in your `Gemfile`:

```ruby
group :test do
  gem "minitest", "~> 5.0"
  gem "syrma"
end
```

Then run `bundle install` and `bundle exec syrma doctor`.

## Minimal test

Keep window creation separate from the code that mounts your UI:

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

```ruby
require "syrma/minitest"

class CounterTest < Minitest::Test
  include Syrma::Minitest

  def setup
    zaniah_session(width: 320, height: 200) { |window| Counter.mount(window) }
  end

  def test_increment
    ui.find(test_id: "increment").click
    assert_ui_text "Count: 1"
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
| Assert | text, element, visibility, clickability, background, pixel, tooltip, menu, tree/terminal/image snapshots |

Locators are lazy: every operation resolves them against the latest rendered frame. Actions wait for visibility and an unobscured matching event handler, then send events through `Window#input`.

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

## Determinism and speed

The default text renderer uses only Zaniah's bundled Abel font plus files passed in `fonts:`. Add a repository-owned font for non-Latin screenshot tests. `text: :none` is faster but does not draw glyphs.

On Ruby 4.0 arm64 macOS, the included 101-element benchmark measured `event_frames: :gesture` at 3.1 ms per click/check with `text: :none` and 7.9 ms with deterministic text; Syrma's tree build plus locator resolution was about 0.28 ms. Run `bundle exec ruby -Ilib bench/click_bench.rb gesture` on the target CI host for relevant numbers.

See [the guide](docs/guide.md) and [recipes](docs/recipes.md) for the full workflow.

## Development

```sh
bundle exec rake
bundle exec ruby -Ilib:test script/test_gesture.rb
bundle exec rbs -I sig validate
gem build --strict syrma.gemspec
```

Syrma supports Ruby 3.1+ and Zaniah `~> 0.2.0`. Virtual time is scoped to each session.

## License

Syrma is available under the [MIT License](LICENSE.txt).
