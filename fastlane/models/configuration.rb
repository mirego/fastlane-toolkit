module Models
  class Configuration
    attr_reader :certificate, :provisioningProfile, :buildConfiguration, :exportMethod, :bundleIdentifierOverride
    attr_writer :bundleIdentifierOverride
    def initialize(certificate:, provisioningProfile:, buildConfiguration:, exportMethod:, bundleIdentifierOverride: nil)
      @certificate = certificate
      @provisioningProfile = provisioningProfile
      @buildConfiguration = buildConfiguration
      @exportMethod = exportMethod
      @bundleIdentifierOverride = bundleIdentifierOverride
    end
  end
end
