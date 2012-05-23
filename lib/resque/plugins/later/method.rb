module Resque::Plugins::Later::Method
  extend ActiveSupport::Concern

  module ClassMethods
    def later(method_name, opts={})
      alias_method "now_#{method_name}", method_name
      return unless PerformLater.config.enabled?
      
      define_method "#{method_name}" do |*args|
        loner          = opts.fetch(:loner, false)
        queue          = opts.fetch(:queue, :generic)
        klass          = PerformLater::Workers::ActiveRecord::Worker
        klass          = PerformLater::Workers::ActiveRecord::LoneWorker if loner
        args           = PerformLater::ArgsParser.args_to_resque(args)
        digest         = PerformLater::PayloadHelper.get_digest(klass, method_name, args)

        if loner
          return "AR EXISTS!" unless Resque.redis.get(digest).blank?
          Resque.redis.set(digest, 'EXISTS')
        end
        
        Resque::Job.create(queue, klass, send(:class).name, send(:id), "now_#{method_name}", args)
      end
    end
  end

  def perform_later(queue, method, *args)
    args = PerformLater::ArgsParser.args_to_resque(args)
    worker = PerformLater::Workers::ActiveRecord::Worker

    enqueue_in_resque_or_send(worker, queue, method, args)
  end

  def perform_later!(queue, method, *args)
    args = PerformLater::ArgsParser.args_to_resque(args)
    digest = PerformLater::PayloadHelper.get_digest(self.class.name, method, args)
    worker = PerformLater::Workers::ActiveRecord::LoneWorker
    
    return "AR EXISTS!" unless Resque.redis.get(digest).blank?
    Resque.redis.set(digest, 'EXISTS')

    enqueue_in_resque_or_send(worker, queue, method, args)
  end

  private 
    def enqueue_in_resque_or_send(worker, queue, method, *args)
      if PerformLater.config.enabled?
        Resque::Job.create(queue, worker, self.class.name, self.id, method, *args)   
      else
        args = PerformLater::ArgsParser.args_from_resque(args)
        self.send(method, *args)
      end
    end
end