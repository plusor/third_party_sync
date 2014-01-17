require 'spec_helper'
require 'active_support/all'
require 'taobao_sync'

describe BaseSync do

  let(:taobao_sync) { TaobaoSync.new(Struct.new(:name),{start_time: Time.now.beginning_of_day,end_time: Time.now.end_of_day}) }

  describe 'mutiple' do

    it 'query' do
      taobao_sync.trade.query.should === {:method=>"trade", :fields=>"tid"}
    end

    it 'response' do
      taobao_sync.trade.fetch_items.should == {"trade_get_response" => {"trade"=>{"tid"=>1}}}
    end

    it 'parser' do
      TaobaoSync.groups[:trade].parser.call({})  == {"trade_type" => "Taobao"}
      TaobaoSync.groups[:trades].parser.call({}) == {"trade_type" => "Taobao"}
    end

    it 'options[:current_page]' do
      taobao_sync.options[:current_page].should == 1
    end

    context 'sync' do
      it 'process' do
        taobao_sync.sync
        taobao_sync.processesed.length.should == 10
        taobao_sync.processesed.flatten.length.should == 100
      end

      it "attributes" do
        taobao_sync.sync
        taobao_sync.processed.length.should == 1
        taobao_sync.processed.first.attributes.should == {"tid" => 1,"trade_type" => "Taobao"}
      end
    end
  end
end