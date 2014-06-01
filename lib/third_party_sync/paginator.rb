#encoding: utf-8
## 支持第三方分页插件 kaminair
module ThirdPartySync
  module Paginator
    def current_page
      @current_page ||= page
    end

    def total_pages
      (total_count.to_f / limit_value).ceil
    end

    def total_count
      count
    end

    def limit_value
      @per ||= per
    end
  end
end