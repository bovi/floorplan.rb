# frozen_string_literal: true

module Floorplan
  class Evaluator
    def self.from_file(path)
      code = File.read(path)
      from_string(code, file: path)
    end

    def self.from_string(code, file: '(plan)')
      # Evaluate the code expecting it to call Floorplan.plan { ... }
      plan = nil
      sandbox = Module.new do
        define_singleton_method(:Floorplan) { ::Floorplan }
      end

      plan = TOPLEVEL_BINDING.eval(code, file)
      unless plan.is_a?(::Floorplan::Plan)
        # If user wrote Floorplan.plan { ... } without returning, try capturing via eval hook
        plan = nil
        ::Floorplan.singleton_class.class_eval do
          alias_method :__orig_plan__, :plan
          define_method(:plan) do |&blk|
            @__last_plan = __orig_plan__(&blk)
          end
        end
        begin
          TOPLEVEL_BINDING.eval(code, file)
          plan = ::Floorplan.instance_variable_get(:@__last_plan)
        ensure
          ::Floorplan.singleton_class.class_eval do
            remove_method :plan
            alias_method :plan, :__orig_plan__
            remove_method :__orig_plan__
          end
          ::Floorplan.remove_instance_variable(:@__last_plan) rescue nil
        end
      end
      raise "Plan file did not produce a Floorplan::Plan (#{file})" unless plan.is_a?(::Floorplan::Plan)
      plan
    rescue Exception => e
      e.define_singleton_method(:plan_file) { file }
      raise e
    end
  end
end

