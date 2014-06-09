require 'spec_helper'
require 'active_support/all'
require 'taobao_sync'

describe BaseSync do

  let(:start_time) { Time.now.beginning_of_day }
  let(:end_time)   { Time.now.end_of_day }
  let(:taobao_sync) { TaobaoSync.new(OpenStruct.new(name: nil,id: 1),{start_time: start_time,end_time: end_time }) }

  describe 'mutiple' do
    context "groups" do
      it 'default_options' do
        taobao_sync.options.should == {:current_page => 1,:start_time => start_time,:end_time => end_time }
      end

      it 'chgroup options' do
        taobao_sync.chgroup('trade').options.keys.should  == [:start_time, :end_time, :message, :current_page]
        taobao_sync.chgroup('trades').options.keys.should == [:start_time, :end_time, :message, :batch, :current_page]
      end
    end

    it 'query' do
      taobao_sync.trade.query.should === {:method=>"trade", :fields=>"tid"}
    end

    it 'response' do
      taobao_sync.trade.response.should == {"trade_get_response" => {"trade"=>{"tid"=>1}}}
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
    
    context 'parse_args' do
      it 'only' do
        groups = taobao_sync._parse_args_(only: [:trade])
        groups.keys.should == [:trade]
      end

      it 'exept' do
        groups = taobao_sync._parse_args_(except: [:trade])
        groups.keys.should == [:trades]
      end

      it 'array' do
        groups = taobao_sync._parse_args_(:trade,:trades)
        groups.keys.should == [:trade,:trades]
      end
    end

    context 'async' do

      it 'can async' do
        taobao_sync.can_async?.should be_true
        taobao_sync.async
        taobao_sync.perform
        taobao_sync.can_async?.should be_true
      end

      it "store" do
        taobao_sync.trades.store "foo"
        taobao_sync.paginate.count.should == 1
        taobao_sync.paginate.first.should == 'foo'
        taobao_sync.cancle
        taobao_sync.paginate.count.should == 0
      end

      it 'redis_key' do
        taobao_sync.trades
        taobao_sync.redis_key.should == '1/trades'
      end

      it 'async_key' do
        taobao_sync.trades
        taobao_sync.async_key.should == '1/trades/async'
      end

      it 'asyncs' do
        taobao_sync.asyncs.keys.should == [:trades,:trade]
        taobao_sync.asyncs(:trade).keys.should == [:trade]
        taobao_sync.asyncs(:trade,:trades).keys.should == [:trade,:trades]
      end

      it 'cancle' do
        taobao_sync.async
        %w(1/trades 1/trade).each { |key| taobao_sync.conn.exists(key).should be_true }
        taobao_sync.cancle(:trade)
        taobao_sync.conn.exists('1/trade').should be_false
        taobao_sync.conn.exists('1/trades').should be_true
      end
      
      it "holding by trade" do
        taobao_sync.holding?(:trade).should be_true
        taobao_sync.conn.keys("*").should == ['1/trade/async']
        taobao_sync.asyncing?(:trade).should be_true
      end

      it "holding by all" do
        taobao_sync.holding?.should be_true
        taobao_sync.conn.keys("*").sort.should == ['1/trade/async','1/trades/async']
      end

      it 'async by trade' do
        taobao_sync.can_async?(:trade).should be_true
        taobao_sync.async(:trade)
        taobao_sync.can_async?(:trade).should be_false
      end

      it 'cancle conditions' do
        taobao_sync.holding?(:trade).should be_true
        taobao_sync.cancle_by(:trade).should be_false
      end
      
      it 'cancle by' do
        taobao_sync.async
        taobao_sync.cancle(:trade)
        taobao_sync.conn.keys.should == ['1/trades']
      end

      it 'perform conditions' do
        taobao_sync.trade
        taobao_sync.holding?(:trade).should be_true
        taobao_sync.can_perform?(:trade).should be_false
        taobao_sync.perform_by(:trade).should be_false

        taobao_sync.store('')
        taobao_sync.can_perform?(:trade).should be_false

        taobao_sync.reset_holding(:trade)
        taobao_sync.can_perform?(:trade).should be_true
      end

      it 'perform by' do
        taobao_sync.async
        taobao_sync.perform(:trade)
        taobao_sync.conn.keys.should == ['1/trades']
      end

      it "insert data after async  " do
        taobao_sync.async
        taobao_sync.can_async?.should be_false
        taobao_sync.conn.keys("*").sort.should == ["1/trade","1/trades"]
      end
    end
  end
end