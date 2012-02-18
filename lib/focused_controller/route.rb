module FocusedController
  class Route
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def call(env)
      name.constantize.call(env)
    end

    def to_s
      "#{name}#run"
    end
  end
end
