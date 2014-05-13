require 'spec_helper'
require 'active_support/all'
require 'taobao_sync'

describe BaseSync do

  let(:start_time) { Time.now.beginning_of_day }
  let(:end_time)   { Time.now.end_of_day }
  let(:taobao_sync) { TaobaoSync.new(Struct.new(:name),{start_time: start_time,end_time: end_time }) }

  describe 'mutiple' do
    context "groups" do
      it 'default_options' do
        taobao_sync.options.should == {:current_page => 1,:start_time => start_time,:end_time => end_time }
      end

      it 'chgroup options' do
        taobao_sync.chgroup('trade').options.keys.should  == [:start_time, :end_time, :current_page,:items]
        taobao_sync.chgroup('trades').options.keys.should == [:start_time, :end_time, :current_page,:total_page,:items,:batch]
      end
    end

    it 'query' do
      taobao_sync.trade.query.should === {:method=>"trade", :fields=>"tid"}
    end

    it 'response' do
      taobao_sync.trade.fetch_items.should == {"trade_get_response" => {"trade"=>{"tid"=>1}}}
    end

    it 'parser' do
      taobao_sync.trade.parse({}).should == {"group"=>"trade", "trade_type"=>"Taobao"}
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
        taobao_sync.processed.first.attributes.should == {"tid" => 1,"group"=>"trade","trade_type" => "Taobao"}
      end
    end
  end
end