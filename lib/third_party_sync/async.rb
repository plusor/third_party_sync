require 'sidekiq'

require 'active_support/callbacks'

module ThirdPartySync
  module Async
    def self.included(base)
      base.send(:include,ActiveSupport::Callbacks)
      base.class_eval do
        define_callbacks :async_by
        set_callback :async_by, :before,:before_async_by
        set_callback :async_by, :after, :after_async_by
      end
    end

    def perform(trade_source,options)
      self.class.new(trade_source,options).async
    end

    def can_async?(g=:all)
      async? && groups.all? {|group| Sidekiq.redis {|conn| conn.type(to_parame(g)) != "list"}}
    end

    def before_async_by(name)
      raise if !can_async?(name)
    end

    def async(group=:all)
      @async = true
      sync(group)
      @async = false
    end

    def async?
      @async
    end

    def stash(group,item)
      run_callbacks :stash do
        Sidekiq.redis do |conn|
          key = to_param(group)
          conn.watch(key)
          if conn.type(key) == 'list'
            conn.multi do
              conn.rpush(key,Marshal.dump(item)) if item.valid?
            end
          else
            conn.unwatch
            raise TypeError
          end
        end
      end
    end

    def apply(group=:default)
      key = to_parame(group)
      Sidekiq.redis do |conn|
        conn.watch(key)
        conn.muti do
          conn.llen(key).times do
            begin
              obj = Marshal.load(conn.lpop(key))
              obj.save!
            rescue Exception => e
              error(group,obj,[e.message,e.backtrace])
            end
          end
        end
      end
    end

    def to_parame(group=:default)
      "#{self.class.name}/#{trade_source.id}/#{group}"
    end

    def error(group,obj,msg)
      key = to_parame(group) << '/errors'
      conn.sadd([obj,msg].inspect)
    end
  end
end