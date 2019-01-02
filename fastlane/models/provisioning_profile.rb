module Models
  class ProvisioningProfile
    attr_reader :path
    def initialize(path:)
      @path = path
    end
  end
end
