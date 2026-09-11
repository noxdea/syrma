# frozen_string_literal: true

module Syrma
  module TerminalFormat
    ROW = 20
    COL = 8
    ANSI = /\e\[[0-9;?]*[A-Za-z]/
    RGB = /\e\[38;2;(\d+);(\d+);(\d+)m/

    module_function

    def lines(output, colors: false)
      frame = output.split("\e[H").last.to_s
      frame = frame.gsub(RGB) { format("{#%02x%02x%02x}", $1.to_i, $2.to_i, $3.to_i) } if colors
      frame.gsub(ANSI, "").split("\r\n").map(&:rstrip)
    end

    def overlaps(text_runs)
      cells = text_runs.map do |x, y, text, _color|
        column = (x / COL).floor
        [(y / ROW).floor, column, column + Zaniah::Unicode.width(text.to_s), text]
      end
      cells.combination(2).filter_map do |first, second|
        [first[3], second[3], first[0]] if first[0] == second[0] && first[1] < second[2] && second[1] < first[2]
      end
    end
  end
end
