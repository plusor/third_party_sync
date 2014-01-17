class TaobaoTradesSync < BaseSync
  PAGE_SIZE = 10
  options do |option|
    option[:total_page] = Proc.new {|response| (response["response"]["total_results"] / PAGE_SIZE.to_f).ceil}
    option[:items]      = Proc.new {|response| response["response"]["trades"]["trade"] }
  end

  query do |options|
    {
      method: "trades",
      fields: 'tid',
      start_created: options[:start_time],
      end_created: options[:end_time],
      page_size: PAGE_SIZE,
      page_no: options[:current_page]
    }
  end

  response { |query,trade_source| TaobaoQuery.get(query,trade_source) }
  
  parser do |struct|
    struct["trade_type"] = "Taobao"
  end

  def process(g,item)
    trades << Trade.new(item)
  end

  def trades
    @trades ||= []
  end
end

class Trade
  attr_accessor :attributes
  def initialize(options)
    @attributes = options
  end
end