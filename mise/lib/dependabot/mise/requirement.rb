# typed: strong
# frozen_string_literal: true

# NOTE: This file was scaffolded automatically but is OPTIONAL.
# If your ecosystem uses standard Gem::Requirement logic,
# you can safely delete this file and remove the require from lib/dependabot/mise.rb
require "dependabot/requirement"
require "dependabot/utils"

module Dependabot
  module Mise
    class Requirement < Dependabot::Requirement
      extend T::Sig

      # Add custom requirement parsing logic if needed
      # If standard Gem::Requirement is sufficient, delete this file
      # This abstract method must be implemented
      sig do
        override
          .params(requirement_string: T.nilable(String))
          .returns(T::Array[Dependabot::Requirement])
      end
      def self.requirements_array(requirement_string)
        [new(requirement_string)]
      end
    end
  end
end

Dependabot::Utils.register_requirement_class("mise", Dependabot::Mise::Requirement)
