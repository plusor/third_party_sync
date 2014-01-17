require 'yaml'
require 'debugger'
class TaobaoQuery
  class << self
    def get(query,id)
      data = data(query[:method])
      !!query[:page_no] ? data[query[:page_no]] : data(query[:method])
    end

    def data(name)
      YAML.load(File.read(File.expand_path("../fixtures/#{name}.yml",__FILE__)))
    end
  end
end