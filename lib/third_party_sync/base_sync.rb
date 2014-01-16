#encoding: utf-8
require 'third_party_sync/group'
require 'third_party_sync/options'
module ThirdPartySync
  class BaseSync
    include ThirdPartySync::Options
    class NotImplemented < StandardError; end

    attr_accessor :current_group
    attr_accessor :trade_source
    attr_accessor :options

    def initialize(trade_source,options={})
      @trade_source = trade_source
      @options ||= default_options.merge(@opts=options)
    end

    # 如果API有分页, 遍历每一页
    def each_page(&block)
      response = fetch_items

      options[:total_page].is_a?(Proc) && (options[:total_page] = options[:total_page].call(response,query))

      cache_exception(message: "#{options[:message]}同步异常(#{trade_source.name})",data: query.dup.merge(response: response)) do
        options[:current_page] += 1
        yield response
      end

      return if options[:total_page].zero?

      each_page(&block) if options[:current_page] <= options[:total_page]
    end

    # 同步所有group的API, 如果没有group,默认设置为default
    def sync(group=:all)
      if group.to_sym == :all
        groups.each {|name,group| sync_by(name)}
      elsif groups[group.to_sym].present?
        sync_by(group)
      else
        raise "Not found Group #{group}"
      end
    end

    # 同步某一个group的API
    # taobao_sync.sync_by(:taobao_product)
    def sync_by(name)
      chgroup(name)
      each_page do |response|
        items = options[:items].call(response).to_a.reduce([]) {|ary,item| ary << parse(item)}
        if options[:batch] == true
          processes(name,items)
        else
          items.each {|item| process(name,item)}
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
  end
end