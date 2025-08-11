# frozen_string_literal: true

module Floorplan
  VERSION = '0.0.1'
end

require_relative 'floorplan/units'
require_relative 'floorplan/plan'
require_relative 'floorplan/dsl/context'
require_relative 'floorplan/evaluator'
require_relative 'floorplan/validate'
require_relative 'floorplan/render/svg_renderer'
require_relative 'floorplan/server/app'

module Floorplan
  def self.plan(&block)
    ctx = DSL::Context.new
    ctx.instance_eval(&block)
    ctx.plan
  end
end

