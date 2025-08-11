# frozen_string_literal: true

module Floorplan
  module Render
    class SVGRenderer
      def initialize(theme: :default)
        @theme = theme
      end

      def render(plan)
        # Determine bounds from wall endpoints
        points = plan.walls.flat_map { |w| [w.p1, w.p2] }
        points = [Vec2.new(0,0), Vec2.new(1000,1000)] if points.empty?
        min_x = points.map(&:x).min
        min_y = points.map(&:y).min
        max_x = points.map(&:x).max
        max_y = points.map(&:y).max
        pad = 200.0
        width = (max_x - min_x) + pad * 2
        height = (max_y - min_y) + pad * 2

        # SVG coordinates: y down; plan uses y up. Flip y.
        yflip = ->(y) { (max_y - (y - min_y)) + pad }
        xmap = ->(x) { (x - min_x) + pad }

        wall_paths = plan.walls.map do |w|
          x1 = xmap.call(w.p1.x)
          y1 = yflip.call(w.p1.y)
          x2 = xmap.call(w.p2.x)
          y2 = yflip.call(w.p2.y)
          thickness = [w.thickness, 1.0].max
          %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#222" stroke-width="#{thickness/10.0}" stroke-linecap="square" />)
        end.join("\n        ")

        <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width/10.0}mm" height="#{height/10.0}mm" viewBox="0 0 #{width} #{height}" style="background:#fff">
          <g id="walls">
            #{wall_paths}
          </g>
          <!-- TODO: render openings, rooms, labels -->
        </svg>
        SVG
      rescue Exception => e
        error_svg(e)
      end

      private

      def error_svg(ex)
        msg = (ex.message || 'Unknown error').gsub('<', '&lt;').gsub('>', '&gt;')
        <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="600" height="200" viewBox="0 0 600 200" style="background:#fee">
          <text x="10" y="30" font-family="monospace" font-size="16" fill="#900">Render error:</text>
          <text x="10" y="60" font-family="monospace" font-size="14" fill="#900">#{msg}</text>
        </svg>
        SVG
      end
    end
  end
end

