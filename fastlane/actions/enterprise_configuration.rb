#-------------------------
# Model classes
#-------------------------

module Model
  class Project
    attr_reader :workspacePath, :projectPath, :infoPlistPath, :scheme, :target, :bundleIdentifier
    def initialize(workspacePath:, projectPath:, infoPlistPath:, scheme:, target:, bundleIdentifier:)
      @workspacePath = workspacePath
      @projectPath = projectPath
      @infoPlistPath = infoPlistPath
      @scheme = scheme
      @target = target
      @bundleIdentifier = bundleIdentifier
    end
  end

  class Configuration
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
end

def strip_quotes(input)
  input.gsub(/\A['"]+|['"]+\Z/, "")
end

module Fastlane
  module Actions
    module SharedValues
      ENTERPRISE_CONFIGURATION = :ENTERPRISE_CONFIGURATION
    end

    class EnterpriseConfigurationAction < Action
      def self.run(params)
        # sh "shellcommand ./path"

        if ENV["EXEC_RUNNING_ON_JENKINS"] == "YES"
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
        else
          enterpriseConfiguration = Model::Configuration.new(
            certificate: nil,
            provisioningProfile: nil,
            buildConfiguration: "Release",
            exportMethod: "enterprise"
          )
          Actions.lane_context[SharedValues::ENTERPRISE_CONFIGURATION] = enterpriseConfiguration
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :development,
                                       env_name: "FL_ENTERPRISE_CONFIGURATION_DEVELOPMENT",
                                       description: "Create a development certificate instead of a distribution one",
                                       is_string: false, # true: verifies the input is a string, false: every kind of value
                                       default_value: false) # the default value if the user didn't provide one
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['ENTERPRISE_CONFIGURATION', 'A configuration containing a generic provisioning profile and enterprise certificate']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["antoinelamy"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
