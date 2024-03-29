#-------------------------
# Model classes
#-------------------------

module Model
  class Project
    attr_reader :workspacePath, :projectPath, :infoPlistPath, :scheme, :target
    attr_accessor :bundleIdentifier, :extensions
    def initialize(workspacePath:, projectPath:, infoPlistPath:, scheme:, target:, bundleIdentifier:, extensions: Array.new)
      @workspacePath = workspacePath
      @projectPath = projectPath
      @infoPlistPath = infoPlistPath
      @scheme = scheme
      @target = target
      @bundleIdentifier = bundleIdentifier
      @extensions = extensions
    end
  end

  class Configuration
    attr_reader :certificate, :exportMethod
    attr_accessor :buildConfiguration, :bundleIdentifierOverride, :provisioningProfile, :extensionProvisioningProfiles, :iCloudContainerEnvironment
    def initialize(certificate:, provisioningProfile:, buildConfiguration:, exportMethod:, bundleIdentifierOverride: nil, iCloudContainerEnvironment: nil, extensionProvisioningProfiles: {})
      @certificate = certificate
      @provisioningProfile = provisioningProfile
      @buildConfiguration = buildConfiguration
      @exportMethod = exportMethod
      @bundleIdentifierOverride = bundleIdentifierOverride
      @iCloudContainerEnvironment = iCloudContainerEnvironment
      @extensionProvisioningProfiles = extensionProvisioningProfiles
    end
  end

  class Certificate
    attr_reader :path, :name, :password
    def initialize(path:, name:, password:)
      @path = path
      @name = name
      @password = password
    end
  end

  class ProvisioningProfile
    attr_reader :path
    def initialize(path:)
      @path = path
    end
  end

  class AppExtension
    attr_reader :target, :bundleIdentifier, :infoPlistPath
    def initialize(target:, bundleIdentifier:, infoPlistPath:)
      @target = target
      @bundleIdentifier = bundleIdentifier
      @infoPlistPath = infoPlistPath
    end
  end
end

def strip_quotes(input)
  unless input.nil?
    input.gsub(/\A['"]+|['"]+\Z/, "")
  end
end

#-------------------------
# Action definition
#-------------------------

module Fastlane
  module Actions
    module SharedValues
      ENTERPRISE_CONFIGURATION = :ENTERPRISE_CONFIGURATION
    end

    class EnterpriseConfigurationAction < Action
      def self.run(params)
        is_jenkins_ci = ENV["EXEC_RUNNING_ON_JENKINS"] != nil && strip_quotes(ENV["EXEC_RUNNING_ON_JENKINS"]) == "YES"

        if is_jenkins_ci || other_action.is_ci
          genericProvisioningProfile = Model::ProvisioningProfile.new(
            path: "#{strip_quotes(ENV["PROVISIONING_DIR"])}/#{strip_quotes(ENV["PROVISIONING_FILE"])}"
          )

          enterpriseCertificate = Model::Certificate.new(
            path: "#{strip_quotes(ENV["PROVISIONING_DIR"])}/#{strip_quotes(ENV["PROVISIONING_CERTIFICATE_FILE"])}",
            name: strip_quotes(ENV["PROVISIONING_NAME"]),
            password: strip_quotes(ENV["PROVISIONING_CERTIFICATE_PASSWORD"])
          )

          enterpriseConfiguration = Model::Configuration.new(
            certificate: enterpriseCertificate,
            provisioningProfile: genericProvisioningProfile,
            buildConfiguration: "Release",
            exportMethod: "enterprise"
          )

          Actions.lane_context[SharedValues::ENTERPRISE_CONFIGURATION] = enterpriseConfiguration

          return enterpriseConfiguration
        else
          UI.user_error!("Enterprise configuration is only available when running on CI")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Return the enterprise configuration if running on Jenkins"
      end

      def self.available_options
        # None
      end

      def self.output
        [
          ['ENTERPRISE_CONFIGURATION', 'A configuration containing a generic provisioning profile and enterprise certificate']
        ]
      end

      def self.return_value
        "The enterprise configuration"
      end

      def self.authors
        ["antoinelamy"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
