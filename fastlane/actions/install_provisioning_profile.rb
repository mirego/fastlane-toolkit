module Fastlane
  module Actions
    module SharedValues
      PROVISIONING_PROFILE_NAME = :PROVISIONING_PROFILE_NAME
      PROVISIONING_PROFILE_UUID = :PROVISIONING_PROFILE_UUID
      PROVISIONING_TEAM_ID = :PROVISIONING_TEAM_ID
    end

    class InstallProvisioningProfileAction < Action
      def self.run(params)
        provisioningProfilePath = File.expand_path(params[:path])
        provisioningProfile = FastlaneCore::ProvisioningProfile.parse(provisioningProfilePath)
        UI.message("Provisioning profile \"#{provisioningProfile['Name']} (#{provisioningProfile['UUID']})\" for team #{provisioningProfile['TeamIdentifier'].first} successfully parsed")

        Actions.lane_context[SharedValues::PROVISIONING_PROFILE_NAME] = provisioningProfile['Name']
        Actions.lane_context[SharedValues::PROVISIONING_PROFILE_UUID] = provisioningProfile['UUID']
        Actions.lane_context[SharedValues::PROVISIONING_TEAM_ID] = provisioningProfile['TeamIdentifier'].first
        
        FastlaneCore::ProvisioningProfile.install(provisioningProfilePath)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Call fastlane core to install a local provisioning profile"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       env_name: "FL_INSTALL_PROVISIONING_PROFILE_PATH",
                                       description: "Path to your provisioning profile relative to the root of your project",
                                       verify_block: proc do |value|
                                          UI.user_error!("No path for InstallProvisioningProfileAction given, pass using `path: 'your/path'`") unless (value and not value.empty?)
                                       end)
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
end
