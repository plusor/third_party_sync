require 'spec_helper'
require 'active_support/all'

describe BaseSync do
  class Single < BaseSync
    options do |option|
      option[:total_page] = Proc.new {|response| response[:total_result] / 100}
      option[:items]      = Proc.new {|response| response[:items]}
    end

    query do |cur_page|
      {
        method: "taobao.trades.sold.get",
        fields: 'tid',
        start_created: Time.now.beginning_of_day,
        end_created: Time.now.end_of_day,
        page_size: 100,
        page_no: cur_page
      }
    end

    response { |query,trade_source| TaobaoQuery.get(query,trade_source) }
  end

  class TaobaoQuery
    class << self
      def get(query,trade_source)
        {total_result: 400, items: {trades: data(query[:page_no])}}
      end

      def data(page)
        {
          1 => [{tid: 1}],
          2 => [{tid: 2}],
          3 => [{tid: 3}],
          4 => [{tid: 4}],
          }[page]
      end
    end
  end

  let(:single) { Single.new(Struct.new(:name)) }

  describe 'sigle' do

    it 'query' do
      single.query.should === {
        :method => "taobao.trades.sold.get",
        :start_created => Time.now.beginning_of_day,
        :end_created => Time.now.end_of_day,
        :fields => "tid",
        :page_no => 1,
        :page_size => 100
      }
    end

    it 'response' do
      single.fetch_items.should == {total_result: 400, items: {trades: [{tid: 1}]}}
    end

    it 'specific page' do
      a = 0
      single.each_page do |response|
        response.should == {total_result: 400, items: {trades: [{tid: a+=1}]}}
      end
    end

    it 'parser' do
      Single.parser.should == {}
    end
  end
end