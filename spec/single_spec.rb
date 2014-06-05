require 'spec_helper'
require 'active_support/all'
require 'taobao_trades_sync'

describe BaseSync do

  let(:taobao_sync) { TaobaoTradesSync.new(Struct.new(:name),{start_time: Time.now.beginning_of_day,end_time: Time.now.end_of_day}) }

  describe 'sigle' do

    it 'query' do
      taobao_sync.query.should === {
        method: "trades",
        fields: 'tid',
        start_created: Time.now.beginning_of_day,
        end_created: Time.now.end_of_day,
        page_size: 10,
        page_no: 1
      }
    end

    it 'response' do
      taobao_sync.response.should == {"response" => {"trades"=>{"trade"=>[{"tid"=>1}, {"tid"=>2}, {"tid"=>3}, {"tid"=>4}, {"tid"=>5}, {"tid"=>6}, {"tid"=>7}, {"tid"=>8}, {"tid"=>9}, {"tid"=>10}]}, "total_results"=>100}}
    end

    it 'parser' do
      TaobaoTradesSync.parser.call({}) == {"trade_type" => "Taobao"}
    end

    it 'options[:current_page]' do
      taobao_sync.options[:current_page].should == 1
    end

    context 'sync' do
      it 'process' do
        taobao_sync.sync
        taobao_sync.trades.length.should == 100
      end

      it "attributes" do
        taobao_sync.sync
        taobao_sync.trades.first.attributes.should == {"tid" => 1,"trade_type" => "Taobao"}
      end
    end
  end
end