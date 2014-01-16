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
   query Proc.new { |options| {method: "trade.detail.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }

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
       # 批量处理
       option[:batch]      = true
     end

     query    Proc.new { |options| {method: "products.lists.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }
     response Proc.new { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}
     # 参数可以使用 Proc,也可使用自定义方法
     parser   :_parser
   end

   group :taobao_sku do
    options  do |option|
      option[:total_page] = Proc.new {|response,query| response["total_results"] / query[:per]}
      option[:item]       = Proc.new {|response| response["response"]["trades"]}
    end
    query    Proc.new {|options| {method: "skus.lists.get",start_time: options[:start_time].strftime("%Y-%m-%d %H:%M:%S"),end_time: options[:end_time].strftime("%Y-%m-%d %H:%M:%S"), per: 100, fields: 'xxxx',current_page: options[:current_page]} }
    response Proc.new {|query,trade_source| TaobaoQuery.get(query,trade_source.id)}
    parser   :_parser
  end

  def process(group_name,item)
    send("process_#{group_name}",item)
  end

  def process_taobao_product(item)
    TaobaoProduct.first_or_create(item)
  end

  def process_taobao_sku(item)
    TaobaoSku.first_or_create(item)
  end

  # 批量处理, 在option[:batch] 为 true的情况下. 默认使用 process 方法
  def processes(group_name,items)
    send("processes_#{group_name}",items)
  end

  def processes_taobao_product
    # 批量插入数据(AR中没有insert这个方法,  主要是体现这个批量插入)
    TaobaoProduct.insert(items)
  end

  def _parser(struct)
    # 注意 必须要改变原对象才有效 比如 Hash#slice,  必须使用 Hash#slice!
    struct.slice!(*["tid"])
  end
end
# 第二个参数是提供给query的(如果query需要)
trade_source = TradeSource.find(201,{start_time: Time.now - 1.day,end_time: Time.now})
TaobaoSync.new(trade_source).sync
# 只同步 taobao_prodcut
TaobaoSync.new(trade_source).sync(:taobao_product)
```



# TODO LIST

* Add Test.
* Add async readme.