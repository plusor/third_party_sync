## 第三方平台数据同步

为第三方平台统一的数据同步接口.  所有平台的API同步接口必须和TaobaoFu一致, 第一个参数为发送API的参数,第二个为请求API辅助的参数.
正常调用第三方api需要处理分页,然后处理api的数据,最后更新或写入数据. 如果同步的地方比较多,会显得很杂乱. 这个项目提供一个标准的接口来同步第三方数据,
支持多个api的数据同步, 同步第三方数据你只需要关心三个步骤:

* 基本的请求api的参数(`query` & `options`)
* 处理 `api` 传回的数据(`parse`)
* 插入/更新数据(process(单个) & processes(批量) 需要 options[:batch] 为true的情况下才调用 processes)

方便的同步第三方数据, 标准的参数(方法)有:

* *group* 同步 `api` 的名称,默认为 `default`. `:default` 为保留字. 请勿使用
> 如: `group :products do ... end` 块中需要包含 `options`, `query`, `response`, `parser`.

如果一个同步类没有使用 `group`,默认为 `default`.

    class TaobaoProductSync < BaseSync
      group :default do
        options { |option| # ... } # or options({message: 'blabla'})
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
        query   {|options| ...}
        .....
      end

      group :skus do
        options { |option| ...}
        query   {|options| ...}
        ....
      end
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

* *options* 主要用来配置: `option[:message]`, 和 `option[:batch]`. 在初始化对象的时候,可进行附加options. `TaobaoTradeSync.new(trade_source,start_time: Time.now)`

> 1. **option[:current_page]**  系统保留参数.
>> 在 `query` 中可以使用 `options[:current_page]` 便于分页, 默认值为 `1`.

> 2. **option[:batch]**         默认为false. 同步时,调用 `process` 方法. true 则调用 `processes` 方法.

> 3. **option[:message]**       用于 `api` 请求异常调用 `cache_exception` 的参数,详见 `cache_exception`

* *total_page* 总页数,参数为 `block`. 也可以为方法名,接收的参数为 response. 没有可不填
> `total_page {|response| (response["total_result"] / 100.0).ceil}`.

* *items*  去掉请求api返回的嵌套最终取的那层数据. 参数为block. 也可以为方法名,接收的参数为 response
> `items {|response| response["response"]["trades"]}`.

* *query* 请求api所必须的参数,参数为 `block`. 也可以为方法名,接收的参数为 options
> `query {|options| { fields: 'tid,status',page_size: 100 , page_no: options[:current_page] } }`.

* *response* 用来设置调用 `api`. 参数为 `block`. 也可以为方法名. 接受的参数: `query`, `trade_source`
> `response { |query,trade_source| TaobaoQuery.get(query,trade_source) }`.

* *parser* 用来更新 `item(s)`. 参数为 `block`. `block` 的参数为 `items` 中的元素 (如果items是数组则遍历处理)
>     parser do |struct|
>        struct["account_id"] = trade_source.account_id
>        struct["name"] = struct.delete("title")
>      end
      

* *process*  自定义方法, 只有当 `options[:batch] != true` 才会调用此方法, 默认为 `nil`.
> 此方法有两个参数, 第一个参数为 正在同步的 `group name`(所有group都是遍历进行同步的). 第二个是 `item`.  `item` 为经过 `parser` 处理的结构.  `def process(gpname,item) ... end`
>>     def process(group_name,item)
>        TaobaoProduct.create(item)
>      end

* *processes* 自定义方法, 只有当 `options[:batch] = true` 才会调用此方法.
> 此方法有两个参数, 第一个参数为 正在同步的 `group name`(所有group都是遍历进行同步的). 第二个是 `items`. `items` 为经过 `parser` 遍历处理过的结构 主要用于批量处理这一页的数据. `def processes(gpname,items) ... end`
>>     def process(group_name,item)
>        send(:"process_#{group_name}",item)
>      end
>      def process_product(item)
>        TaobaoProduct.create(item)
>      end


* *cache_exception* 在处理同步的过程中运行 `response` 然后调用 `items` 时出错调用的方法.  可自定义.
> 默认的参数为 `cache_exception(message: "#{options[:message]} 同步异常(#{trade_source.name})",data: query.dup.merge(response: response))`
> options[:message] 是在 options块中设置的.


-------------------


### Install

    gem 'third_party_sync',git: 'git@git.networking.io:nioteam/third_party_sync.git',branch: "v0.0.5"

#### 完整示例

------------------------ 
针对一个API的同步

```ruby
TaobaoSync < BaseSync
   options({message: "淘宝数据同步"})
   total_page {|response,query| (response["total_results"] / query[:per].to_f).ceil}
   items      {|response| response["response"]["trades"]}
   # API parameters
   query      { |options| {method: "trade.detail.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }

   # API response
   response   { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}

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
   def _parser(struct)
     # 注意 必须要改变原对象才有效 比如 Hash#slice,  必须使用 Hash#slice!
     struct.slice!(*["tid"])
   end

   group :taobao_product do
     options({message: "淘宝商品同步",batch: true})
     total_page {|response,query| (response["total_results"] / query[:per].to_f).ceil}
     items      {|response| response["response"]["trades"]}

     query      { |options| {method: "products.lists.get", per: 100, fields: 'xxxx',current_page: options[:current_page]} }
     response   { |query,trade_source| TaobaoQuery.get(query,trade_source.id)}
     # 参数可以使用 Proc,也可使用自定义方法
     parser     :_parser
   end

   group :taobao_sku do
    options({message: "淘宝SKU同步"})
    total_page  {|response,query| (response["total_results"] / query[:per].to_f).ceil}
    items       {|response| response["response"]["trades"]}
    query       {|options| {method: "skus.lists.get",start_time: options[:start_time].strftime("%Y-%m-%d %H:%M:%S"),end_time: options[:end_time].strftime("%Y-%m-%d %H:%M:%S"), per: 100, fields: 'xxxx',current_page: options[:current_page]} }
    response    {|query,trade_source| TaobaoQuery.get(query,trade_source.id)}
    parser      :_parser
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

trade_source = TradeSource.find(201)
TaobaoSync.new(trade_source,{start_time: Time.now - 1.day,end_time: Time.now}).sync # 初始化第二个参数是 options.


# 只同步 taobao_prodcut
TaobaoSync.new(trade_source).sync(:taobao_product) or TaobaoSync.new(trade_source).sync(only: [:taobao_product])
# 或者
TaobaoSync.new(trade_source).sync(except: [:taobao_sku])
```

# BaseSync#Async

此方法会在*同步* 时更新 `async?` 为 `true`.  然后调用  `store` 存到 `redis` 中.
最后调用 `BaseSync#perform(action=:save)` 来批量处理存入的数据.

* `async(*args)`                异步同步,参数同 `sync` 方法 (需要在 process 中自行处理 保存的方式)
* `can_async?(*args)`           是否允许异步同步(参数为空的话,默认 groups )
* `async?(*args)`               指定的args(groups)同步方式是否是异步的. 如果为空的话, 默认所有groups
* `store(object)`               存入(当前`group`) redis中. 最好使用未被保存(save,update)的对象
* `paginate(options)`           在调用 `async` 后. 调用此方法分页查看(当前 `group`) `store` 的内容, options 默认选项为 page: 1, per: 25
* `cancle(*args)`               撤销 `args(groups)` 下异步同步存入redis中的内容.(如果为空的话, 撤销当前类下所有的 `group`). 正在进行同步中的group,将不会被撤销.
* `transaction`                 事物块, 可复写: def transaction(&block); ActiveRecord::Base.transaction { yield }; end
* `perform(*args,:save)`        处理 `groupname(s) (args)` 下 `store` 存入的数据,遍历参数 `:save`.  `action` 默认为 `save`. (args 可以为数组,如果为空的话,默认处理当前类下所有的 `group`). 如果给定的 groups 有正在同步中的,将不会被处理.
* `redis_key`                   redis 存储的键. 默认为 `:trade_source_id/:group_name`. 可重定义: def redis_key; "#{trade_source.name};end", 最好不要这样改, 如果groups多的话, 存进去的对象的类就可能不是一样了. 这样就不要在列表页显示了

```ruby
class TaobaoProductSync < BaseSync
  # ......

  def process(group_name,item)
    send("process_#{group_name}",item)
  end

  def process_taobao_product(item)
  # 如果调用 `TaobaoSync#async` `async?` 为 `true`
    if async?
      taobao_product.assign_attributes(item)
      store taobao_product
    else
      taobao_product.update_attributes(item)
    end
  end

  def transaction(&block)
    ActiveRecord::Base.transaction { yield }
  end
end

sync = TaobaoProductSync.new(trade_source)
sync.async

@records = sync.paginate(page: params[:page],per: params[:per])  # 页面直接 paginate(@records)

> 如果是多个groups的话,需要切换到那个 `group`. @records = sync.send(:products).paginate(page: params[:page],per: params[:per]) 

@records.perform  # 确认同步
@records.cancle   # 取消同步
```

# TODO LIST

* 重构测试