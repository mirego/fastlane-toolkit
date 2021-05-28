# Fastlane toolkit
This project provides a base Fastfile to minimize the amount of configuration required to build a project on CI using manual signing with fastlane.

## What's included?
The base Fastfile provides basic model classes to make it easier to work with. These classes includes:
- Project
  - AppExtension
- Configuration
  - Certificate
  - ProvisioningProfile

A build is produced by providing a `Project` object with a `Configuration` object. To sign a build using Mirego's enterprise certificate, a `betaConfiguration` object is declared for you containing all the needed information about the certificate and the provisioning profile.

Important to note that this Fastfile is just a starting point, if you need more flexibility or more advanced features I encourage you to use fastlane as it pleases you.

## Usage
Start by importing the toolkit at the very top of your Fastfile and defining your project by creating a `Project` instance describing what's contained in your repository.

```ruby
import_from_git(url: "git@github.com:mirego/fastlane-toolkit.git")

# ...

sampleProject = Model::Project.new(
  workspacePath: "Sample.xcworkspace",
  projectPath: "Sample.xcodeproj",
  infoPlistPath: "Sample/Info.plist",
  scheme: "Sample",
  target: "Sample",
  bundleIdentifier: "com.mirego.Sample"
)
```

Once it's done, create a lane that import the toolkit and that calls the provided `build` lane with your project. You can either explicitly specify the enterprise configuration by calling `build(project: sampleProject, configuration: enterprise_configuration())` or simply omit the configuration parameter as it is the default value when none is supplied.

```ruby
desc "Build using the enterprise certificate and publish on HockeyApp"
lane :beta do
  cocoapods(use_bundle_exec: true, try_repo_update_on_error: true)
  build(project: sampleProject)
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

You can also simply re-assign the bundle identifier of your `Project` instance.
```ruby
sampleProject.bundleIdentifier = "com.mirego.Sample.beta"
```

### App extensions
If your app contains app extensions, you must provide them via your `Project` instance.

```ruby
notificationExtension = Model::AppExtension.new(
  target: "SampleNotifications",
  bundleIdentifier: "com.mirego.Sample.notifications",
  infoPlistPath: "SampleNotifications/Info.plist"
)
sampleProject.extensions = [notificationExtension]
```

You also need to provide the provisioning profile to use for each of the registered app extensions in your configuration. The property takes a `Hash` (key value pair) of the extension bundle identifier to a `ProvisioningProfile` instance.

```ruby
notificationExtensionProvisioningProfile = Model::ProvisioningProfile.new(
  path: "./fastlane/provisioning/AppStoreNotifications.mobileprovision"
)
configuration.extensionProvisioningProfiles = {
  notificationExtension.bundleIdentifier => notificationExtensionProvisioningProfile
}
```

### Bitcode
Bitcode is enabled by default but if for some reason you need it disabled, you can do so with the `include_bitcode` option.
```ruby
build(project: sampleProject, configuration: configuration, include_bitcode: false)
```

### Xcode environment variables
If you need to provide Xcode extra environment variables, you can do so using the `xcargs` option of the `build` action. This is the equivalent of the `BUILD_EXTRA_XCODE_ENV` variable when using the `build-ios.sh` script.

```ruby
build(project: sampleProject, configuration: configuration, xcargs: "ENABLE_CONFIG_PANEL=true")
```

## Custom Actions
The project also includes some custom actions described here.

### enterprise_configuration
Create a configuration containing a generic provisioning profile and the enterprise certificate. This action take care of extracting informations in environment variables and must be run on Jenkins in order to work.

### install_provisioning_profile
Internally required by the `build` private lane, the `install_provisioning_profile` action take care of parsing the provisioning profile and install it in the proper location so that Xcode can use it.

## Plugins

### icon_banner
Use icon_badge plugin to add badge icon to your application icon.

To install:

```
bundle exec fastlane add_plugin icon_banner
```
[documentation](https://github.com/ebelair/icon-banner)

## Jenkins Configuration
### Required options
- Prepare an environment for the run
  - Keep Jenkins Environment Variables
  - Keep Jenkins Build Variables
  - Properties File Path: `${HOME}/.build_ios_env`

- Build
  - Execute shell
    ```
    bundle install
    bundle exec fastlane beta
    ```

### Recommended options
- Color ANSI Console Output: `xterm`

### Jenkins DSL Example
```groovy
String clientName = 'client'
String projectDisplayName = 'Sample'
String projectName = 'sample'
String folderName = 'Client Display Name'
String slackNotificationChannel = '#project-channel'

folder("$folderName") {
    description('Jobs related to ' + clientName.capitalize())
}

job("$folderName/$clientName-$projectName-watcher") {
    description("Repository watcher for master branch of the $projectDisplayName mobile app")
    scm {
        git {
            branch('origin/master')
            remote {
                name('origin')
                url("${GIT_URL}")
                credentials('github')
            }
            extensions {
                submoduleOptions {
                  recursive()
                }
            }
        }
    }
    triggers {
        scm('H/5 * * * *')
    }
    steps {
        triggerBuilder {
            configs {
                blockableBuildTriggerConfig {
                    projects("$folderName/$clientName-$projectName-ios-fastlane")
                    block {
                        buildStepFailureThreshold("never")
                        unstableThreshold("never")
                        failureThreshold("never")
                    }
                    configs {
                        predefinedBuildParameters {
                            textParamValueOnNewLine(false)
                            properties('''Branch=${GIT_BRANCH}
Lane=beta''')
                        }
                    }
                }
            }
        }
    }
}

job("$folderName/$clientName-$projectName-ios-fastlane") {
    description("Builds $projectDisplayName Sample iOS app")
    logRotator {
        numToKeep(5)
    }
    parameters {
        stringParam {
            name('Branch')
            defaultValue('origin/master')
            description('The git branch to be built')
            trim(true)
        }
        choiceParam('Lane', ['beta', 'app_store'], 'Name of the lane to run in fastlane')
    }
    environmentVariables {
        keepBuildVariables(true)
        keepSystemVariables(true)
        propertiesFile('${HOME}/.build_ios_env')
    }
    scm {
        git {
            branch('${Branch}')
            remote {
                name('origin')
                url("${GIT_URL}")
                credentials('github')
            }
            extensions {
                submoduleOptions {
                    recursive(true)
                }
                wipeOutWorkspace()
            }
        }
    }
    steps {
        shell('''bundle install
bundle exec fastlane ${Lane}''')
    }
    wrappers {
        colorizeOutput()
    }
    publishers {
        jUnitResultArchiver {
            testResults('fastlane/test_output/report.junit')
        }
        cobertura('cobertura.xml') {
            failNoReports(false)
            sourceEncoding('ASCII')

            methodTarget(80, 0, 0)
            lineTarget(80, 0, 0)
            conditionalTarget(70, 0, 0)
        }
        slackNotifier {
            notifyBackToNormal(true)
            notifyFailure(true)
            room(slackNotificationChannel)
        }
    }
}
```

## Contributing
If you find that something else could be useful or if your use case is not covered and you feel that it could benefit others, please take the time to contribute by opening a pull request or open an issue asking for it very very kindly ;)
