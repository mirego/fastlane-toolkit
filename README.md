# Fastlane boilerplate
This project provides a base Fastfile to minimize the amount of configuration required to build a project on Jenkins using manual signing with fastlane.

## What's included?
The base Fastfile provides basic model classes to make it easier to work with. These classes includes:
- Project
- Configuration
  - Certificate
  - ProvisioningProfile

A build is produced by providing a `Project` object with a `Configuration` object. To sign a build using Mirego's enterprise certificate, a `betaConfiguration` object is declared for you containing all the needed information about the certificate and the provisioning profile.

Important to note that this Fastfile is just a starting point, if you need more flexibility or more advanced features I encourage you to use fastlane as it pleases you.

## Usage
Start by importing the boilerplate and defining your project by creating a `Project` instance describing what's contained in your repository.

```ruby
import_from_git(url: "git@github.com:mirego/fastlane-boilerplate.git")

sampleProject = Model::Project.new(
  workspacePath: "Sample.xcworkspace",
  projectPath: "Sample.xcodeproj",
  infoPlistPath: "Sample/Info.plist",
  scheme: "Sample",
  target: "Sample",
  bundleIdentifier: "com.mirego.Sample"
)
```

Once it's done, create a lane that import the boilerplate and that calls the provided `build` lane with your project and the provided `betaConfiguration`.

```ruby
desc "Build using the enterprise certificate and publish on HockeyApp"
lane :beta do
  build(project: sampleProject, configuration: betaConfiguration)
  changelog_from_git_commits(commits_count: 10)
  hockey(
    api_token: ENV["HOCKEYAPP_API_TOKEN"].strip_quotes,
    public_identifier: "PUT_YOUR_APP_IDENTIFIER_HERE",
    notify: "0"
  )
end
```

### Custom certificate
If you need to sign your build using a custom signing certificate, create your custom configuration object and call the `build` lane with it.

```ruby
appStoreProvisioningProfile = Model::ProvisioningProfile.new(
  path: "./fastlane/provisioning/AppStore.mobileprovision"
)

appStoreCertificate = Model::Certificate.new(
  path: "./fastlane/provisioning/AppStore.p12",
  name: "iPhone Distribution: Sample (????????)",
  password: "SuperStrongPassword"
)

appStoreConfiguration = Model::Configuration.new(
  certificate: appStoreCertificate,
  provisioningProfile: appStoreProvisioningProfile,
  buildConfiguration: "Release",
  exportMethod: "app-store"
)

lane :release do
  build(project: sampleProject, configuration: appStoreConfiguration)
  upload_to_app_store(force: true)
  slack(message: "Successfully submitted #{sampleProject.target} to AppStore", slack_url: "https://hooks.slack.com/services/T025F65SP/AAW2V1FC3/rgMjwWCk21ag79rjdhbfDS78G")
end
```

### Bundle identifier override
If you need to change the bundle identifier of your app before building it, simply assign the `bundleIdentifierOverride` property of your configuration object prior to calling the `build` lane.

```ruby
betaConfiguration.bundleIdentifierOverride = "com.mirego.Sample.beta"
```

## Custom Actions
The project also includes some custom actions described here.

### install_provisioning_profile
Internally required by the `build` private lane, the `install_provisioning_profile` action take care of parsing the provisioning profile and install it in the proper location so that Xcode can use it.

### icon_banner
WIP - Do not work at the moment

## Contributing
If you find that something else could be useful or if your use case is not covered and you feel that it could benefit others, please take the time to contribute by opening a pull request or open an issue asking for it very very kindly ;)
