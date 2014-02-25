## 第三方平台数据同步

为第三方平台统一的数据同步接口.  所有平台的API同步接口必须和TaobaoFu一致, 第一个参数为发送API的参数,第二个为请求API辅助的参数.
正常调用第三方api需要处理分页,然后处理api的数据,最后更新或写入数据. 如果同步的地方比较多,会显得很杂乱. 这个项目提供一个标准的接口来同步第三方数据,
支持多个api的数据同步, 同步第三方数据你只需要关心三个步骤:

* 基本的请求api的参数(query & options)
* 处理 `api` 传回的数据(parse)
* 插入/更新数据(process(单个) & processes(批量) 需要options[:batch] 为true的情况下才调用processes)

方便的同步第三方数据, 标准的参数(方法)有:

* *group* 同步 `api` 的名称,默认为 `default`, 如: `group :products do ... end` 块中需要包含 `options`, `query`, `response`, `parser`
* *options* 主要存放 总页数 `option[:total_page]`, 和所需要的那层数据(一般 `api` 会嵌套好几层的数据) `option[:items]`
    1. *total_page* 总页数, 参数为 `block`, `option[:total_page] = Proc.new {|response| (response[:total_result] / 100.0).ceil}`, `block`的参数为 `api` 的 `response`
    2. *items* 去掉 `response` 前缀的那层数据, 参数为block `option[:items] = Proc.new {|response| response["response"]["trades"]}` ,block的参数为 `api` 的 `response`
* *query* 请求api所必须的参数,参数为 `block`, `query {|options| { fields: 'tid,status',page_size: 100 , page_no: options[:current_page] } }` block的参数为 `options`
* *response* 调用api的方法, 参数为 `block` , `response { |query,trade_source| TaobaoQuery.get(query,trade_source) }`, `block` 的参数有两个, 第一个是 `query` 第二个是 初始化`class`的第一个参数. `TaobaoProductSync.new(TradeSource.first)`
* *parser* 参数为 `block`, block的参数为items中的元素(如果items是数组则遍历处理)
* *process*  自定义方法, 只有当 `options[:batch] != true` 才会调用此方法, 默认为 `nil`. 此方法有两个参数, 第一个参数为 `group` 的 `name` , 第二个是 `item`. item 为经过parse处理过的结构
* *processes* 自定义方法, 只有当 `options[:batch] = true` 才会调用此方法,  此方法有两个参数, 第一个参数为 `group` 的 `name`, 第二个是 `items`. `items` 为经过 `parse` 遍历处理过的结构 主要用于批量处理这一页的数据
* *cache_exception* 在 `options[:items].call` 异常的时候调用此方法.

--------------

#### group
如果说一个同步类只同步某个 `api`,那么默认的 `group` 为 `default` .

    class TaobaoProductSync < BaseSync
      group :default do
        options { |option| # ... }
        query {....}
        # ....
      end
    end
    
    # 等于
    
    class TaobaoProductSync < BaseSync
      options {|option|  ...}
      query ...
      # ....
    end

如果同步多个 `api` 时候可以指定 `group`

    class TaobaoProductSync < BaseSync
      group :products do
      options { |option| ... }
    end
    
    group :skus do
      options { |option| ...}
    end
    
    # 只同步 products
    taobao = TaobaoProductSync.new(trade_source)
    taobao.sync(:products)
    # 只同步除了 products
    taobao.sync(except: [:products])
    # 同步多个指定的
    taobao.sync(only: [:products,:skus])
    # 同步所有
    taobao.sync

--------------------

#### options
在类的实例中可使用 `options` 来访问.  
默认的 `options` 的值:

*  `:current_page` 在 `query` 中可以使用 `options[:current_page]` 便于分页, 默认值为 `1`.
*  `:batch`        用来批量处理请求过来的经过 `parser` 处理的数据 ,默认值为`false`
*  `:message`      用于api请求异常调用 `cache_exception` 的参数,详见 `cache_exception`

其中必填的 几个 `option` 有:

* `option[:items]` 值应该是一个带 `call` 的方法 比如方法或者 `proc`,  参数为 `api` 请求过来的数据. 一般api请求过来的数据都会嵌套好几层, 只取最终想要的数据

* `option[:total_page]` 值也是一个带 `call` 的方法. 比如方法或者 `proc`, 参数为 `api` 请求过来的数据. 结果应该是总页数, 不是返回的总数. 比如:

        PAGE_SIZE = 100
        query {|option| {method: 'xxxx',page_size: PAGE_SIZE,page_no: options[:current_page]}}
        options do |option|
          option[:total_page] = Proc.new {|response| (response[:total_result] / PAGE_SIZE).ceil }
        end

------------------

#### query
在类的实例中可使用 `query` 来访问.  
请求 `api` 所必须的参数, 比如 淘宝中的 `method` 等等.

    query { |options| {method: 'taobao.items.onsale.get',fields: FIELDS,page_size: PAGE_SIZE,page_no: options[:current_page] } }

-------------------

#### response
调用第三方 `api` 的接口, 需要带一个 `block`,  参数1 为 `query`, 参数2 为 `trade_source`

    response {|query,trade_source| TaobaoQuery.get(query,trade_source) }
    

---------------------
#### parser
遍历处理 `items`, 需要带一个 `block`, 参数为 `items` 中的元素.

    parser do |struct|
      struct["account_id"] = trade_source.account_id
      struct["name"] = struct.delete("title")
    end

-------------------

#### process
为自定义的方法, 用来最终处理经过 `parser` 处理过的数据, 第一个参数为 `group`, 第二个为 经过 `parser` 处理过的单个数据

    options do |option|
    # ..
    end
    
    def process(group_name,item)
      TaobaoProduct.create(item)
    end

    # 如果有多个group的话
    # def process(group_name,item)
    # send(:"process_#{group_name}",item)
    # end
    
    # def process_product(item)
    # TaobaoProduct.create(item)
    # end


#### processes
为自定义的方法, 需要在 `options` 中激活,  `option[:batch] = true`, , 第一个参数为 `group`, 第二个为 经过 `parser` 处理过的所有数据

    options do |option|
      # ....
      option[:batch] = true
      # ...
    end
    
    # ...
    
    def processes(group_name,items)
      # 如果有多个 group的话可以使用
      send(:"processes_#{group_name}",items)
    end
    
    def processes_trades(items)
      TaobaoTrade.collection.insert(items)
    end

-------------------

####  cache_exception
请求 `api` 如果异常(或者 `option[:items]` 的结果没有时) 会调用此方法,用来追踪异常信息.
参数为 `Hash`,   `:message` 为 `options` 中的 `message`, `options[:data]` `api` 请求返回的数据

* `message` 的格式为 `"#{options[:message]}同步异常(#{trade_source.name})"`
* `data`    `query.dup.merge(response: response)`

        def cache_exception(options)
          Notifier.send_message(options[:message],options[:data])
        end

### Install

    gem 'third_party_sync',git: 'git@git.networking.io:ddl1st/third_party_sync.git',branch: "v0.0.3"

#### USAGE

------------------------ 
针对一个API的同步

```ruby
TaobaoSync < BaseSync
   options do |option|
     # 总页数
     option[:total_page] = Proc.new {|response,query| (response["total_results"] / query[:per].to_f).ceil}
   # 订单的结构的数组
     option[:items]      = Proc.new {|response| response["response"]["trades"]}
   end
   # API parameters
   query { |options| {method: "trade.detail.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }

   # API response
   response { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}

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
   # 此方法必须放到最上面
   def _parser(struct)
     # 注意 必须要改变原对象才有效 比如 Hash#slice,  必须使用 Hash#slice!
     struct.slice!(*["tid"])
   end

   group :taobao_product do
     options do |option|
       option[:total_page] = Proc.new {|response,query| (response["total_results"] / query[:per].to_f).ceil}
       option[:items]      = Proc.new {|response| response["response"]["trades"]}
       # 批量处理
       option[:batch]      = true
     end

     query    { |options| {method: "products.lists.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }
     response { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}
     # 参数可以使用 Proc,也可使用自定义方法
     parser   :_parser
   end

   group :taobao_sku do
    options  do |option|
      option[:total_page] = Proc.new {|response,query| (response["total_results"] / query[:per].to_f).ceil}
      option[:item]       = Proc.new {|response| response["response"]["trades"]}
    end
    query    {|options| {method: "skus.lists.get",start_time: options[:start_time].strftime("%Y-%m-%d %H:%M:%S"),end_time: options[:end_time].strftime("%Y-%m-%d %H:%M:%S"), per: 100, fields: 'xxxx',current_page: options[:current_page]} }
    response {|query,trade_source| TaobaoQuery.get(query,trade_source.id)}
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
end
# 第二个参数是提供给query的(如果query需要)
trade_source = TradeSource.find(201)
TaobaoSync.new(trade_source,{start_time: Time.now - 1.day,end_time: Time.now}).sync
# 只同步 taobao_prodcut
TaobaoSync.new(trade_source).sync(:taobao_product) or TaobaoSync.new(trade_source).sync(only: [:taobao_product]) or TaobaoSync.new(trade_source).sync(except: [:taobao_sku])
```



# TODO LIST

* Add async readme.