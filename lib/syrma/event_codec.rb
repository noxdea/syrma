# frozen_string_literal: true

require "json"

module Syrma
  module EventCodec
    I = Zaniah::Input
    TYPES = {
      "MouseDown" => I::MouseDown,
      "MouseUp" => I::MouseUp,
      "MouseMove" => I::MouseMove,
      "ScrollWheel" => I::ScrollWheel,
      "KeyDown" => I::KeyDown,
      "KeyUp" => I::KeyUp,
      "TextInput" => I::TextInput,
      "Composition" => I::Composition,
      "FileDrop" => I::FileDrop
    }.freeze
    SYMBOLS = %i[button phase].freeze

    module_function

    def dump(event, t:, target: nil)
      type = TYPES.key(event.class) or raise ArgumentError, "Unsupported event: #{event.class}"
      fields = event.to_h.transform_values { |value| encode(value) }
      JSON.generate({"t" => Float(t), "type" => type, "fields" => fields}.tap { |record| record["target"] = target if target })
    end

    def load(line)
      data = parse(line)
      klass = TYPES.fetch(data["type"]) { raise ArgumentError, "Unknown event type: #{data['type'].inspect}" }
      fields = data.fetch("fields")
      values = klass.members.map do |member|
        value = decode(fields.fetch(member.to_s))
        SYMBOLS.include?(member) && value ? value.to_s.to_sym : value
      end
      klass.new(*values)
    end

    def parse(line)
      data = JSON.parse(line)
      raise ArgumentError, "Recording must be a JSON object" unless data.is_a?(Hash)
      raise ArgumentError, "Unknown event type: #{data['type'].inspect}" unless TYPES.key?(data["type"])
      raise ArgumentError, "Missing fields" unless data["fields"].is_a?(Hash)

      data
    rescue JSON::ParserError => error
      raise ArgumentError, "Invalid JSON: #{error.message}"
    end

    def encode(value)
      return {"x" => value.x, "y" => value.y} if value.is_a?(Zaniah::Point)

      value
    end

    def decode(value)
      return Zaniah::Point.new(value.fetch("x"), value.fetch("y")) if value.is_a?(Hash) && value.keys.sort == %w[x y]

      value
    end
  end
end
