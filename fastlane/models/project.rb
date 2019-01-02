module Models
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
end
