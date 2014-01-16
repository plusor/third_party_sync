## 第三方平台数据同步

为第三方平台统一的数据同步接口.  所有平台的API同步接口必须和TaobaoFu一致, 第一个参数为发送API的参数,第二个为请求API辅助的参数

#### USAGE

------------------------ 
针对一个API的同步

```ruby
TaobaoSync < BaseSync
   options do |option|
     # 总页数
     option[:total_page] = Proc.new {|response,query| response["total_results"] / query[:per]}
   # 订单的结构的数组
     option[:items]      = Proc.new {|response| response["response"]["trades"]}
   end
   # API parameters
   query Proc.new { |cur_page| {method: "trade.detail.get", per: 100, fields: 'xxxx',current_page: cur_page} }

   # API response
   response Proc.new { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}

   # 处理订单的数据结构
   parser do |struct|
     struct.slice(*['title'])
   end

   def process(group,item)
     # item 为经过 parser 处理过的
     TaobaoTrade.create(item)
   end
end
trade_source = TradeSource.find(201)
TaobaoSync.new(trade_source).sync
```

---------------------
针对不同的API同步

```ruby
TaobaoSync < BaseSync
   group :taobao_product do
     options do |option|
       option[:total_page] = Proc.new {|response,query| response["total_results"] / query[:per]}
       option[:items]      = Proc.new {|response| response["response"]["trades"]}
     end

     query    Proc.new { |cur_page| {method: "products.lists.get", per: 100, fields: 'xxxx',current_page: cur_page} }
     response Proc.new { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}
     # 参数可以使用 Proc,也可使用自定义方法
     parser   :_parser
   end

   group :taobao_sku do
    options  do |option|
      option[:total_page] = Proc.new {|response,query| response["total_results"] / query[:per]}
      option[:item]       = Proc.new {|response| response["response"]["trades"]}
    end
    query    Proc.new {|cur_page| {method: "skus.lists.get", per: 100, fields: 'xxxx',current_page: cur_page} }
    response Proc.new {|query,trade_source| TaobaoQuery.get(query,trade_source.id)}
    parser   :_parser
  end

  def process(group,item)
    send("process_#{group}",item)
  end

  def process_taobao_product(item)
    TaobaoProduct.first_or_create(item)
  end

  def process_taobao_sku(item)
    TaobaoSku.first_or_create(item)
  end

  def _parser(struct)
    # 注意 必须要改变原对象才有效 比如 Hash#slice,  必须使用 Hash#slice!
    struct.slice!(*["tid"])
  end
end

trade_source = TradeSource.find(201)
TaobaoSync.new(trade_source).sync
```



# TODO LIST

* Add Test.
* Add async readme.