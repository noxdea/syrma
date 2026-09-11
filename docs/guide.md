# Syrma guide

## Structure an application for tests

Put UI construction in a method that accepts a window. Keep backend selection, the native text renderer, and `window.run` in the production entry point. Tests can then mount the same UI in a deterministic headless window.

```ruby
module MyTool
  def self.mount(window)
    window.draw { Zaniah::Text.new("Ready") }
  end

  def self.run
    window = Zaniah::Platform.open_window(backend: :mac, width: 480, height: 320)
    window.text_system = Zaniah::TextSystem::Renderer.new
    mount(window)
    window.run
  end
end
```

Use `test_id` for stable targets:

```ruby
Zaniah::Div.new.test_id("save-button").on_click { save }
```

An existing `key` also works when changing application code is undesirable.

## Create a session

```ruby
session = Syrma::Session.new(width: 480, height: 320) { |window| MyTool.mount(window) }
```

Use `Session.attach(window)` for an existing window, `Session.for_app(app)` for an app that opens multiple windows, and `Session.launch_script(path)` for a legacy script that ends in `window.run`.

Important options are:

- `text: :deterministic`, `:none`, `:native`, or a custom text system
- `fonts: [...]` for deterministic non-Latin rendering
- `raster: :lazy` or `:eager`
- `clock: :virtual`, `:real`, or a callable clock shared with `Zaniah::App`
- `event_frames: :each` for fidelity or `:gesture` for speed
- `strict: true` to reject ambiguous action targets

## Run in CI

Set `CI=true`, keep snapshot goldens under version control, and upload `tmp/syrma` when tests fail. Use the same OS and fonts that produced screenshot goldens.

## Environment variables

| Variable | Meaning |
| --- | --- |
| `SYRMA_UPDATE_SNAPSHOTS=1` | Create or update goldens |
| `SYRMA_SNAPSHOT_DIR` | Override the golden directory |
| `SYRMA_TIMEOUT` | Override the default wait timeout |
| `SYRMA_ARTIFACTS` | Override diagnostics output |
| `SYRMA_RASTER=eager` | Rasterize every frame |
| `SYRMA_NATIVE=1` | Enable the optional native smoke test |
| `CI` | Treat missing goldens as failures |

## Troubleshooting

- `ElementNotFound`: inspect the visible-text list; virtual-list rows require `scroll_until`.
- `AmbiguousMatch`: add a `test_id`, nest locators, or select with `nth`.
- `NotActionable`: close a popup, target the element with the handler, or use `force: true` only when testing obstruction itself.
- `UnstableUI`: a render loop keeps requesting frames; advance virtual time or choose an intentional frame boundary.
- Missing text in screenshots: do not use `text: :none`; provide a deterministic font containing the glyphs.
- Key shortcuts do nothing: pass the application's keymap and focus a `FocusHandle`.
