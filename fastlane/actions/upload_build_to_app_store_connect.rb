require 'fastlane/action'
require 'digest'
require 'net/http'
require 'json'
require 'zip'
require 'plist'

module Fastlane
  module Actions
    class UploadBuildToAppStoreConnectAction < Action
      def self.run(params)
        # Get API token
        api_token = self.api_token(params)

        # Get app by bundle ID or app ID using direct API call
        app = self.find_app(params, api_token)
        UI.success("Found app: #{app['attributes']['name']} (#{app['id']})")

        # Get IPA path
        ipa_path = params[:ipa]
        unless File.exist?(ipa_path)
          UI.user_error!("IPA file not found at path: #{ipa_path}")
        end

        file_size = File.size(ipa_path)
        UI.message("IPA file size: #{(file_size / 1024.0 / 1024.0).round(2)} MB")

        # Extract build metadata from IPA
        UI.message("Extracting build metadata from IPA...")
        # Get bundle ID from app attributes
        bundle_id = app.dig('attributes', 'bundleId')
        build_metadata = self.extract_build_metadata(ipa_path, bundle_id)
        UI.message("Bundle ID: #{build_metadata[:bundle_id]}")
        UI.message("Version: #{build_metadata[:version]}")
        UI.message("Build: #{build_metadata[:build_number]}")

        # Step 1: Create build upload with build metadata
        UI.message("Creating build upload...")
        build_upload = self.create_build_upload(
          api_token, 
          app['id'], 
          params[:platform],
          build_metadata
        )
        UI.success("Build upload created: #{build_upload['id']}")

        # Step 2: Reserve build upload file
        UI.message("Reserving build upload file...")
        upload_file = self.reserve_build_upload_file(
          api_token,
          build_upload['id'],
          file_size
        )
        UI.success("Build upload file reserved: #{upload_file['id']}")

        # Step 3: Upload the IPA file
        upload_operations = upload_file.dig('attributes', 'uploadOperations')
        if upload_operations.nil? || upload_operations.empty?
          UI.user_error!("No upload operations returned from API")
        end

        UI.message("Uploading IPA file (#{upload_operations.length} chunks)...")
        self.upload_file_chunks(ipa_path, upload_operations, params[:max_upload_retries])
        UI.success("IPA file uploaded successfully")

        # Step 4: Commit the build upload file
        UI.message("Committing build upload file...")
        self.commit_build_upload_file(
          api_token,
          upload_file['id']
        )
        UI.success("Build upload file committed")

        # Step 5: Wait for processing if requested
        unless params[:skip_waiting_for_build_processing]
          UI.message("Waiting for build processing...")
          self.wait_for_build_processing(api_token, build_upload['id'], params[:processing_timeout])
        end

        UI.success("Build upload completed successfully!")
        
        return {
          build_upload_id: build_upload['id'],
          upload_file_id: upload_file['id'],
          app_id: app['id'],
          version: build_metadata[:version],
          build_number: build_metadata[:build_number]
        }
      end

      def self.extract_build_metadata(ipa_path, expected_bundle_id)
        require 'cfpropertylist'
        
        info_plist_data = nil
        
        Zip::File.open(ipa_path) do |zip_file|
          app_entries = zip_file.glob('Payload/*.app/Info.plist')
          
          if app_entries.empty?
            UI.user_error!("Could not find any Info.plist in IPA file")
          end
          
          # Find the Info.plist that matches the expected bundle ID
          matching_entry = app_entries.find do |entry|
            data = entry.get_input_stream.read
            plist = CFPropertyList::List.new(data: data)
            info = CFPropertyList.native_types(plist.value)
            info['CFBundleIdentifier'] == expected_bundle_id
          end

          if matching_entry
            info_plist_data = matching_entry.get_input_stream.read
          else
            UI.user_error!("Could not find Info.plist with bundle ID: #{expected_bundle_id}")
          end
        end
        
        # Parse the plist
        plist = CFPropertyList::List.new(data: info_plist_data)
        info = CFPropertyList.native_types(plist.value)
        
        bundle_id = info['CFBundleIdentifier']
        version = info['CFBundleShortVersionString']
        build_number = info['CFBundleVersion']
        
        unless bundle_id && version && build_number
          UI.user_error!("Could not extract required metadata from Info.plist")
        end
        
        {
          bundle_id: bundle_id,
          version: version,
          build_number: build_number
        }
      end

      def self.api_token(params)
        require 'spaceship/connect_api'
        
        # Try to get from lane_context first (set by app_store_connect_api_key action)
        existing_api_key = Actions.lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
        
        if existing_api_key
          UI.message("Using App Store Connect API Key from lane context")
          
          # If it's already a Token object, return it
          return existing_api_key if existing_api_key.is_a?(Spaceship::ConnectAPI::Token)
          
          # If it's a Hash, create a Token from it
          if existing_api_key.is_a?(Hash)
            return Spaceship::ConnectAPI::Token.create(
              key_id: existing_api_key[:key_id],
              issuer_id: existing_api_key[:issuer_id],
              key: existing_api_key[:key],
              filepath: existing_api_key[:key_filepath],
              is_key_content_base64: existing_api_key[:is_key_content_base64] || false,
              duration: existing_api_key[:duration] || 1200,
              in_house: existing_api_key[:in_house] || false
            )
          end
        end
        
        if params[:api_key_path]
          return Spaceship::ConnectAPI::Token.from_json_file(params[:api_key_path])
        elsif params[:api_key]
          return Spaceship::ConnectAPI::Token.create(**params[:api_key])
        else
          UI.user_error!("Must provide either api_key, api_key_path, or call app_store_connect_api_key first")
        end
      end

      def self.find_app(params, api_token)
        if params[:app_identifier]
          # Search by bundle identifier
          url = URI("https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=#{params[:app_identifier]}")
          response = self.make_api_request(url, api_token, :get)
          
          apps = response.dig('data')
          if apps.nil? || apps.empty?
            UI.user_error!("Could not find app with bundle ID: #{params[:app_identifier]}")
          end
          
          apps.first
        elsif params[:apple_id]
          # Get by Apple ID
          url = URI("https://api.appstoreconnect.apple.com/v1/apps/#{params[:apple_id]}")
          response = self.make_api_request(url, api_token, :get)
          
          app = response.dig('data')
          if app.nil?
            UI.user_error!("Could not find app with Apple ID: #{params[:apple_id]}")
          end
          
          app
        else
          UI.user_error!("Must provide either app_identifier or apple_id")
        end
      end

      def self.create_build_upload(api_token, app_id, platform, build_metadata)
        url = URI("https://api.appstoreconnect.apple.com/v1/buildUploads")
        
        body = {
          data: {
            type: "buildUploads",
            attributes: {
              platform: platform,
              cfBundleShortVersionString: build_metadata[:version],
              cfBundleVersion: build_metadata[:build_number]
            },
            relationships: {
              app: {
                data: {
                  type: "apps",
                  id: app_id
                }
              }
            }
          }
        }

        response = self.make_api_request(url, api_token, :post, body)
        response['data']
      end

      def self.reserve_build_upload_file(api_token, build_upload_id, file_size)
        url = URI("https://api.appstoreconnect.apple.com/v1/buildUploadFiles")
        
        body = {
          data: {
            type: "buildUploadFiles",
            attributes: {
              fileName: "app.ipa",
              fileSize: file_size,
              uti: "com.apple.ipa",
              assetType: "ASSET"
            },
            relationships: {
              buildUpload: {
                data: {
                  type: "buildUploads",
                  id: build_upload_id
                }
              }
            }
          }
        }

        response = self.make_api_request(url, api_token, :post, body)
        response['data']
      end

      def self.upload_file_chunks(file_path, upload_operations, max_retries = 10)
        File.open(file_path, 'rb') do |file|
          upload_operations.each_with_index do |operation, index|
            offset = operation['offset']
            length = operation['length']
            
            file.seek(offset)
            chunk_data = file.read(length)
            
            # Retry logic for each chunk
            retry_count = 0
            success = false
            
            while retry_count <= max_retries && !success
              begin
                url = URI(operation['url'])
                headers = operation['requestHeaders'].map { |h| [h['name'], h['value']] }.to_h
                
                http = Net::HTTP.new(url.host, url.port)
                http.use_ssl = true
                http.read_timeout = 300
                http.open_timeout = 300
                
                request = Net::HTTP::Put.new(url)
                headers.each { |k, v| request[k] = v }
                request.body = chunk_data
                
                response = http.request(request)
                
                unless response.is_a?(Net::HTTPSuccess)
                  raise "HTTP Error: #{response.code} #{response.message}"
                end
                
                UI.message("Uploaded chunk #{index + 1}/#{upload_operations.length}")
                success = true
                
              rescue => e
                retry_count += 1
                
                if retry_count <= max_retries
                  wait_time = [2 ** retry_count, 30].min # Exponential backoff, max 30 seconds
                  UI.important("Chunk #{index + 1} upload failed (attempt #{retry_count}/#{max_retries}): #{e.message}")
                  UI.message("Retrying in #{wait_time} seconds...")
                  sleep(wait_time)
                else
                  UI.user_error!("Failed to upload chunk #{index + 1} after #{max_retries} retries: #{e.message}")
                end
              end
            end
          end
        end
      end

      def self.commit_build_upload_file(api_token, upload_file_id)
        url = URI("https://api.appstoreconnect.apple.com/v1/buildUploadFiles/#{upload_file_id}")
        
        body = {
          data: {
            type: "buildUploadFiles",
            id: upload_file_id,
            attributes: {
              uploaded: true
            }
          }
        }

        self.make_api_request(url, api_token, :patch, body)
      end

      def self.wait_for_build_processing(api_token, build_upload_id, timeout)
        start_time = Time.now
        poll_count = 0

        loop do
          poll_count += 1
          elapsed_time = Time.now - start_time

          if elapsed_time > timeout
            UI.important("Build processing timeout reached (#{timeout}s)")
            break
          end

          url = URI("https://api.appstoreconnect.apple.com/v1/buildUploads/#{build_upload_id}")
          response = self.make_api_request(url, api_token, :get)

          # Extract the nested state from the nested hash
          state_hash = response.dig('data', 'attributes', 'state')
          state = state_hash['state'] if state_hash.is_a?(Hash)

          if state.nil?
            UI.user_error!("Could not extract state from API response")
          end

          UI.message("Build processing status (poll ##{poll_count}, elapsed: #{elapsed_time.round(1)}s): #{state}")

          case state
          when 'PROCESSING_COMPLETE', 'COMPLETE'
            UI.success("Build processing completed successfully!")
            break
          when 'FAILED'
            UI.user_error!("Build processing failed")
          when 'PROCESSING', 'WAITING_FOR_UPLOAD'
            sleep(10)
          else
            UI.important("Unknown state '#{state}' - continuing to wait...")
            sleep(10)
          end
        end
      end

      def self.make_api_request(url, api_token, method, body = nil, max_retries = 3)
        retry_count = 0
        
        while retry_count <= max_retries
          begin
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.read_timeout = 300
            http.open_timeout = 300
            
            request = case method
            when :get
              Net::HTTP::Get.new(url)
            when :post
              Net::HTTP::Post.new(url)
            when :patch
              Net::HTTP::Patch.new(url)
            when :delete
              Net::HTTP::Delete.new(url)
            end
            
            # Get the token text - handle both Token objects and raw strings
            token_text = api_token.respond_to?(:text) ? api_token.text : api_token.to_s
            
            request['Authorization'] = "Bearer #{token_text}"
            request['Content-Type'] = 'application/json'
            
            if body
              request.body = body.to_json
            end
            
            response = http.request(request)
            
            unless response.is_a?(Net::HTTPSuccess)
              error_body = JSON.parse(response.body) rescue {}
              error_msg = error_body.dig('errors', 0, 'detail') || response.message
              UI.user_error!("API request failed: #{response.code} - #{error_msg}")
            end
            
            return JSON.parse(response.body)
            
          rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError, Net::ReadTimeout, Net::OpenTimeout => e
            retry_count += 1
            
            if retry_count <= max_retries
              wait_time = [2 ** retry_count, 30].min
              UI.important("API request failed (attempt #{retry_count}/#{max_retries}): #{e.class} - #{e.message}")
              UI.message("Retrying in #{wait_time} seconds...")
              sleep(wait_time)
            else
              UI.user_error!("API request failed after #{max_retries} retries: #{e.class} - #{e.message}")
            end
          end
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload an IPA build to App Store Connect using the Build Uploads API"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :ipa,
            env_name: "UPLOAD_BUILD_IPA",
            description: "Path to the IPA file to upload",
            default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH],
            optional: false,
            verify_block: proc do |value|
              UI.user_error!("Could not find IPA file at path '#{value}'") unless File.exist?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key_path,
            env_name: "APP_STORE_CONNECT_API_KEY_PATH",
            description: "Path to your App Store Connect API Key JSON file",
            optional: true,
            conflicting_options: [:api_key]
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key,
            env_name: "APP_STORE_CONNECT_API_KEY",
            description: "Your App Store Connect API Key information",
            type: Hash,
            optional: true,
            sensitive: true,
            conflicting_options: [:api_key_path]
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_identifier,
            env_name: "UPLOAD_BUILD_APP_IDENTIFIER",
            description: "The bundle identifier of your app",
            optional: true,
            code_gen_sensitive: true,
            default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
            default_value_dynamic: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :apple_id,
            env_name: "UPLOAD_BUILD_APPLE_ID",
            description: "The Apple ID of your app",
            optional: true,
            conflicting_options: [:app_identifier]
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            env_name: "UPLOAD_BUILD_PLATFORM",
            description: "The platform of the build (IOS, MAC_OS, TV_OS, VISION_OS)",
            default_value: "IOS",
            verify_block: proc do |value|
              available = ["IOS", "MAC_OS", "TV_OS", "VISION_OS", "WATCH_OS"]
              UI.user_error!("Invalid platform. Must be one of: #{available.join(', ')}") unless available.include?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :skip_waiting_for_build_processing,
            env_name: "UPLOAD_BUILD_SKIP_WAITING_FOR_PROCESSING",
            description: "Skip waiting for build processing to complete",
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :processing_timeout,
            env_name: "UPLOAD_BUILD_PROCESSING_TIMEOUT",
            description: "Timeout for waiting for build processing (in seconds)",
            default_value: 3600,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :max_upload_retries,
            env_name: "UPLOAD_BUILD_MAX_UPLOAD_RETRIES",
            description: "Maximum number of retries for uploading chunks",
            default_value: 10,
            type: Integer
          )
        ]
      end

      def self.return_value
        "Hash containing build_upload_id, upload_file_id, app_id, version, and build_number"
      end

      def self.authors
        ["Jean-Philippe Martin"]
      end

      def self.is_supported?(platform)
        [:ios, :mac, :tvos, :watchos, :visionos].include?(platform)
      end

      def self.example_code
        [
          'upload_build_to_app_store_connect(
            ipa: "./MyApp.ipa",
            api_key_path: "./AuthKey.json",
            app_identifier: "com.example.myapp",
            platform: "IOS"
          )',
          'upload_build_to_app_store_connect(
            api_key: {
              key_id: "D383AB000",
              issuer_id: "6053b7fe-68a8-6acb-00be-165aa0000000",
              key_filepath: "./AuthKey_D383SF000.p8"
            },
            apple_id: "1234567890",
            skip_waiting_for_build_processing: true,
            max_upload_retries: 10
          )'
        ]
      end

      def self.category
        :beta
      end
    end
  end
end
