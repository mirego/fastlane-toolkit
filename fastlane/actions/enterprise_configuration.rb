#-------------------------
# Model classes
#-------------------------

# module Model
#   class Project
#     attr_reader :workspacePath, :projectPath, :infoPlistPath, :scheme, :target, :bundleIdentifier
#     def initialize(workspacePath:, projectPath:, infoPlistPath:, scheme:, target:, bundleIdentifier:)
#       @workspacePath = workspacePath
#       @projectPath = projectPath
#       @infoPlistPath = infoPlistPath
#       @scheme = scheme
#       @target = target
#       @bundleIdentifier = bundleIdentifier
#     end
#   end
#
#   class Configuration
#     attr_reader :certificate, :provisioningProfile, :buildConfiguration, :exportMethod, :bundleIdentifierOverride
#     attr_writer :buildConfiguration, :bundleIdentifierOverride
#     def initialize(certificate:, provisioningProfile:, buildConfiguration:, exportMethod:, bundleIdentifierOverride: nil)
#       @certificate = certificate
#       @provisioningProfile = provisioningProfile
#       @buildConfiguration = buildConfiguration
#       @exportMethod = exportMethod
#       @bundleIdentifierOverride = bundleIdentifierOverride
#     end
#   end
#
#   class Certificate
#     attr_reader :path, :name, :password
#     def initialize(path:, name:, password:)
#       @path = path
#       @name = name
#       @password = password
#     end
#   end
#
#   class ProvisioningProfile
#     attr_reader :path
#     def initialize(path:)
#       @path = path
#     end
#   end
# end
#
# def strip_quotes(input)
#   input.gsub(/\A['"]+|['"]+\Z/, "")
# end

module Fastlane
  module Actions
    module SharedValues
      ENTERPRISE_CONFIGURATION = :ENTERPRISE_CONFIGURATION
    end
  end

  class EnterpriseConfiguration < Action

    def self.run(params)
      Actions.lane_context[SharedValues::ENTERPRISE_CONFIGURATION] = "Test"
      # if ENV["EXEC_RUNNING_ON_JENKINS"] == "YES"
      #   genericProvisioningProfile = Model::ProvisioningProfile.new(
      #     path: "#{strip_quotes(ENV["PROVISIONING_DIR"])}/#{strip_quotes(ENV["PROVISIONING_FILE"])}"
      #   )
      #
      #   enterpriseCertificate = Model::Certificate.new(
      #     path: "#{strip_quotes(ENV["PROVISIONING_DIR"])}/#{strip_quotes(ENV["PROVISIONING_CERTIFICATE_FILE"])}",
      #     name: strip_quotes(ENV["PROVISIONING_NAME"]),
      #     password: strip_quotes(ENV["PROVISIONING_CERTIFICATE_PASSWORD"])
      #   )
      #
      #   enterpriseConfiguration = Model::Configuration.new(
      #     certificate: enterpriseCertificate,
      #     provisioningProfile: genericProvisioningProfile,
      #     buildConfiguration: "Release",
      #     exportMethod: "enterprise"
      #   )
      #
      #   Actions.lane_context[SharedValues::ENTERPRISE_CONFIGURATION] = enterpriseConfiguration
      # end
    end

    #####################################################
    # @!group Documentation
    #####################################################

    def self.description
      "Dummy action to provide enterprise configuration shared value"
    end

    def self.available_options
      []
    end

    def self.output
      [
        ['ENTERPRISE_CONFIGURATION', 'Enterprise configuration']
      ]
    end

    def self.authors
      ["antoinelamy"]
    end

    def self.is_supported?(platform)
      platform == :ios
    end
  end
end
