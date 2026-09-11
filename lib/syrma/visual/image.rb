# frozen_string_literal: true

module Syrma
  module Visual
    module Image
      module_function

      def crop(rgba, width, height, bounds)
        x = bounds.x.floor.clamp(0, width)
        y = bounds.y.floor.clamp(0, height)
        cropped_width = bounds.right.ceil.clamp(0, width) - x
        cropped_height = bounds.bottom.ceil.clamp(0, height) - y
        out = String.new(capacity: cropped_width * cropped_height * 4, encoding: Encoding::BINARY)
        cropped_height.times do |row|
          out << rgba.byteslice(((y + row) * width + x) * 4, cropped_width * 4)
        end
        [cropped_width, cropped_height, out]
      end

      def mask!(rgba, width, height, bounds, color: [255, 0, 255, 255])
        pixel = color.pack("C4")
        (bounds.y.floor.clamp(0, height)...bounds.bottom.ceil.clamp(0, height)).each do |row|
          (bounds.x.floor.clamp(0, width)...bounds.right.ceil.clamp(0, width)).each do |column|
            rgba[(row * width + column) * 4, 4] = pixel
          end
        end
        rgba
      end
    end
  end
end
