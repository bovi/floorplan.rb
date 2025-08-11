# frozen_string_literal: true

module Floorplan
  module Rooms
    module_function

    EPS = 1e-6

    def near(a, b, eps = EPS)
      (a.x - b.x).abs <= eps && (a.y - b.y).abs <= eps
    end

    # Computes an ordered polygon (array of Vec2) for a room.
    # If room.polygon is present, returns it. If room.by_loop is provided,
    # attempts to stitch the referenced walls into a closed loop of vertices.
    def polygon_for(plan, room)
      return room.polygon if room.polygon && !room.polygon.empty?
      ids = room.by_loop
      return nil unless ids && !ids.empty?
      walls = ids.map { |id| plan.walls.find { |w| w.id == id.to_sym } }
      return nil if walls.any?(&:nil?)

      # Start with the first wall oriented p1->p2
      sequence = []
      used = Array.new(walls.length, false)
      current = walls[0]
      used[0] = true
      pts = [current.p1, current.p2]
      # Greedy walk: at each step, find the next unused wall that connects.
      loop do
        connected = false
        walls.each_with_index do |w, i|
          next if used[i]
          if near(pts[-1], w.p1)
            pts << w.p2
            used[i] = true
            connected = true
            break
          elsif near(pts[-1], w.p2)
            pts << w.p1
            used[i] = true
            connected = true
            break
          end
        end
        break unless connected
        # Stop if we are back at start and all used or we're looping
        break if near(pts[-1], pts[0]) && used.all?
        # Safety to avoid infinite loops
        break if pts.length > walls.length + 2
      end

      # Ensure closed
      if !near(pts[-1], pts[0])
        # Can't close; invalid loop
        return nil
      end
      # Drop duplicate last point for polygonal path
      pts.pop
      pts
    end
  end
end

