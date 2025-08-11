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
      # Minimal opening bounds check: width positive
      plan.openings.each do |o|
        errors << "Opening #{o.id || '(unnamed)'} width must be > 0" if o.width.to_f <= 0.0
      end
      raise ValidationError, errors.join("\n") unless errors.empty?
      true
    end
  end
end

