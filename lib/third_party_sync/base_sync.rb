#encoding: utf-8
require 'third_party_sync/group'
require 'third_party_sync/options'
require 'third_party_sync/async'
module ThirdPartySync
  class BaseSync
    include ThirdPartySync::Options
    class NotImplemented < StandardError; end

    attr_accessor :current_group
    attr_accessor :trade_source
    attr_accessor :options,:default_options

    def initialize(trade_source,options={})
      @trade_source = trade_source
      @default_options,@options = options,group_options.merge(options)
    end

    # 如果API有分页, 遍历每一页
    def each_page(&block)
      body = response

      options[:total_page] = total_page(body).to_i

      cache_exception(message: error_message,data: request(body)) do
        options[:current_page] += 1
        yield body
      end

      return if options[:total_page].zero?

      each_page(&block) if options[:current_page] <= options[:total_page]
    end

    # 同步所有 group, 如果没有 group ,默认设置为 default
    def sync(*args)
      _parse_args_(*args).each {|name,group| sync_by(name)}
    end

    def _parse_args_(*args)
      opts = args.extract_options!
      if opts[:only]
        groups.slice(*opts[:only])
      elsif opts[:except]
        groups.except(*opts[:except])
      else
        args.blank? ? groups() : groups.slice(*args.flatten.map(&:to_sym))
      end
    end

    # 同步某一个group的API
    # taobao_sync.sync_by(:taobao_product)
    def sync_by(name)
      chgroup(name).each_page do |body|
        items = Array.wrap(items(body)).reduce([]) do |ary,item|
          parse(item)
          ary << item
        end

        if options[:batch] == true
          processes(group_name,items)
        else
          items.each {|item| process(group_name,item)}
        end
      end
    end

    # 批量处理单页的所有items中的数据(items为parse后的).
    # 如果是插入数据的话, 主要用来减少数据库连接次数(比如sql插入次数), 进行批量插入
    # 只有在 option[:batch] = true 的情况下才会调用
    def processes(group_name,items)
      raise NotImplemented
    end

    # item 为经过parser 处理后的对象(一般是Hash)
    # 此方法用来处理 API请求过来的数据. 比如创建,或更新
    def process(group_name,item)
      raise NotImplemented
    end

    def cache_exception(*args)
      if Class.respond_to?(:cache_exception)
        super(*args)
      else
        yield
      end
    end
    include Async
  end
end