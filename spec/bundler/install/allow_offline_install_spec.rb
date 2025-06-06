# frozen_string_literal: true

RSpec.describe "bundle install with :allow_offline_install" do
  before do
    bundle "config set allow_offline_install true"
  end

  context "with no cached data locally" do
    it "still installs" do
      install_gemfile <<-G, artifice: "compact_index"
        source "http://testgemserver.local"
        gem "myrack-obama"
      G
      expect(the_bundle).to include_gem("myrack 1.0")
    end

    it "still fails when the network is down" do
      install_gemfile <<-G, artifice: "fail", raise_on_error: false
        source "http://testgemserver.local"
        gem "myrack-obama"
      G
      expect(err).to include("Could not reach host testgemserver.local.")
      expect(the_bundle).to_not be_locked
    end
  end

  context "with cached data locally" do
    it "will install from the compact index" do
      system_gems ["myrack-1.0.0"], path: default_bundle_path

      bundle "config set clean false"
      install_gemfile <<-G, artifice: "compact_index"
        source "http://testgemserver.local"
        gem "myrack-obama"
        gem "myrack", "< 1.0"
      G

      expect(the_bundle).to include_gems("myrack-obama 1.0", "myrack 0.9.1")

      gemfile <<-G
        source "http://testgemserver.local"
        gem "myrack-obama"
      G

      bundle :update, artifice: "fail", all: true
      expect(stdboth).to include "Using the cached data for the new index because of a network error"

      expect(the_bundle).to include_gems("myrack-obama 1.0", "myrack 1.0.0")
    end

    def break_git_remote_ops!
      FileUtils.mkdir_p(tmp("broken_path"))
      File.open(tmp("broken_path/git"), "w", 0o755) do |f|
        f.puts <<~RUBY
          #!/usr/bin/env ruby
          fetch_args = %w(fetch --force --quiet --no-tags)
          clone_args = %w(clone --bare --no-hardlinks --quiet)

          if (fetch_args.-(ARGV).empty? || clone_args.-(ARGV).empty?) && File.exist?(ARGV[ARGV.index("--") + 1])
            warn "git remote ops have been disabled"
            exit 1
          end
          ENV["PATH"] = ENV["PATH"].sub(/^.*?:/, "")
          exec("git", *ARGV)
        RUBY
      end

      old_path = ENV["PATH"]
      ENV["PATH"] = "#{tmp("broken_path")}:#{ENV["PATH"]}"
      yield if block_given?
    ensure
      ENV["PATH"] = old_path if block_given?
    end

    it "will install from a cached git repo" do
      skip "doesn't print errors" if Gem.win_platform?

      git = build_git "a", "1.0.0", path: lib_path("a")
      update_git("a", path: git.path, branch: "new_branch")
      install_gemfile <<-G
        source "https://gem.repo1"
        gem "a", :git => #{git.path.to_s.dump}
      G

      break_git_remote_ops! { bundle :update, all: true }
      expect(err).to include("Using cached git data because of network errors")
      expect(the_bundle).to be_locked

      break_git_remote_ops! do
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "a", :git => #{git.path.to_s.dump}, :branch => "new_branch"
        G
      end
      expect(err).to include("Using cached git data because of network errors")
      expect(the_bundle).to be_locked
    end
  end
end
