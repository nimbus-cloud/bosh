require 'common/version/semi_semantic_version'

module Bosh::Common::Version
  class ReleaseVersion < SemiSemanticVersion

    DEFAULT_POST_RELEASE_SEGMENT = SemiSemantic::VersionSegment.parse('dev.1')

    def self.parse(version)
      raise ArgumentError, 'Invalid Version: nil' if version.nil?
      version = version.to_s

      #convert old-style dev version suffix to new dev post-release segment
      matches = /\A(?<release>.*)(\.(?<dev>[0-9]+)-dev)\z/.match(version)
      unless matches.nil?
        version = matches[:release] + "+dev." + matches[:dev]
      end

      self.new(SemiSemantic::Version.parse(version))
    end

    def to_old_format
      matches = /\A(?<release>.*)(\+dev\.(?<dev>[0-9]+))\z/.match(to_s)
      if matches.nil?
        return nil
      end
      matches[:release] + '.' + matches[:dev] + "-dev"
    end

    private

    def default_post_release_segment
      DEFAULT_POST_RELEASE_SEGMENT
    end
  end
end
