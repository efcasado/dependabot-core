# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/mise/update_checker"
require_common_spec "update_checkers/shared_examples_for_update_checkers"

RSpec.describe Dependabot::Mise::UpdateChecker do
  let(:mise_toml) do
    Dependabot::DependencyFile.new(
      name: "mise.toml",
      content: <<~TOML
        [tools]
        erlang = "27.3.2"
      TOML
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: "erlang",
      version: "27.3.2",
      package_manager: "mise",
      requirements: [{
        requirement: "27.3.2",
        file: "mise.toml",
        groups: [],
        source: nil
      }],
      metadata: {
        bump_version: "0.0.0"
      }
    )
  end

  let(:checker) do
    described_class.new(
      dependency: dependency,
      dependency_files: [mise_toml],
      credentials: [],
      ignored_versions: [],
      raise_on_ignored: false
    )
  end

  before do
    allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
      .with(/mise ls-remote/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
      .and_return(JSON.dump(
                    [
                      { "version" => "27.3.2", "created_at" => "2026-01-13T20:06:42.23Z", "rolling" => false },
                      { "version" => "28.4.1", "created_at" => "2026-03-12T19:32:23.78Z", "rolling" => false }
                    ]
                  ))
  end

  it_behaves_like "an update checker"

  describe "#latest_version" do
    it "returns the latest version from mise ls-remote" do
      expect(checker.latest_version).to eq("28.4.1")
    end
  end

  describe "#latest_resolvable_version" do
    it "returns the same as latest_version" do
      expect(checker.latest_resolvable_version).to eq(checker.latest_version)
    end
  end

  describe "#updated_requirements" do
    it "updates the requirement to the latest version" do
      expect(checker.updated_requirements.first[:requirement]).to eq("28.4.1")
    end
  end

  context "when mise ls-remote returns empty" do
    before do
      allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
        .with(/mise ls-remote/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
        .and_return("{}")
    end

    describe "#latest_version" do
      it "returns nil" do
        expect(checker.latest_version).to be_nil
      end
    end

    describe "#updated_requirements" do
      it "returns the original requirements unchanged" do
        expect(checker.updated_requirements).to eq(dependency.requirements)
      end
    end
  end

  context "when mise ls-remote fails" do
    before do
      allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
        .with(/mise ls-remote/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
        .and_raise(Dependabot::SharedHelpers::HelperSubprocessFailed.new(
                     message: "mise not found",
                     error_context: {}
                   ))
    end

    describe "#latest_version" do
      it "returns nil gracefully" do
        expect(checker.latest_version).to be_nil
      end
    end
  end

  context "when dependency has a fuzzy version pin" do
    let(:dependency) do
      Dependabot::Dependency.new(
        name: "node",
        version: "latest",
        package_manager: "mise",
        requirements: [{
          requirement: "latest",
          file: "mise.toml",
          groups: [],
          source: nil
        }],
        metadata: {
          bump_version: nil
        }
      )
    end

    describe "#latest_version" do
      it "returns nil" do
        expect(checker.latest_version).to be_nil
      end
    end
  end
end
