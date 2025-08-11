# frozen_string_literal: true

# Simple numeric unit helpers. Internal unit is millimeters.
class Numeric
  def mm
    self.to_f
  end

  def cm
    (self.to_f * 10.0)
  end

  def m
    (self.to_f * 1000.0)
  end
end

module Floorplan
  module Units
    VALID = %i[meters centimeters millimeters].freeze
    def self.scale_for(unit)
      case unit
      when :meters then 1000.0
      when :centimeters then 10.0
      when :millimeters then 1.0
      else 1.0
      end
    end
  end
end

