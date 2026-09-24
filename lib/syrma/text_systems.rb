# frozen_string_literal: true

module Syrma
  module TextSystems
    module_function

    def build(mode, fonts: [])
      case mode
      when :none, nil then nil
      when :native then Zaniah::TextSystem::Renderer.new
      when :deterministic
        paths = [Zaniah.bundled_font_path, *fonts.map { |font| File.expand_path(font) }]
        missing = paths.reject { |path| File.file?(path) }
        raise ArgumentError, "Fonts not found: #{missing.join(', ')}" unless missing.empty?

        db = Zaniah::TextSystem::FontDB.new(paths: paths)
        primary = fonts.empty? ? paths.first : paths[1]
        Zaniah::TextSystem::Renderer.new(font: db.open(primary), font_db: db)
      else
        raise ArgumentError, "Unsupported text mode: #{mode.inspect}" unless mode.respond_to?(:layout_line)

        mode
      end
    end
  end
end
