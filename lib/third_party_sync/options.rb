#encoding: utf-8
module ThirdPartySync
  module Options
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # 配置选项
      #   Options:
      #    :message:      当前 group 的描述.
      #    :batch:        如果值为 true ,则调用 processes(group_name,items) . items 为经过 parse 处理过的.
      #                    默认调用 process(group_name,item).两者的区别在于一次性处理一页items的数据,
      #                    和一页数据遍历items处理单个的item
      def options(hashe={})
        raise ArgumentError,'The Argument must be Hash' if !hashe.is_a?(Hash)

        if block_given?
          yield current_group[:options]
        else
          current_group[:options].replace hashe.merge(current_group[:options])
        end

        current_group[:options]
      end

      # API查询接口的参数. 比如:
      #   TaobaoQuery.get({method: 'xxxx',fields: 'xxxx'},trade_source.id)
      #     则:
      #   query {method: 'xxxx',fields: 'xxxx'}
      #
      # 如果 query 中有分页,比如:
      #   TaobaoQuery.get({method: 'xxx',fields: 'xx',page_no: 1,page_size: 100})
      #     则:
      #   query {|options| {method: 'xxx',fields: 'xx',page_no: options[:current_page],page_size: 100} }
      #  如果query需要自定义的时间
      #  query {|options| {method: 'xxx',fields: 'xx',page_no: options[:current_page],page_size: 100,start_time: start_time.strftime("%Y-%m-%d %H:%M:%S")} }
      #  TaobaoSync.new(trade_source,{start_time: Time.now,end_time: Time.now})
      def query(query=nil)
        build_maro(:query,query,(Proc.new if block_given?))
      end

      # API查询的语句, 比如:
      #   response {|query,trade_source| TaobaoQuery.get(query,trade_source.id)} # query 等价于 上面的 query.
      #    trade_source 为 创建类时的第一个参数
      def response(id=nil)
        build_maro(:response,id,(Proc.new if block_given?))
      end

      # 参数为 items 集合中的元素.  此方法用来处理元素的值等.
      # parser {|struct| struct.slice!(*["tid"])}
      def parser(id=nil)
        build_maro(:parser,id,(Proc.new if block_given?))
      end

      # 如果API返回的数据需要嵌套取出,比如: API返回的是 {"response" => {"trades" => "trade" => [.......]}}
      # 则可以写为:  items {|response| response["response"]["trades"]["trade"] }
      def items(id=nil)
        build_maro(:items,id,(Proc.new if block_given?))
      end

      # 如果API需要分页查找,需要取出 API返回的总数量的值. 比如:
      # total_page { |response| response["response"]["total_pages"] }
      def total_page(id=nil)
        build_maro(:total_page,id,(Proc.new if block_given?))
      end

      # 可用于多个API接口的同步
      # group :taobao_product do
      #   options do
      #     ...
      #   end
      #   query {|response| ....}
      #   response { ....}
      #   ...
      # end
      # group :taobao_sku do
      #   options do
      #     ...
      #   end
      #   query {....}
      #   response {....}
      #   ....
      # end
      def group(name,&block)
        @current_group = groups[name]
        define_method(name) { chgroup(name); self }
        yield
        @current_group = nil
      end

      def groups
        @groups ||= Hash.new {|k,v| k[v] = Group.new(v)}
      end

      def current_group
        @current_group || default_group
      end

      def default_group
        @default_group ||= groups[:default]
      end

      private
      def build_maro(name,id,block)
        current_group[name] = instance_method(id) if id && method_defined?(id)
        block ? (current_group[name] = block) : current_group[name]
      end
    end

    def group_name
      @group_name ||= :default
    end

    # 当前使用的API
    def group
      self.class.groups[group_name.to_sym]
    end

    def groups
      gps = self.class.groups
      gps.keys.length > 1 ? gps.except(:default) : gps
    end
    # 更换当前使用的API
    def chgroup(name)
      @group_name = name.to_sym
      @options = default_options.merge(group_options)
      @query = nil
      self
    end

    # API所需的参数
    def query
      normal_call(group.query,options)
    end

    def items(response=response)
      normal_call(group.items,response)
    end

    def group_options
      group.options
    end

    def response
      normal_call(group.response,query,trade_source)
    end

    def total_page(response=response)
      normal_call(group.total_page,response)
    end

    def parse(item)
      normal_call(group.parser,item)
    end

    def error_message
      "#{options[:message]}同步异常(#{trade_source.name})"
    end

    def request(result)
      {query: query,result: result}
    end

    protected
    def normal_call(block,*args)
      case block
      when UnboundMethod then block.bind(self).call(*args)
      when Proc          then instance_exec(*args,&block)
      else
        block
      end
    end
  end
end