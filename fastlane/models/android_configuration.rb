#-------------------------
# Model classes
#-------------------------

module Model
  class Android::Project
    attr_reader :projectPath, :flavor, :target
    def initialize(projectPath:, flavor:, target:)
      @projectPath = projectPath
      @flavor = flavor
      @target = target
    end
  end

  class Android::Configuration
    attr_reader :certificate, :provisioningProfile, :buildConfiguration, :exportMethod, :bundleIdentifierOverride
    attr_writer :buildConfiguration, :bundleIdentifierOverride
    def initialize(certificate:, provisioningProfile:, buildConfiguration:, exportMethod:, bundleIdentifierOverride: nil)
      @certificate = certificate
      @provisioningProfile = provisioningProfile
      @buildConfiguration = buildConfiguration
      @exportMethod = exportMethod
      @bundleIdentifierOverride = bundleIdentifierOverride
    end
  end

end
