# frozen_string_literal: true

module Syrma
  class Recording
    FONT = {
      "A" => %w[01110 10001 10001 11111 10001 10001 10001], "B" => %w[11110 10001 10001 11110 10001 10001 11110],
      "C" => %w[01111 10000 10000 10000 10000 10000 01111], "D" => %w[11110 10001 10001 10001 10001 10001 11110],
      "E" => %w[11111 10000 10000 11110 10000 10000 11111], "F" => %w[11111 10000 10000 11110 10000 10000 10000],
      "G" => %w[01111 10000 10000 10111 10001 10001 01111], "H" => %w[10001 10001 10001 11111 10001 10001 10001],
      "I" => %w[11111 00100 00100 00100 00100 00100 11111], "J" => %w[00111 00010 00010 00010 10010 10010 01100],
      "K" => %w[10001 10010 10100 11000 10100 10010 10001], "L" => %w[10000 10000 10000 10000 10000 10000 11111],
      "M" => %w[10001 11011 10101 10101 10001 10001 10001], "N" => %w[10001 11001 10101 10011 10001 10001 10001],
      "O" => %w[01110 10001 10001 10001 10001 10001 01110], "P" => %w[11110 10001 10001 11110 10000 10000 10000],
      "Q" => %w[01110 10001 10001 10001 10101 10010 01101], "R" => %w[11110 10001 10001 11110 10100 10010 10001],
      "S" => %w[01111 10000 10000 01110 00001 00001 11110], "T" => %w[11111 00100 00100 00100 00100 00100 00100],
      "U" => %w[10001 10001 10001 10001 10001 10001 01110], "V" => %w[10001 10001 10001 10001 10001 01010 00100],
      "W" => %w[10001 10001 10001 10101 10101 11011 10001], "X" => %w[10001 10001 01010 00100 01010 10001 10001],
      "Y" => %w[10001 10001 01010 00100 00100 00100 00100], "Z" => %w[11111 00001 00010 00100 01000 10000 11111],
      "0" => %w[01110 10001 10011 10101 11001 10001 01110], "1" => %w[00100 01100 00100 00100 00100 00100 01110],
      "2" => %w[01110 10001 00001 00010 00100 01000 11111], "3" => %w[11110 00001 00001 01110 00001 00001 11110],
      "4" => %w[00010 00110 01010 10010 11111 00010 00010], "5" => %w[11111 10000 10000 11110 00001 00001 11110],
      "6" => %w[01110 10000 10000 11110 10001 10001 01110], "7" => %w[11111 00001 00010 00100 01000 01000 01000],
      "8" => %w[01110 10001 10001 01110 10001 10001 01110], "9" => %w[01110 10001 10001 01111 00001 00001 01110],
      "." => %w[00000 00000 00000 00000 00000 00110 00110], "-" => %w[00000 00000 00000 01110 00000 00000 00000],
      ":" => %w[00000 00110 00110 00000 00110 00110 00000], "/" => %w[00001 00010 00010 00100 01000 01000 10000]
    }.freeze

    Cast = Data.define(:width, :height, :events)
    Result = Data.define(:animation, :cast, :frames, :duration_ms) do
      def write_apng(path, **options)
        require "wezen"
        Wezen::APNG.write(path, animation, **options)
      end

      def write_gif(path, **options)
        require "wezen"
        Wezen::GIF.write(path, animation, **options)
      end

      def write_png(path)
        raise Error, "recording has no animation" unless animation
        frame = frames.last || raise(Error, "recording has no frames")
        Zaniah::PNG.write(path, animation.width, animation.height, frame.rgba)
        path
      end

      def write_cast(path, **options)
        require "wezen"
        source = cast.is_a?(Cast) ? cast : nil
        raise Error, "recording has no cast dimensions" unless source
        Wezen::Cast.write(path, width: source.width, height: source.height, events: source.events, **options)
      end
    end
    Frame = Data.define(:rgba, :delay_ms)

    attr_reader :session, :fps, :scale, :max_frames

    def initialize(session, fps:, scale:, max_frames:, seed: nil, chrome: {}, cast_only: false)
      @session = session
      @fps = Float(fps)
      @scale = Float(scale)
      @max_frames = Integer(max_frames)
      raise ArgumentError, "fps must be positive" unless @fps.positive?
      raise ArgumentError, "scale must be positive" unless @scale.positive?
      raise ArgumentError, "max_frames must be positive" unless @max_frames.positive?

      @random = Random.new(seed.nil? ? 0 : Integer(seed))
      @cast_only = cast_only
      @frames = []
      @captures = 0
      @events = []
      @elapsed = 0.0
      @frame_remainder = 0.0
      @cursor_visible = chrome.fetch(:cursor, false)
      @keycaps_visible = chrome.fetch(:keycaps, false)
      @cursor_style = :arrow
      @cursor = [0, 0]
      @keycap = nil
      @keycap_until = 0.0
      @caption_text = nil
      @caption_until = 0.0
      @highlight_bounds = nil
      @highlight_until = 0.0
      @zoom = nil
      @zoom_until = 0.0
      @last_output = ""
      @events << event(0.0, :resize, "#{terminal_dimensions[0]}x#{terminal_dimensions[1]}") if @cast_only
    end

    def advance(seconds)
      seconds = Float(seconds)
      raise ArgumentError, "time cannot be negative" if seconds.negative?

      session.advance(seconds) if seconds.positive?
      @elapsed += seconds
      @frame_remainder += seconds
      interval = 1.0 / @fps
      while @frame_remainder >= interval
        @frame_remainder -= interval
        @capture_elapsed = @elapsed - @frame_remainder
        capture
      end
      @capture_elapsed = nil
      self
    end

    def pause(seconds)
      advance(seconds)
    end

    def frame(count: 1)
      Integer(count).times { capture }
      self
    end

    def type_humanly(text, cps: 18, jitter: 0.25)
      cps = Float(cps); jitter = Float(jitter)
      raise ArgumentError, "cps must be positive" unless cps.positive?
      raise ArgumentError, "jitter must be between 0 and 1" unless jitter.between?(0.0, 1.0)

      text.each_grapheme_cluster do |character|
        session.driver.type(character)
        @keycap = character
        @keycap_until = @elapsed + (@keycap_duration || 1.2)
        advance((1.0 / cps) * (1.0 + (@random.rand * 2.0 - 1.0) * jitter))
      end
      self
    end

    def press_slowly(*keystrokes, hold: 0.08, gap: 0.25)
      keystrokes.each do |keystroke|
        session.driver.press(keystroke)
        @keycap = keystroke.to_s
        @keycap_until = @elapsed + (@keycap_duration || 1.2)
        advance(hold)
        advance(gap)
      end
      self
    end

    def click_slowly(target, approach: 0.4, **options)
      point = point_for(target)
      session.driver.mouse_move(point)
      @cursor = [point.x, point.y]
      advance(approach)
      session.driver.click(target, **options)
      self
    end

    def drag_slowly(from, to, duration: 0.8)
      start = point_for(from); finish = point_for(to)
      steps = [(Float(duration) * @fps).round, 1].max
      session.driver.mouse_move(start)
      session.driver.mouse_down(start)
      steps.times do |index|
        ratio = (index + 1).fdiv(steps)
        point = Zaniah::Point.new(start.x + (finish.x - start.x) * ratio, start.y + (finish.y - start.y) * ratio)
        session.driver.mouse_move(point)
        @cursor = [point.x, point.y]
        advance(1.0 / @fps)
      end
      session.driver.mouse_up(finish)
      self
    end

    def scroll_smoothly(target, dy:, duration: 0.6)
      steps = [(Float(duration) * @fps).round, 1].max
      steps.times { session.driver.scroll(target, dy: Float(dy) / steps); advance(1.0 / @fps) }
      self
    end

    def cursor(visible: true, style: :arrow)
      @cursor_visible = !!visible
      @cursor_style = style.to_sym
      self
    end

    def keycaps(visible: true, duration: 1.2)
      @keycaps_visible = !!visible
      @keycap_duration = Float(duration)
      self
    end

    def highlight(target, padding: 8, duration: 1.0)
      node = target.respond_to?(:resolve) ? target.resolve : target
      bounds = node.respond_to?(:bounds) ? node.bounds : node
      @highlight_bounds = [bounds.x - padding, bounds.y - padding, bounds.width + padding * 2, bounds.height + padding * 2]
      @highlight_until = @elapsed + Float(duration)
      self
    end

    def caption(text, duration: 2.0, position: :bottom)
      @caption_text = text.to_s
      @caption_position = position.to_sym
      @caption_until = @elapsed + Float(duration)
      self
    end

    def zoom(_target, scale: 2.0, duration: 0.6)
      factor = Float(scale)
      raise ArgumentError, "zoom scale must be positive" unless factor.positive?
      node = _target.respond_to?(:resolve) ? _target.resolve : _target
      bounds = node.respond_to?(:bounds) ? node.bounds : node
      @zoom = [bounds.x + bounds.width / 2.0, bounds.y + bounds.height / 2.0, factor]
      @zoom_until = @elapsed + Float(duration)
      advance(duration)
      self
    end

    def result
      animation = wezen_available? ? build_animation : nil
      cast = @cast_only ? Cast.new(terminal_dimensions[0], terminal_dimensions[1], @events.freeze) : @events.freeze
      Result.new(animation, cast, @frames.freeze, (@elapsed * 1000).round)
    end

    def write_apng(path, **options)
      require_wezen
      Wezen::APNG.write(path, build_animation, **options)
    end

    def write_gif(path, **options)
      require_wezen
      Wezen::GIF.write(path, build_animation, **options)
    end

    def write_png(path)
      frame = @frames.last || raise(Error, "recording has no frames")
      width, height = dimensions
      Zaniah::PNG.write(path, width, height, frame.rgba)
      path
    end

    def write_cast(path, **options)
      require_wezen
      width, height = terminal_dimensions
      Wezen::Cast.write(path, width: width, height: height, events: @events, **options)
    end

    private

    def require_wezen
      require "wezen"
    rescue LoadError => error
      raise LoadError, "write_apng/write_gif/write_cast require the wezen gem (#{error.message})"
    end

    def wezen_available?
      require "wezen"
      true
    rescue LoadError
      false
    end

    def capture
      raise Error, "record exceeded max_frames=#{@max_frames}" if @captures >= @max_frames
      @captures += 1
      if @cast_only
        collect_output
        return
      end
      pixels = session.screenshot_pixels
      width, height = raw_dimensions
      if @scale != 1.0
        require_wezen
        source_width, source_height = width, height
        target_width = [(@scale * source_width).round, 1].max
        target_height = [(@scale * source_height).round, 1].max
        pixels = Wezen::Image.scale(pixels, source_width, source_height, to_width: target_width, to_height: target_height)
        width = target_width; height = target_height
      end
      pixels = compose(pixels, width, height)
      delay = (1000.0 / @fps).round
      if (last = @frames.last) && last.rgba == pixels
        # Keep one immutable buffer for a static interval; only its duration grows.
        @frames[-1] = Frame.new(last.rgba, last.delay_ms + delay)
      else
        @frames << Frame.new(pixels.freeze, delay)
      end
      collect_output
    end

    def build_animation
      require_wezen
      animation = Wezen::Animation.new(width: dimensions.first, height: dimensions.last)
      @frames.each { |frame| animation.add(frame.rgba, delay_ms: frame.delay_ms) }
      animation
    end

    def dimensions
      raw_dimensions.map { |value| [(@scale * value).round, 1].max }
    end

    def raw_dimensions
      size = session.driver.window.content_size
      [size.width.to_i, size.height.to_i]
    end

    def terminal_dimensions
      size = session.driver.window.content_size
      [size.width.to_i, size.height.to_i]
    end

    def point_for(target)
      target = target.resolve if target.respond_to?(:resolve)
      return target if target.is_a?(Zaniah::Point)
      return Zaniah::Point.new(*target) if target.is_a?(Array) && target.length == 2
      target.center
    end

    def collect_output
      return unless session.tui?
      output = session.output_for.string
      delta = output.byteslice(@last_output.bytesize..)
      @events << event(@elapsed, :output, delta) if delta && !delta.empty?
      @last_output = output
    end

    def event(time, kind, data)
      if defined?(Wezen::Cast::Event)
        Wezen::Cast::Event.new(time, kind, data)
      else
        [time, kind, data]
      end
    end

    def compose(pixels, width, height)
      now = @capture_elapsed || @elapsed
      pixels = zoom_pixels(pixels, width, height) if @zoom && now < @zoom_until
      output = pixels.dup
      if @highlight_bounds && now < @highlight_until
        x, y, w, h = @highlight_bounds
        height.times do |row|
          width.times do |column|
            next if column.between?(x, x + w - 1) && row.between?(y, y + h - 1)
            index = (row * width + column) * 4
            red, green, blue, alpha = output.byteslice(index, 4).bytes
            output[index, 4] = [(red * 0.35).round, (green * 0.35).round, (blue * 0.35).round, alpha].pack("C4")
          end
        end
        rect(output, width, height, x, y, w, h, [255, 192, 0, 255])
      end
      rect(output, width, height, @cursor[0], @cursor[1], 2, 2, [255, 255, 255, 255, 255]) if @cursor_visible
      if @keycaps_visible && @keycap && now < @keycap_until
        rect(output, width, height, 12, height - 42, [@keycap.to_s.length * 8 + 20, 28].max, 28, [30, 30, 30, 220])
        draw_text(output, width, height, @keycap.to_s, 20, height - 35, [255, 255, 255, 255], scale: 2)
      end
      if @caption_text && now < @caption_until
        y = @caption_position == :top ? 0 : height - 48
        rect(output, width, height, 0, y, width, 48, [0, 0, 0, 190])
        draw_text(output, width, height, @caption_text, 12, y + 16, [255, 255, 255, 255], scale: 1)
      end
      output
    end

    def zoom_pixels(pixels, width, height)
      center_x, center_y, factor = @zoom
      output = String.new(capacity: pixels.bytesize, encoding: Encoding::BINARY)
      height.times do |row|
        source_y = (center_y + (row - height / 2.0) / factor).round
        width.times do |column|
          source_x = (center_x + (column - width / 2.0) / factor).round
          output << if source_x.between?(0, width - 1) && source_y.between?(0, height - 1)
            pixels.byteslice((source_y * width + source_x) * 4, 4)
          else
            "\0\0\0\0".b
          end
        end
      end
      output
    end

    def rect(pixels, width, height, x, y, rect_width, rect_height, color)
      x = x.to_i; y = y.to_i; rect_width = rect_width.to_i; rect_height = rect_height.to_i
      y0 = [y, 0].max; y1 = [y + rect_height, height].min; x0 = [x, 0].max; x1 = [x + rect_width, width].min
      (y0...y1).each { |row| (x0...x1).each { |column| pixels[(row * width + column) * 4, 4] = color.pack("C4") } }
    end

    def draw_text(pixels, width, height, text, x, y, color, scale: 1)
      text.to_s.upcase.each_char do |character|
        glyph = FONT[character] || Array.new(7, "10001")
        glyph.each_with_index do |row, row_index|
          row.each_char.with_index do |value, column|
            next unless value == "1"

            rect(pixels, width, height, x + column * scale, y + row_index * scale, scale, scale, color)
          end
        end
        x += 6 * scale
        break if x >= width
      end
    end
  end
end
