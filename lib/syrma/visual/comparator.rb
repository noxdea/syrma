# frozen_string_literal: true

module Syrma
  class Comparator
    Result = Data.define(:width, :height, :diff_pixels, :diff_image) do
      def ratio = diff_pixels.fdiv(width * height)
    end

    def initialize(threshold: 0)
      raise ArgumentError, "threshold must be between 0 and 255" unless threshold.is_a?(Numeric) && threshold.between?(0, 255)

      @threshold = threshold
    end

    def compare(width, height, expected, actual)
      expected_size = width * height * 4
      unless expected.bytesize == actual.bytesize && expected.bytesize == expected_size
        raise ArgumentError, "Image dimensions do not match"
      end

      diff = String.new(capacity: expected_size, encoding: Encoding::BINARY)
      count = 0
      expected_bytes = expected.unpack("C*")
      actual_bytes = actual.unpack("C*")
      (width * height).times do |index|
        offset = index * 4
        different = 4.times.any? { |channel| (expected_bytes[offset + channel] - actual_bytes[offset + channel]).abs > @threshold }
        if different
          count += 1
          diff << [255, 0, 0, 255].pack("C4")
        else
          gray = ((expected_bytes[offset] * 30 + expected_bytes[offset + 1] * 59 + expected_bytes[offset + 2] * 11) / 300 + 170).clamp(0, 255)
          diff << [gray, gray, gray, 255].pack("C4")
        end
      end
      Result.new(width: width, height: height, diff_pixels: count, diff_image: diff)
    end
  end
end
