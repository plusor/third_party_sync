#encoding: utf-8
class TaobaoSync < BaseSync
  PAGE_SIZE = 10
  def _response(query,trade_source)
    TaobaoQuery.get(query,trade_source)
  end

  def _parser(struct)
    struct.merge!(default_attributes)
    struct["trade_type"] = "Taobao"
    struct
  end

  group :trades do
    options({message: "淘宝订单批量同步",batch: true})
    total_page { |response| (response["response"]["total_results"] / PAGE_SIZE.to_f).ceil }
    items      { |response| response["response"]["trades"]["trade"] }
    query      { |options| {method: "trades",fields: 'tid',start_created: options[:start_time],end_created: options[:end_time],page_size: PAGE_SIZE,page_no: options[:current_page]} }
    response  :_response
    parser    :_parser
  end

  group :trade do
    options({message: "淘宝订单同步"})
    items     { |response| response["trade_get_response"]["trade"] }
    query     { |options|  {method: "trade",fields: 'tid'} }
    response  :_response
    parser    :_parser
  end

  def processes(gp,items)
    send("processes_#{gp}",items)
  end

  def processes_trades(items)
    if async?(:trades)
      trades = Trade.new
      trades.insert(items)
      store trades
    else
      processesed << Trade.new.insert(items)
    end
  end

  def process(group,item)
    send("process_#{group}",item)
  end

  def process_trade(item)
    if async?(:trade)
      store Trade.new(item)
    else
      processed << Trade.new(item)
    end
  end

  def default_attributes
    {"group"=> group_name.to_s}
  end

  def processed
    @processed ||= []
  end

  def processesed
    @processesed ||= []
  end

  class Trade

    attr_accessor :attributes,:items
    def initialize(attr=nil)
      @attributes = attr
    end

    def insert(items)
      @items = items
    end

    def save
      "puts Done!"
    end
  end
end