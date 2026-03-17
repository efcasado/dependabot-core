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
      }]
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
      .with(/mise outdated/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
      .and_return(JSON.dump(
                    {
                      "erlang" => {
                        "name" => "erlang",
                        "requested" => "27.3.2",
                        "current" => "27.3.2",
                        "bump" => "28.0.0",
                        "latest" => "28.0.0",
                        "source" => {
                          "type" => "mise.toml",
                          "path" => File.join(Dir.pwd, "mise.toml")
                        }
                      }
                    }
                  ))
  end

  it_behaves_like "an update checker"

  describe "#latest_version" do
    it "returns the latest version from mise outdated" do
      expect(checker.latest_version).to eq("28.0.0")
    end
  end

  describe "#latest_resolvable_version" do
    it "returns the same as latest_version" do
      expect(checker.latest_resolvable_version).to eq(checker.latest_version)
    end
  end

  describe "#updated_requirements" do
    it "updates the requirement to the latest version" do
      expect(checker.updated_requirements.first[:requirement]).to eq("28.0.0")
    end
  end

  context "when mise outdated returns empty" do
    before do
      allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
        .with(/mise outdated/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
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

  context "when mise outdated fails" do
    before do
      allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
        .with(/mise outdated/, stderr_to_stdout: false, env: { "MISE_YES" => "1" })
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
        }]
      )
    end

    describe "#latest_version" do
      it "returns nil" do
        expect(checker.latest_version).to be_nil
      end
    end
  end
end
