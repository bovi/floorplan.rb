# frozen_string_literal: true

module Floorplan
  module DSL
    # Execution context for Floorplan.plan DSL
    class Context
      attr_reader :plan

      def initialize
        @plan = Floorplan::Plan.new
        @cursor = nil
        @path_start = nil
        @walls_defaults = { thickness: 100.mm, justify: :center, layer: :walls }
      end

      # Global settings
      def units(unit)
        @plan.units = unit.to_sym
      end

      def origin(o)
        @plan.origin = o.to_sym
      end

      def scale(s)
        @plan.scale = s
      end

      def theme(t)
        @plan.theme = t.to_sym
      end

      def layer(name, visible: true, style: {})
        @plan.layers[name.to_sym] = Floorplan::Layer.new(name, visible: visible, style: style)
      end

      # Defaults for walls created afterwards
      def walls(thickness: nil, justify: nil, layer: nil)
        @walls_defaults[:thickness] = thickness if thickness
        @walls_defaults[:justify] = justify.to_sym if justify
        @walls_defaults[:layer] = layer.to_sym if layer
      end

      # Drawing cursor controls
      def start(at:)
        @cursor = vec(at)
        @path_start = @cursor
      end

      def line(from:, to:, id: nil, thickness: nil, justify: nil, layer: nil)
        p1 = vec(from)
        p2 = vec(to)
        add_wall(p1, p2, id: id, thickness: thickness, justify: justify, layer: layer)
        @cursor = p2
      end

      def go(direction, length, id: nil, thickness: nil, justify: nil, layer: nil)
        raise 'start point not set (call start at: [x,y])' unless @cursor
        len = to_mm(length)
        dir = direction.is_a?(Symbol) ? direction : direction.to_sym
        dx, dy = case dir
                 when :east then [len, 0]
                 when :west then [-len, 0]
                 when :north then [0, len]
                 when :south then [0, -len]
                 else
                   # treat as angle in degrees from +x CCW
                   ang = direction.to_f * Math::PI / 180.0
                   [Math.cos(ang) * len, Math.sin(ang) * len]
                 end
        p1 = @cursor
        p2 = Vec2.new(p1.x + dx, p1.y + dy)
        add_wall(p1, p2, id: id, thickness: thickness, justify: justify, layer: layer)
        @cursor = p2
      end

      def close_path(id: nil, thickness: nil, justify: nil, layer: nil)
        raise 'no path to close (call start ... then go ...)' unless @cursor && @path_start
        add_wall(@cursor, @path_start, id: id, thickness: thickness, justify: justify, layer: layer)
        @cursor = @path_start
        @path_start = nil
      end

      # Entities
      def opening(wall:, at:, type:, width:, swing: nil, sill: nil, head: nil, id: nil)
        @plan.openings << Floorplan::Opening.new(
          id: id,
          wall_id: wall,
          at: to_mm(at),
          width: to_mm(width),
          type: type,
          swing: swing,
          sill: sill && to_mm(sill),
          head: head && to_mm(head)
        )
      end

      def room(id, by_loop: nil, polygon: nil, label: nil, layer: :rooms, fill: nil)
        poly = polygon&.map { |p| vec(p) }
        @plan.rooms << Floorplan::Room.new(id: id, label: label, polygon: poly, by_loop: by_loop, layer: layer, fill: fill)
      end

      def label(text, at:, rotation: 0, layer: :annotations, style: {})
        @plan.labels << Floorplan::Label.new(text: text, at: vec(at), rotation: rotation.to_f, layer: layer, style: style)
      end

      # Helpers
      def to_mm(v)
        v.respond_to?(:to_f) ? v.to_f : v
      end

      def vec(pair)
        x, y = pair
        Floorplan::Vec2.new(to_mm(x), to_mm(y))
      end

      private

      def add_wall(p1, p2, id:, thickness:, justify:, layer:)
        opts = @walls_defaults.dup
        opts[:thickness] = to_mm(thickness) if thickness
        opts[:justify] = justify.to_sym if justify
        opts[:layer] = layer.to_sym if layer
        @plan.ensure_layer(opts[:layer])
        @plan.walls << Floorplan::Wall.new(id: id, p1: p1, p2: p2, thickness: opts[:thickness], justify: opts[:justify], layer: opts[:layer])
      end
    end
  end
end

