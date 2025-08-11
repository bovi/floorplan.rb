# frozen_string_literal: true

module Floorplan
  module Render
    class SVGRenderer
      def initialize(theme: :default)
        @theme = theme
      end

      def render(plan)
        points = plan.walls.flat_map { |w| [w.p1, w.p2] }
        points = [Vec2.new(0,0), Vec2.new(1000,1000)] if points.empty?
        min_x = points.map(&:x).min
        min_y = points.map(&:y).min
        max_x = points.map(&:x).max
        max_y = points.map(&:y).max
        pad = 200.0
        span_w = (max_x - min_x)
        span_h = (max_y - min_y)
        width = span_w + pad * 2
        height = span_h + pad * 2

        yflip = ->(y) { (max_y - (y - min_y)) + pad }
        xmap = ->(x) { (x - min_x) + pad }

        wall_polys = plan.walls.map { |w| extrude_wall_poly(w) }
        wall_paths = wall_polys.map do |poly|
          d = points_to_path(poly, xmap, yflip)
          %(<path d="#{d}" />)
        end.join("\n            ")

        opening_rects = plan.openings.map do |o|
          wall = plan.walls.find { |w| w.id == o.wall_id }
          next nil unless wall
          rect = opening_rect_on_wall(wall, o)
          { rect: rect, type: o.type }
        end.compact

        openings_svg = opening_rects.map do |h|
          rect = h[:rect]
          path = points_to_path(rect, xmap, yflip)
          %(<path d="#{path}" fill="#fff" stroke="none" />)
        end.join("\n            ")

        window_strokes = opening_rects.select { |h| h[:type] == :window }.map do |h|
          r = h[:rect]
          mid1 = midpoint(r[0], r[3])
          mid2 = midpoint(r[1], r[2])
          x1, y1 = xmap.call(mid1.x), yflip.call(mid1.y)
          x2, y2 = xmap.call(mid2.x), yflip.call(mid2.y)
          %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#1e88e5" stroke-width="2" />)
        end.join("\n            ")

        # Dynamic label size based on drawing span (user units ~ mm)
        base_span = [span_w, span_h].min
        label_size = [[base_span * 0.02, 36.0].max, 160.0].min
        rooms_group = render_rooms(plan, xmap, yflip, label_size: label_size)
        <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{width/10.0}mm" height="#{height/10.0}mm" viewBox="0 0 #{width} #{height}" style="background:#fff">
          #{rooms_group}
          <g id="walls" fill="#222" stroke="none">
            #{wall_paths}
          </g>
          <g id="openings">
            #{openings_svg}
            #{window_strokes}
          </g>
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

      def points_to_path(poly, xmap, yflip)
        return '' if poly.nil? || poly.empty?
        d = []
        poly.each_with_index do |p, i|
          x = xmap.call(p.x)
          y = yflip.call(p.y)
          d << (i.zero? ? "M #{x} #{y}" : "L #{x} #{y}")
        end
        d << 'Z'
        d.join(' ')
      end

      def extrude_wall_poly(w)
        dx = w.p2.x - w.p1.x
        dy = w.p2.y - w.p1.y
        len = Math.hypot(dx, dy)
        raise 'Wall length zero' if len <= 0
        ux = dx / len
        uy = dy / len
        # Left-hand normal
        nx = -uy
        ny = ux
        t = w.thickness.to_f
        case w.justify
        when :left
          a1 = Vec2.new(w.p1.x, w.p1.y)
          b1 = Vec2.new(w.p2.x, w.p2.y)
          a2 = Vec2.new(w.p1.x + nx * t, w.p1.y + ny * t)
          b2 = Vec2.new(w.p2.x + nx * t, w.p2.y + ny * t)
        when :right
          a1 = Vec2.new(w.p1.x - nx * t, w.p1.y - ny * t)
          b1 = Vec2.new(w.p2.x - nx * t, w.p2.y - ny * t)
          a2 = Vec2.new(w.p1.x, w.p1.y)
          b2 = Vec2.new(w.p2.x, w.p2.y)
        else # :center or default
          half = t / 2.0
          a1 = Vec2.new(w.p1.x - nx * half, w.p1.y - ny * half)
          b1 = Vec2.new(w.p2.x - nx * half, w.p2.y - ny * half)
          a2 = Vec2.new(w.p1.x + nx * half, w.p1.y + ny * half)
          b2 = Vec2.new(w.p2.x + nx * half, w.p2.y + ny * half)
        end
        [a1, b1, b2, a2]
      end

      def opening_rect_on_wall(w, o)
        dx = w.p2.x - w.p1.x
        dy = w.p2.y - w.p1.y
        len = Math.hypot(dx, dy)
        ux = dx / len
        uy = dy / len
        nx = -uy
        ny = ux
        at = o.at.to_f
        width = o.width.to_f
        t = w.thickness.to_f
        case w.justify
        when :left
          lo = 0.0; hi = t
        when :right
          lo = -t; hi = 0.0
        else
          lo = -t / 2.0; hi = t / 2.0
        end
        p_a = Vec2.new(w.p1.x + ux * at + nx * lo, w.p1.y + uy * at + ny * lo)
        p_b = Vec2.new(w.p1.x + ux * (at + width) + nx * lo, w.p1.y + uy * (at + width) + ny * lo)
        p_c = Vec2.new(w.p1.x + ux * (at + width) + nx * hi, w.p1.y + uy * (at + width) + ny * hi)
        p_d = Vec2.new(w.p1.x + ux * at + nx * hi, w.p1.y + uy * at + ny * hi)
        [p_a, p_b, p_c, p_d]
      end

      def midpoint(a, b)
        Vec2.new((a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
      end

      def render_rooms(plan, xmap, yflip, label_size: 24.0)
        polys = []
        labels = []
        plan.rooms.each_with_index do |r, idx|
          poly = r.polygon || (r.by_loop && Floorplan::Rooms.polygon_for(plan, r))
          next unless poly && poly.length >= 3
          d = points_to_path(poly, xmap, yflip)
          fill = r.fill || default_room_fill(idx)
          polys << %(<path d="#{d}" fill="#{fill}" stroke="none" opacity="0.6" />)
          cx, cy = centroid(poly)
          area_mm2 = polygon_area_mm2(poly).abs
          area_m2 = area_mm2 / 1_000_000.0
          area_str = format('%.1f m²', area_m2)
          tx = xmap.call(cx)
          ty = yflip.call(cy)
          if r.label && !r.label.to_s.empty?
            labels << %(
              <text x="#{tx}" y="#{ty}" font-family="system-ui, sans-serif" text-anchor="middle" fill="#0d47a1">
                <tspan x="#{tx}" dy="#{-0.2 * label_size}" font-size="#{label_size}">#{escape_text(r.label)}</tspan>
                <tspan x="#{tx}" dy="#{1.2 * label_size}" font-size="#{(label_size * 0.85)}">#{escape_text(area_str)}</tspan>
              </text>
            )
          else
            labels << %(<text x="#{tx}" y="#{ty}" font-family="system-ui, sans-serif" font-size="#{label_size}" fill="#0d47a1" text-anchor="middle" dominant-baseline="middle">#{escape_text(area_str)}</text>)
          end
        end
        return '' if polys.empty? && labels.empty?
        "<g id=\"rooms\">\n#{(polys + labels).join("\n")}\n</g>"
      end

      def centroid(poly)
        # polygon centroid (simple, non-self-intersecting)
        a = 0.0
        cx = 0.0
        cy = 0.0
        (0...poly.length).each do |i|
          p0 = poly[i]
          p1 = poly[(i + 1) % poly.length]
          cross = p0.x * p1.y - p1.x * p0.y
          a += cross
          cx += (p0.x + p1.x) * cross
          cy += (p0.y + p1.y) * cross
        end
        a *= 0.5
        if a.abs < 1e-9
          # fallback average
          sx = poly.sum(&:x)
          sy = poly.sum(&:y)
          return [sx / poly.length, sy / poly.length]
        end
        [cx / (6.0 * a), cy / (6.0 * a)]
      end

      def escape_text(t)
        t.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end

      def default_room_fill(idx)
        palette = [
          '#bbdefb', # blue 100
          '#dcedc8', # green 100
          '#ffe0b2', # orange 100
          '#f8bbd0', # pink 100
          '#c5cae9'  # indigo 100
        ]
        palette[idx % palette.length]
      end

      def polygon_area_mm2(poly)
        a = 0.0
        (0...poly.length).each do |i|
          p0 = poly[i]
          p1 = poly[(i + 1) % poly.length]
          a += p0.x * p1.y - p1.x * p0.y
        end
        0.5 * a
      end
    end
  end
end
