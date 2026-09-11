# frozen_string_literal: true

module Syrma
  module Codegen
    module_function

    def generate(lines, framework: :minitest)
      records = lines.filter_map { |line| EventCodec.parse(line) unless line.strip.empty? }
      body = operations(records).map { |line| "    #{line}" }.join("\n")
      framework == :rspec ? rspec(body) : minitest(body)
    end

    def operations(records)
      output = []
      text = +""
      flush = -> { output << "ui.type(#{text.dump})" unless text.empty?; text.clear }
      records.each_with_index do |record, index|
        if record["type"] == "TextInput"
          text << record.fetch("fields").fetch("text")
          next
        end
        next if record["type"] == "KeyUp" || typing_key?(records, index)

        flush.call
        operation = operation(record)
        output << operation if operation
      end
      flush.call
      output << "# TODO: add assertions"
    end

    def operation(record)
      fields = record.fetch("fields")
      case record["type"]
      when "MouseDown"
        target = locator(record["target"], fields.fetch("position"))
        return fields["button"].to_s == "right" ? "#{target}.right_click" : "#{target}.click" if target

        point = fields.fetch("position")
        method = fields["button"].to_s == "right" ? "right_click" : "click"
        "ui.#{method}([#{point.fetch('x')}, #{point.fetch('y')}])"
      when "KeyDown" then "ui.press(#{fields.fetch('keystroke').dump})"
      when "ScrollWheel"
        point = fields.fetch("position")
        delta = fields.fetch("delta")
        "ui.scroll([#{point.fetch('x')}, #{point.fetch('y')}], dx: #{delta.fetch('x')}, dy: #{delta.fetch('y')})"
      when "Composition" then "ui.compose(#{fields.fetch('text').dump}, selection: #{fields['selection'].inspect})"
      when "FileDrop"
        point = fields.fetch("position")
        "ui.drop_files(#{fields.fetch('paths').inspect}, at: [#{point.fetch('x')}, #{point.fetch('y')}])"
      end
    end

    def locator(target, point)
      return "ui.find(test_id: #{target['test_id'].dump})" if target&.fetch("test_id", nil)
      return "ui.button(#{target['text'].dump})" if target&.fetch("text", nil)&.then { |text| !text.empty? }

      nil
    end

    def typing_key?(records, index)
      records[index]["type"] == "KeyDown" && records[index + 1]&.fetch("type") == "TextInput"
    end

    def minitest(body)
      <<~RUBY
        require "syrma/minitest"

        class RecordedUiTest < Minitest::Test
          include Syrma::Minitest

          def test_recorded_flow
        #{body}
          end
        end
      RUBY
    end

    def rspec(body)
      <<~RUBY
        require "syrma/rspec"

        RSpec.describe "recorded UI", type: :zaniah do
          it "replays the flow" do
        #{body}
          end
        end
      RUBY
    end
  end
end
