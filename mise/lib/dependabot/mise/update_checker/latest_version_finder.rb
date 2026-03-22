# typed: strict
# frozen_string_literal: true

require "dependabot/package/package_latest_version_finder"
require "dependabot/mise/helpers"
require "dependabot/shared_helpers"
require "json"

module Dependabot
  module Mise
    class UpdateChecker
      class LatestVersionFinder < Dependabot::Package::PackageLatestVersionFinder
        extend T::Sig
        include Dependabot::Mise::Helpers

        sig do
          params(
            dependency: Dependabot::Dependency,
            dependency_files: T::Array[Dependabot::DependencyFile],
            credentials: T::Array[Dependabot::Credential],
            ignored_versions: T::Array[String],
            security_advisories: T::Array[Dependabot::SecurityAdvisory],
            raise_on_ignored: T::Boolean,
            cooldown_options: T.nilable(Dependabot::Package::ReleaseCooldownOptions)
          ).void
        end
        def initialize(
          dependency:,
          dependency_files:,
          credentials:,
          ignored_versions:,
          security_advisories:,
          raise_on_ignored:,
          cooldown_options: nil
        )
          @dependency = dependency
          @dependency_files = dependency_files
          @credentials = credentials
          @ignored_versions = ignored_versions
          @security_advisories = security_advisories
          @raise_on_ignored = raise_on_ignored
          @cooldown_options = cooldown_options
          super
        end

        PRERELEASE_PATTERN = T.let(
          /[-.]?(rc|alpha|beta|preview|dev|nightly|pre)\d*/i,
          Regexp
        )

        sig { returns(Dependabot::Dependency) }
        attr_reader :dependency

        sig { returns(T::Array[Dependabot::Credential]) }
        attr_reader :credentials

        sig { returns(T.nilable(Dependabot::Package::ReleaseCooldownOptions)) }
        attr_reader :cooldown_options

        sig { returns(T::Array[String]) }
        attr_reader :ignored_versions

        sig { returns(T::Array[Dependabot::SecurityAdvisory]) }
        attr_reader :security_advisories

        sig { override.returns(T.nilable(Dependabot::Package::PackageDetails)) }
        def package_details; end

        sig { params(language_version: T.nilable(T.any(Dependabot::Version, String))).returns(T.nilable(Dependabot::Version)) }
        def latest_version(language_version: nil)
          _language_version = language_version
          releases = package_releases
          return nil if releases.nil? || releases.empty?

          releases = filter_ignored_versions(releases)
          releases = filter_by_cooldown(releases)
          releases.max_by(&:version)&.version
        end

        private

        sig { override.returns(T::Boolean) }
        def cooldown_enabled?
          true
        end

        sig { returns(T.nilable(T::Array[Dependabot::Package::PackageRelease])) }
        def package_releases
          @package_releases ||= T.let(
            fetch_releases,
            T.nilable(T::Array[Dependabot::Package::PackageRelease])
          )
        end

        sig { returns(T::Array[Dependabot::Package::PackageRelease]) }
        def fetch_releases
          Dependabot::SharedHelpers.in_a_temporary_directory do
            write_manifest_files(dependency_files)

            raw = Dependabot::SharedHelpers.run_shell_command(
              "mise ls-remote --json #{dependency.name}",
              stderr_to_stdout: false,
              env: { "MISE_YES" => "1" }
            )

            JSON.parse(raw).filter_map do |entry|
              version = entry["version"]
              next unless version
              # Skip prereleases unless the current version is also a prerelease
              next if prerelease?(version) && !wants_prerelease?

              released_at = entry["created_at"] ? Time.parse(entry["created_at"]) : nil

              Dependabot::Package::PackageRelease.new(
                version: Dependabot::Version.new(version),
                released_at: released_at
              )
            end
          end
        rescue StandardError
          []
        end

        sig { returns(T.class_of(Dependabot::Version)) }
        def version_class
          dependency.version_class
        end

        sig { returns(T::Boolean) }
        def wants_prerelease?
          current = dependency.version
          return false unless current

          prerelease?(current.to_s)
        end

        sig { params(version: String).returns(T::Boolean) }
        def prerelease?(version)
          PRERELEASE_PATTERN.match?(version)
        end
      end
    end
  end
end
