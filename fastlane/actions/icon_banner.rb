module Fastlane
  module Actions
    class IconBannerAction < Action
      def self.run(params)
        Dir.chdir(ENV['script_dir']) do
          sh("source utils/generate-banner-icons.sh && generate_ios_banner_icons  \"#{ENV['PWD']}\" \"#{params[:text]}\"")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Generate a banner on app icons using a given text"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :text,
                                       env_name: "FL_ICON_BANNER_TEXT",
                                       description: "The text that will appear on top of the app icon",
                                       verify_block: proc do |value|
                                          UI.user_error!("No text for IconBannerAction given, pass using `text: 'beta'`") unless (value and not value.empty?)
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
