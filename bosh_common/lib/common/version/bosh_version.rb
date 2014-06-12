require 'common/version/semi_semantic_version'

module Bosh::Common::Version
  class BoshVersion < SemiSemanticVersion

    def self.parse(version)
      raise ArgumentError, 'Invalid Version: nil' if version.nil?
      version = version.to_s

      #discard anything after a space, including the space, to support compound bosh versions
      version = version.split(' ', 2)[0] if version =~ / /

      self.new(SemiSemantic::Version.parse(version))
    end

    private

    def default_post_release_segment
      raise NotImplementedError, 'Bosh post-release versions unsupported'
    end
  end
end
