# typed: strong
# frozen_string_literal: true

# NOTE: This file was scaffolded automatically but is OPTIONAL.
# If you don't need custom metadata finding logic (changelogs, release notes, etc.),
# you can safely delete this file and remove the require from lib/dependabot/mise.rb

require "dependabot/metadata_finders"
require "dependabot/metadata_finders/base"

module Dependabot
  module Mise
    class MetadataFinder < Dependabot::MetadataFinders::Base
      extend T::Sig

      private

      sig { override.returns(T.nilable(Dependabot::Source)) }
      def look_up_source
        nil
      end
    end
  end
end

Dependabot::MetadataFinders.register("mise", Dependabot::Mise::MetadataFinder)
