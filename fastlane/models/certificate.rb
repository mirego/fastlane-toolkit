module Models
  class Certificate
    attr_reader :path, :name, :password
    def initialize(path:, name:, password:)
      @path = path
      @name = name
      @password = password
    end
  end
end
