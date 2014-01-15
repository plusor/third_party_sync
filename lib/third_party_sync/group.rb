#encoding: utf-8
module ThirdPartySync
  class Group < Hash
    attr_accessor :name,:options,:query,:response,:parser
    def initialize(name)
      @name = name.to_sym
      initialize_attributes
    end

    def initialize_attributes
      [:options,:query,:response,:parser].each do |name|
        self[name] = {}
        self.class.send(:define_method,name) { self[__method__] }
      end
    end

    def inspect
      "#{name}: #{super}"
    end
  end
end