# typed: strict
# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/mise/helpers"
require "dependabot/shared_helpers"
require "json"

module Dependabot
  module Mise
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      extend T::Sig
      include Dependabot::Mise::Helpers

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_version
        @latest_version ||= T.let(fetch_latest_version, T.nilable(T.any(String, Gem::Version)))
      end

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_resolvable_version
        latest_version
      end

      sig { override.returns(T.nilable(String)) }
      def latest_resolvable_version_with_no_unlock
        dependency.version
      end

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def updated_requirements
        return dependency.requirements if latest_version.nil?

        dependency.requirements.map do |req|
          req.merge(requirement: latest_version.to_s)
        end
      end

      private

      sig { returns(T.nilable(String)) }
      def fetch_latest_version
        entry = run_mise_outdated[dependency.name]
        return nil if entry.nil?
        return nil unless entry.dig("source", "path") == File.join(Dir.pwd, "mise.toml")

        version = entry["bump"]
        return nil if version.nil? || version == "[NONE]"

        version
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def run_mise_outdated
        @run_mise_outdated ||= T.let(
          begin
            Dependabot::SharedHelpers.in_a_temporary_directory do
              write_manifest_files(dependency_files)

              raw = Dependabot::SharedHelpers.run_shell_command(
                "mise outdated --bump --json #{dependency.name}",
                stderr_to_stdout: false,
                env: { "MISE_YES" => "1" }
              )

              JSON.parse(raw)
            end
          rescue Dependabot::SharedHelpers::HelperSubprocessFailed => e
            Dependabot.logger.warn("mise outdated failed for #{dependency.name}: #{e.message}")
            {}
          rescue JSON::ParserError => e
            Dependabot.logger.warn("mise outdated returned invalid JSON for #{dependency.name}: #{e.message}")
            {}
          end,
          T.nilable(T::Hash[String, T.untyped])
        )
      end

      sig { override.returns(T::Boolean) }
      def latest_version_resolvable_with_full_unlock?
        false
      end

      sig { override.returns(T::Array[Dependabot::Dependency]) }
      def updated_dependencies_after_full_unlock
        []
      end
    end
  end
end

Dependabot::UpdateCheckers.register("mise", Dependabot::Mise::UpdateChecker)
