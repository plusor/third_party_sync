class TaobaoSync < BaseSync
  attr_accessor :processed
  attr_accessor :processesed
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
    options do |option|
      option[:total_page] = Proc.new {|response| (response["response"]["total_results"] / PAGE_SIZE.to_f).ceil}
      option[:items]      = Proc.new {|response| response["response"]["trades"]["trade"] }
      option[:batch]      = true
    end
    query     { |options| {method: "trades",fields: 'tid',start_created: options[:start_time],end_created: options[:end_time],page_size: PAGE_SIZE,page_no: options[:current_page]} }
    response  :_response
    parser    :_parser
  end

  group :trade do
    options   { |option| option[:items] = Proc.new {|response| response["trade_get_response"]["trade"] } }
    query     { |options| {method: "trade",fields: 'tid'} }
    response  :_response
    parser    :_parser
  end

  def processes(gp,items)
    send("processes_#{gp}",items)
  end

  def processes_trades(items)
    @processesed ||= []
    if async?(:trades)
      trades = Trade.new
      trades.insert(items)
      store trades
    else
      @processesed << Trade.new.insert(items)
    end
  end

  def process(group,item)
    send("process_#{group}",item)
  end

  def process_trade(item)
    @processed ||= []
    if async?(:trade)
      store Trade.new(item)
    else
      @processed << Trade.new(item)
    end
  end

  def default_attributes
    {"group"=> group_name.to_s}
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