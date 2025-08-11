# frozen_string_literal: true

module Floorplan
  # Basic 2D vector
  Vec2 = Struct.new(:x, :y) do
    def +(o) = Vec2.new(x + o.x, y + o.y)
    def -(o) = Vec2.new(x - o.x, y - o.y)
    def to_a = [x, y]
  end

  class Layer
    attr_accessor :name, :visible, :style
    def initialize(name, visible: true, style: {})
      @name = name.to_sym
      @visible = visible
      @style = style
    end
    def to_h = { name: @name, visible: @visible, style: @style }
  end

    class Wall
    attr_accessor :id, :p1, :p2, :thickness, :justify, :layer
    def initialize(id:, p1:, p2:, thickness:, justify: :center, layer: :walls)
      @id = id&.to_sym
      @p1 = p1
      @p2 = p2
      @thickness = thickness
      @justify = justify
      @layer = layer.to_sym
    end
    def length
      Math.hypot(p2.x - p1.x, p2.y - p1.y)
    end
    def to_h
      { type: :wall, id: @id, p1: p1.to_a, p2: p2.to_a, thickness: @thickness, justify: @justify, layer: @layer }
    end
  end

  class Opening
    attr_accessor :id, :wall_id, :at, :width, :type, :swing, :sill, :head
    def initialize(id:, wall_id:, at:, width:, type:, swing: nil, sill: nil, head: nil)
      @id = id&.to_sym
      @wall_id = wall_id&.to_sym
      @at = at
      @width = width
      @type = type.to_sym
      @swing = swing&.to_sym
      @sill = sill
      @head = head
    end
    def to_h
      { type: :opening, id: @id, wall_id: @wall_id, at: @at, width: @width, subtype: @type, swing: @swing, sill: @sill, head: @head }
    end
  end

  class Room
    attr_accessor :id, :label, :polygon, :by_loop, :layer, :fill
    def initialize(id:, label: nil, polygon: nil, by_loop: nil, layer: :rooms, fill: nil)
      @id = id&.to_sym
      @label = label
      @polygon = polygon
      @by_loop = by_loop
      @layer = layer.to_sym
      @fill = fill
    end
    def to_h
      { type: :room, id: @id, label: @label, polygon: @polygon&.map(&:to_a), by_loop: @by_loop, layer: @layer, fill: @fill }
    end
  end

  class Label
    attr_accessor :text, :at, :rotation, :layer, :style
    def initialize(text:, at:, rotation: 0, layer: :annotations, style: {})
      @text = text
      @at = at
      @rotation = rotation
      @layer = layer.to_sym
      @style = style
    end
    def to_h
      { type: :label, text: @text, at: @at.to_a, rotation: @rotation, layer: @layer, style: @style }
    end
  end

  class Plan
    attr_accessor :units, :origin, :scale, :theme
    attr_reader :layers, :walls, :openings, :rooms, :labels
    def initialize(units: :millimeters, origin: :lower_left, scale: nil, theme: :default)
      @units = units
      @origin = origin
      @scale = scale
      @theme = theme
      @layers = { walls: Layer.new(:walls), rooms: Layer.new(:rooms), annotations: Layer.new(:annotations) }
      @walls = []
      @openings = []
      @rooms = []
      @labels = []
    end

    def ensure_layer(name, **opts)
      @layers[name.to_sym] ||= Layer.new(name, **opts)
    end

    def to_h
      {
        units: @units,
        origin: @origin,
        scale: @scale,
        theme: @theme,
        layers: @layers.transform_values(&:to_h),
        walls: @walls.map(&:to_h),
        openings: @openings.map(&:to_h),
        rooms: @rooms.map(&:to_h),
        labels: @labels.map(&:to_h)
      }
    end
  end
end
