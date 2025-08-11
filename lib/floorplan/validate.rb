# frozen_string_literal: true

module Floorplan
  class ValidationError < StandardError; end

  module Validate
    module_function

    def check!(plan)
      errors = []
      plan.walls.each do |w|
        errors << "Wall #{w.id || '(unnamed)'} has zero length" if w.length <= 0.0
      end
      # Opening checks: positive width, within wall, non-overlap per wall
      plan.openings.group_by(&:wall_id).each do |wall_id, openings|
        wall = plan.walls.find { |w| w.id == wall_id }
        if wall.nil?
          openings.each { |o| errors << "Opening #{o.id || '(unnamed)'} references missing wall #{wall_id.inspect}" }
          next
        end
        openings.each do |o|
          errors << "Opening #{o.id || '(unnamed)'} width must be > 0" if o.width.to_f <= 0.0
          unless %i[centerline inner_face outer_face].include?(o.ref)
            errors << "Opening #{o.id || '(unnamed)'} invalid ref #{o.ref.inspect} (use :centerline, :inner_face, or :outer_face)"
          end
          if o.at.to_f < 0.0
            errors << "Opening #{o.id || '(unnamed)'} at must be >= 0"
          end
          if o.at.to_f + o.width.to_f > wall.length + 1e-6
            errors << "Opening #{o.id || '(unnamed)'} exceeds wall length #{format('%.1f', wall.length)}mm"
          end
        end
        # Overlap check
        sorted = openings.map { |o| [o.at.to_f, o.at.to_f + o.width.to_f, o] }.sort_by(&:first)
        sorted.each_cons(2) do |(_, end_a, oa), (start_b, _, ob)|
          if start_b < end_a - 1e-6
            errors << "Openings #{oa.id || '(unnamed)'} and #{ob.id || '(unnamed)'} overlap on wall #{wall_id}"
          end
        end
      end
      # Rooms: either polygon present and valid, or by_loop can be resolved
      plan.rooms.each do |r|
        poly = r.polygon
        if poly && poly.length >= 3
          # ok; optionally ensure not self-closing; assume well-formed for MVP
        elsif r.by_loop && !r.by_loop.empty?
          poly = Floorplan::Rooms.polygon_for(plan, r)
          if poly.nil? || poly.length < 3
            errors << "Room #{r.id || '(unnamed)'} by_loop does not form a closed polygon"
          else
            # cache computed polygon for downstream renderers
            r.polygon = poly
          end
        else
          errors << "Room #{r.id || '(unnamed)'} must define polygon: [...] or by_loop: [...]"
        end
      end
      raise ValidationError, errors.join("\n") unless errors.empty?
      true
    end
  end
end
