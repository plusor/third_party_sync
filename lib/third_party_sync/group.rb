#encoding: utf-8
module ThirdPartySync
  class Group < Hash
    attr_accessor :name,:options,:query,:response,:parser
    def initialize(name)
      @name = name.to_sym
      initialize_attributes
    end

    def initialize_attributes
      [:options,:query,:response,:parser,:items,:total_page].each do |name|
        self[name] = {}
        self[name] = nil if name == :total_page

        self.class.send(:define_method,name) { self[name] }
      end

      options[:current_page] = 1
    end

    def inspect
      "#{name}: #{super}"
    end
  end
end