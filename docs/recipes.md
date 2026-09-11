# Syrma recipes

```ruby
ui.button("Save").click
ui.test_id("sidebar").find(has_text: "Open").click
ui.find(clickable: true).nth(2).click
ui.press("ctrl-k", "ctrl-s")
ui.type("Hello")
ui.compose("hel"); ui.commit("hello")
ui.test_id("delete").hover; ui.advance(0.6); assert_tooltip "Delete"
ui.test_id("file").right_click; ui.menu.select("Rename")
ui.scroll_until(ui.test_id("list"), found: {test_id: "row-120"})
ui.drag(ui.test_id("handle"), [300, 40])
ui.drop_files(["fixtures/a.csv"], at: ui.test_id("drop-zone"))
```

For fast logic-heavy scenarios:

```ruby
zaniah_session(text: :none, event_frames: :gesture) { |window| MyTool.mount(window) }
```

For a screenshot using a repository-owned font:

```ruby
zaniah_session(fonts: ["test/fonts/NotoSans-Regular.ttf"]) { |window| MyTool.mount(window) }
assert_screenshot "custom-font-screen"
```

For multiple windows:

```ruby
session = Syrma::Session.for_app(app) { |current| AppUi.open_windows(current) }
session.button("Settings").click
session.window(title: "Settings")
session.button("Save").click
```
