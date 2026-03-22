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
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with(/mise outdated/, hash_including(stderr_to_stdout: false))
          .and_return(JSON.dump(
                        {
                          "erlang" => {
                            "name" => "erlang",
                            "requested" => "27.3.2",
                            "current" => nil,
                            "bump" => "28.4.1",
                            "latest" => "28.4.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "elixir" => {
                            "name" => "elixir",
                            "requested" => "1.18.4-otp-27",
                            "current" => nil,
                            "bump" => "1.19.5-otp-28",
                            "latest" => "1.19.5-otp-28",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "helm" => {
                            "name" => "helm",
                            "requested" => "3.17.3",
                            "current" => nil,
                            "bump" => "4.1.3",
                            "latest" => "4.1.3",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          }
                        }
                      ))
      end

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
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with(/mise outdated/, hash_including(stderr_to_stdout: false))
          .and_return(JSON.dump(
                        {
                          "node" => {
                            "name" => "node",
                            "requested" => "20",
                            "current" => nil,
                            "bump" => "25",
                            "latest" => "25.8.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "erlang" => {
                            "name" => "erlang",
                            "requested" => "27.3.2",
                            "current" => nil,
                            "bump" => "28.4.1",
                            "latest" => "28.4.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "npm:@redocly/cli" => {
                            "name" => "npm:@redocly/cli",
                            "requested" => "2.19.1",
                            "current" => nil,
                            "bump" => "2.24.1",
                            "latest" => "2.24.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "python" => {
                            "name" => "python",
                            "requested" => "latest",
                            "current" => nil,
                            "bump" => nil,
                            "latest" => "3.14.3",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "helm" => {
                            "name" => "helm",
                            "requested" => "3.17.3",
                            "current" => nil,
                            "bump" => "4.1.3",
                            "latest" => "4.1.3",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "ruby" => {
                            "name" => "ruby",
                            "requested" => "3.3.0",
                            "current" => nil,
                            "bump" => "4.0.2",
                            "latest" => "4.0.2",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "go" => {
                            "name" => "go",
                            "requested" => "1.18",
                            "current" => nil,
                            "bump" => "1.26",
                            "latest" => "1.26.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          }
                        }
                      ))
      end

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
          "npm:@redocly/cli",
          "node",
          "python",
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

    context "with fuzzy version formats" do
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with(/mise outdated/, hash_including(stderr_to_stdout: false))
          .and_return(JSON.dump(
                        {
                          "node" => {
                            "name" => "node",
                            "requested" => "20",
                            "current" => nil,
                            "bump" => "25",
                            "latest" => "25.8.1",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "python" => {
                            "name" => "python",
                            "requested" => "latest",
                            "current" => nil,
                            "bump" => nil,
                            "latest" => "3.14.3",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          },
                          "ruby" => {
                            "name" => "ruby",
                            "requested" => "lts",
                            "current" => nil,
                            "bump" => nil,
                            "latest" => "4.0.2",
                            "source" => {
                              "type" => "mise.toml",
                              "path" => "mise.toml"
                            }
                          }
                        }
                      ))
      end

      let(:mise_toml) do
        Dependabot::DependencyFile.new(
          name: "mise.toml",
          content: fixture("mise_toml/fuzzy.toml")
        )
      end

      it "returns all tools regardless of version format" do
        expect(dependencies.map(&:name)).to contain_exactly(
          "node",
          "python",
          "ruby"
        )
      end

      it "preserves the version string as-is" do
        node = dependencies.find { |d| d.name == "node" }
        expect(node.version).to eq("20")
      end
    end
  end
end
