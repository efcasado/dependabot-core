# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_file"
require "dependabot/mise/file_parser"
require_common_spec "file_parsers/shared_examples_for_file_parsers"

RSpec.describe Dependabot::Mise::FileParser do
  subject(:parser) do
    described_class.new(
      dependency_files: dependency_files,
      source: source
    )
  end

  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "example/mise-project",
      directory: "/"
    )
  end

  let(:dependency_files) { [mise_toml] }

  let(:mise_toml) do
    Dependabot::DependencyFile.new(
      name: "mise.toml",
      content: fixture("mise_toml/simple.toml")
    )
  end

  it_behaves_like "a dependency file parser"

  describe "#parse" do
    subject(:dependencies) { parser.parse }

    context "with simple exact versions" do
      it "returns the correct number of dependencies" do
        expect(dependencies.length).to eq(3)
      end

      it "parses tool names correctly" do
        expect(dependencies.map(&:name)).to contain_exactly("erlang", "elixir", "helm")
      end

      it "parses versions correctly" do
        versions = dependencies.to_h { |d| [d.name, d.version] }
        expect(versions).to eq(
          "erlang" => "27.3.2",
          "elixir" => "1.18.4-otp-27",
          "helm" => "3.17.3"
        )
      end

      it "sets the package manager" do
        expect(dependencies.map(&:package_manager).uniq).to eq(["mise"])
      end
    end

    context "with no tools section" do
      let(:mise_toml) do
        Dependabot::DependencyFile.new(
          name: "mise.toml",
          content: fixture("mise_toml/no_tools.toml")
        )
      end

      it "returns no dependencies" do
        expect(dependencies).to be_empty
      end
    end

    context "with mixed version formats" do
      let(:mise_toml) do
        Dependabot::DependencyFile.new(
          name: "mise.toml",
          content: fixture("mise_toml/mixed.toml")
        )
      end

      it "returns dependencies for all tools regardless of version format" do
        expect(dependencies.map(&:name)).to contain_exactly(
          "erlang",
          "helm",
          "node",
          "python",
          "npm:@redocly/cli",
          "ruby",
          "go"
        )
      end

      it "parses the inline table version correctly" do
        ruby = dependencies.find { |d| d.name == "ruby" }
        expect(ruby.version).to eq("3.3.0")
      end

      it "parses plain string versions correctly" do
        erlang = dependencies.find { |d| d.name == "erlang" }
        expect(erlang.version).to eq("27.3.2")
      end

      it "preserves fuzzy version strings as-is" do
        python = dependencies.find { |d| d.name == "python" }
        expect(python.version).to eq("latest")
      end
    end

    context "with unsupported version formats" do
      let(:mise_toml) do
        Dependabot::DependencyFile.new(
          name: "mise.toml",
          content: fixture("mise_toml/unsupported.toml")
        )
      end

      it "returns all tools regardless of version format" do
        expect(dependencies.map(&:name)).to contain_exactly(
          "node", "python", "ruby", "go"
        )
      end

      it "preserves the version string as-is" do
        node = dependencies.find { |d| d.name == "node" }
        expect(node.version).to eq("20")
      end
    end
  end
end
