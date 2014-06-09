#encoding: utf-8
require 'third_party_sync/paginator'
module ThirdPartySync
  module Async
    def can_async?(*args)
      # 当前没有同步中的任务 & 当前没有有未处理的同步内容
      !asyncing?(*args) and !wait_perform?(*args)
    end

    def async(*args)
      return if not can_async?(*args)

      sync(*args) if holding?(*args)
      reset_holding(*args)
    end

    # 是否有并发 async 调用
    def holding?(*args)
      asyncs(*args).all? do |gpname,options|
        conn.watch async_key(gpname)
        conn.multi { conn.setex async_key(gpname),3600, 1 }
      end
    end

    # 清空当前正在同步标识
    def reset_holding(*args)
      asyncs(*args).each { |gpname,options| conn.del async_key(gpname) }
    end

    # 是否有 groups 正在同步
    def asyncing?(*args)
      asyncs(*args).keys.all? {|gpname| conn.exists(async_key(gpname)) }
    end

    alias_method :async?, :asyncing?

    # 指定 group_names 的 groups
    def asyncs(*args)
      _parse_args_(*args)
    end

    # perform([:products,:skus],action: :save) # perform :products and :skus groups through by :save
    # perform(:products)                       # perform :products group
    # perform                                  # perform all groups
    def perform(*args)
      action = args.last.is_a?(Hash) && args.last.delete(:action) || default_action
      asyncs(*args).each do |gpname,options|
        perform_by(gpname,action)
      end
    end

    def default_action
      :save
    end

    def perform_by(gpname,action=default_action)
      return false if asyncing?(gpname.to_sym)
      transaction do
        chgroup(gpname)
        conn.zrevrange(redis_key,0,-1).each {|object| Marshal.load(object).send(action) }
        conn.del redis_key
      end
    end

    # 是否允许确认同步 条件:
    # 1. 当前没有正在执行中的指定 group(默认所有的group) 异步同步任务
    # 2. 指定的 group(默认所有 group) 中有异步同步存储的内容
    def can_perform?(*args)
      asyncs(*args).all? {|gpname,options| !asyncing?(gpname) && conn.exists(dup.send(gpname).redis_key) }
    end

    alias_method :wait_perform?,:can_perform?

    # cancle([:products,:skus]) # cancle :products and :skus groups
    # cancle(:products)         # cancle :products group
    # cancle                    # cancle all groups
    def cancle(*args)
      asyncs(*args).each do |gpname,options|
        cancle_by(gpname)
      end
    end

    def cancle_by(name)
      return false if asyncing?(name.to_sym)
      conn.del dup.send(name).redis_key
    end

    def paginate(options={})
      StoreCollection.new(redis_key,options)
    end

    def store(object,index=Time.now.to_f)
      conn.zadd(redis_key,index,Marshal.dump(object))
    end

    def redis_key
      "#{trade_source.id}/#{group_name}"
    end

    # 正在进行同步中的key
    def async_key(gpname=group_name)
      "#{trade_source.id}/#{gpname}/async"
    end

    def conn
      ThirdPartySync::redis
    end

    # 事务块, 可以重写此方法:
    # def transaction(&block)
    #   ActiveRecord::Base.transaction { yield }
    # end
    def transaction(&block)
      yield
    end

    class StoreCollection < Array
      include ThirdPartySync::Paginator
      attr_accessor :key

      def initialize(key,options={})
        @key = key
        super paginate(options)
      end

      def paginate(options={})
        @per          = per(options[:per])
        @current_page = page(options[:page])

        starting     = starting(current_page,per)
        ending       = ending(starting,per)

        ThirdPartySync::redis.zrevrange(key,starting,ending).map {|object| Marshal.load(object) }
      end

      def count
        ThirdPartySync::redis.zcard(key)
      end

      alias_method :length, :count

      def per(num=nil)
        num.to_i < 1 ? 25 : num.to_i
      end

      def page(num=nil)
        num.to_i < 1 ? 1 : num.to_i
      end

      def starting(page,per)
        (page - 1) * per
      end

      def ending(starting,per)
        starting + per - 1
      end
    end
  end
end
