module Resque::Plugins::Later::Method
  extend ActiveSupport::Concern

  module ClassMethods
    def later(method_name, opts={})
      alias_method :"now_#{method_name}", method_name
      return unless PerformLater.enabled?
    
      define_method "#{method_name}" do |*args|
        queue          = opts.fetch(:queue, generic)
        loner          = opts.fetch(:loner, false)
        klass          = PerformLater::Workers::ActiveRecord::Worker

        klass = PerformLater::Workers::ActiveRecord::LoneWorker if loner

        args = PerformLater::ArgsParser.args_to_resque(args)
        Resque::Job.create(queue, klass, send(:class).name, send(:id), "now_#{method_name}", args)
      end
    end
  end

  module InstanceMethods
    def perform_later(queue, method, *args)
      ActiveSupport::Deprecation.warn("perform_later will be deprecated in future versions, please use the later method on your models")
      
      if PerformLater.enabled?
        args = PerformLater::ArgsParser.args_to_resque(args)
        
        Resque::Job.create(queue,
          ActiveRecordWorker,
          self.class.name,
          self.id,
          method,
          *args)
      else
        self.send(method, *args)
      end
    end
  end  
end