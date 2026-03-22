# typed: strict
# frozen_string_literal: true

require "dependabot/dependency"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/mise/helpers"
require "dependabot/shared_helpers"
require "json"

module Dependabot
  module Mise
    class FileParser < Dependabot::FileParsers::Base
      extend T::Sig
      include Dependabot::Mise::Helpers

      sig { override.returns(T::Array[Dependabot::Dependency]) }
      def parse
        Dependabot::SharedHelpers.in_a_temporary_directory do
          write_manifest_files(dependency_files)

          raw = Dependabot::SharedHelpers.run_shell_command(
            "mise outdated --bump --json",
            stderr_to_stdout: false,
            env: { "MISE_YES" => "1" }
          )

          JSON.parse(raw).filter_map do |tool_name, entry|
            next unless entry
            next unless entry.dig("source", "path") == File.join(Dir.pwd, "mise.toml")

            requested = entry["requested"]
            bump = entry["bump"]

            build_dependency(tool_name, requested, bump)
          end
        end
      rescue Dependabot::SharedHelpers::HelperSubprocessFailed => e
        Dependabot.logger.warn("mise outdated failed: #{e.message}")
        []
      rescue JSON::ParserError => e
        Dependabot.logger.warn("mise outdated returned invalid JSON: #{e.message}")
        []
      end

      private

      sig do
        params(name: String, version: String, bump_version: T.nilable(String))
          .returns(Dependabot::Dependency)
      end
      def build_dependency(name, version, bump_version)
        Dependabot::Dependency.new(
          name: name,
          version: version,
          package_manager: "mise",
          requirements: [{
            requirement: version,
            file: "mise.toml",
            groups: [],
            source: nil
          }],
          metadata: {
            bump_version: bump_version
          }
        )
      end

      sig { override.void }
      def check_required_files
        return if get_original_file("mise.toml")

        raise "No mise.toml file found!"
      end
    end
  end
end

Dependabot::FileParsers.register("mise", Dependabot::Mise::FileParser)
