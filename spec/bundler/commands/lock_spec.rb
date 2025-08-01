# frozen_string_literal: true

RSpec.describe "bundle lock" do
  let(:expected_lockfile) do
    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "actionmailer", "2.3.2"
      c.checksum gem_repo4, "actionpack", "2.3.2"
      c.checksum gem_repo4, "activerecord", "2.3.2"
      c.checksum gem_repo4, "activeresource", "2.3.2"
      c.checksum gem_repo4, "activesupport", "2.3.2"
      c.checksum gem_repo4, "foo", "1.0"
      c.checksum gem_repo4, "rails", "2.3.2"
      c.checksum gem_repo4, "rake", rake_version
      c.checksum gem_repo4, "weakling", "0.0.3"
    end

    <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          actionmailer (2.3.2)
            activesupport (= 2.3.2)
          actionpack (2.3.2)
            activesupport (= 2.3.2)
          activerecord (2.3.2)
            activesupport (= 2.3.2)
          activeresource (2.3.2)
            activesupport (= 2.3.2)
          activesupport (2.3.2)
          foo (1.0)
          rails (2.3.2)
            actionmailer (= 2.3.2)
            actionpack (= 2.3.2)
            activerecord (= 2.3.2)
            activeresource (= 2.3.2)
            rake (= #{rake_version})
          rake (#{rake_version})
          weakling (0.0.3)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
        rails
        weakling
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  let(:outdated_lockfile) do
    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "actionmailer", "2.3.1"
      c.checksum gem_repo4, "actionpack", "2.3.1"
      c.checksum gem_repo4, "activerecord", "2.3.1"
      c.checksum gem_repo4, "activeresource", "2.3.1"
      c.checksum gem_repo4, "activesupport", "2.3.1"
      c.checksum gem_repo4, "foo", "1.0"
      c.checksum gem_repo4, "rails", "2.3.1"
      c.checksum gem_repo4, "rake", rake_version
      c.checksum gem_repo4, "weakling", "0.0.3"
    end

    <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          actionmailer (2.3.1)
            activesupport (= 2.3.1)
          actionpack (2.3.1)
            activesupport (= 2.3.1)
          activerecord (2.3.1)
            activesupport (= 2.3.1)
          activeresource (2.3.1)
            activesupport (= 2.3.1)
          activesupport (2.3.1)
          foo (1.0)
          rails (2.3.1)
            actionmailer (= 2.3.1)
            actionpack (= 2.3.1)
            activerecord (= 2.3.1)
            activeresource (= 2.3.1)
            rake (= #{rake_version})
          rake (#{rake_version})
          weakling (0.0.3)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
        rails
        weakling
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  let(:gemfile_with_rails_weakling_and_foo_from_repo4) do
    build_repo4 do
      build_gem "rake", "10.0.1"
      build_gem "rake", rake_version

      %w[2.3.1 2.3.2].each do |version|
        build_gem "rails", version do |s|
          s.executables = "rails"
          s.add_dependency "rake",           version == "2.3.1" ? "10.0.1" : rake_version
          s.add_dependency "actionpack",     version
          s.add_dependency "activerecord",   version
          s.add_dependency "actionmailer",   version
          s.add_dependency "activeresource", version
        end
        build_gem "actionpack", version do |s|
          s.add_dependency "activesupport", version
        end
        build_gem "activerecord", version do |s|
          s.add_dependency "activesupport", version
        end
        build_gem "actionmailer", version do |s|
          s.add_dependency "activesupport", version
        end
        build_gem "activeresource", version do |s|
          s.add_dependency "activesupport", version
        end
        build_gem "activesupport", version
      end

      build_gem "weakling", "0.0.3"

      build_gem "foo"
    end

    gemfile <<-G
      source "https://gem.repo4"
      gem "rails"
      gem "weakling"
      gem "foo"
    G
  end

  it "prints a lockfile when there is no existing lockfile with --print" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --print"

    expect(out).to eq(expected_lockfile.chomp)
  end

  it "prints a lockfile when there is an existing lockfile with --print" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    bundle "lock --print"

    expect(out).to eq(expected_lockfile.chomp)
  end

  it "prints a lockfile when there is an existing checksums lockfile with --print" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    bundle "lock --print"

    expect(out).to eq(expected_lockfile.chomp)
  end

  it "writes a lockfile when there is no existing lockfile" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock"

    expect(read_lockfile).to eq(expected_lockfile)
  end

  it "prints a lockfile without fetching new checksums if the existing lockfile had no checksums" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    bundle "lock --print"

    expect(out).to eq(expected_lockfile.chomp)
  end

  it "touches the lockfile when there is an existing lockfile that does not need changes" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    expect do
      bundle "lock"
    end.to change { bundled_app_lock.mtime }
  end

  it "does not touch lockfile with --print" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    expect do
      bundle "lock --print"
    end.not_to change { bundled_app_lock.mtime }
  end

  it "writes a lockfile when there is an outdated lockfile using --update" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile outdated_lockfile

    bundle "lock --update"

    expect(read_lockfile).to eq(expected_lockfile)
  end

  it "prints an updated lockfile when there is an outdated lockfile using --print --update" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile outdated_lockfile

    bundle "lock --print --update"

    expect(out).to eq(expected_lockfile.rstrip)
  end

  it "emits info messages to stderr when updating an outdated lockfile using --print --update" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile outdated_lockfile

    bundle "lock --print --update"

    expect(err).to eq(<<~STDERR.rstrip)
      Fetching gem metadata from https://gem.repo4/...
      Resolving dependencies...
    STDERR
  end

  it "writes a lockfile when there is an outdated lockfile and bundle is frozen" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile outdated_lockfile

    bundle "lock --update", env: { "BUNDLE_FROZEN" => "true" }

    expect(read_lockfile).to eq(expected_lockfile)
  end

  it "does not fetch remote specs when using the --local option" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --update --local", raise_on_error: false

    expect(err).to match(/locally installed gems/)
  end

  it "does not fetch remote checksums with --local" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    bundle "lock --print --local"

    expect(out).to eq(expected_lockfile.chomp)
  end

  it "works with --gemfile flag" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    gemfile "CustomGemfile", <<-G
      source "https://gem.repo4"
      gem "foo"
    G
    bundle "lock --gemfile CustomGemfile"

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "foo", "1.0"
    end

    lockfile = <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          foo (1.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
    expect(out).to match(/Writing lockfile to.+CustomGemfile\.lock/)
    expect(read_lockfile("CustomGemfile.lock")).to eq(lockfile)
    expect { read_lockfile }.to raise_error(Errno::ENOENT)
  end

  it "writes to a custom location using --lockfile" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --lockfile=lock"

    expect(out).to match(/Writing lockfile to.+lock/)
    expect(read_lockfile("lock")).to eq(expected_lockfile)
    expect { read_lockfile }.to raise_error(Errno::ENOENT)
  end

  it "writes to custom location using --lockfile when a default lockfile is present" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "install"
    bundle "lock --lockfile=lock"

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "actionmailer", "2.3.2"
      c.checksum gem_repo4, "actionpack", "2.3.2"
      c.checksum gem_repo4, "activerecord", "2.3.2"
      c.checksum gem_repo4, "activeresource", "2.3.2"
      c.checksum gem_repo4, "activesupport", "2.3.2"
      c.checksum gem_repo4, "foo", "1.0"
      c.checksum gem_repo4, "rails", "2.3.2"
      c.checksum gem_repo4, "rake", rake_version
      c.checksum gem_repo4, "weakling", "0.0.3"
    end

    lockfile = <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          actionmailer (2.3.2)
            activesupport (= 2.3.2)
          actionpack (2.3.2)
            activesupport (= 2.3.2)
          activerecord (2.3.2)
            activesupport (= 2.3.2)
          activeresource (2.3.2)
            activesupport (= 2.3.2)
          activesupport (2.3.2)
          foo (1.0)
          rails (2.3.2)
            actionmailer (= 2.3.2)
            actionpack (= 2.3.2)
            activerecord (= 2.3.2)
            activeresource (= 2.3.2)
            rake (= #{rake_version})
          rake (#{rake_version})
          weakling (0.0.3)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
        rails
        weakling
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L

    expect(out).to match(/Writing lockfile to.+lock/)
    expect(read_lockfile("lock")).to eq(lockfile)
  end

  it "update specific gems using --update" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "actionmailer", "2.3.1"
      c.checksum gem_repo4, "actionpack", "2.3.1"
      c.checksum gem_repo4, "activerecord", "2.3.1"
      c.checksum gem_repo4, "activeresource", "2.3.1"
      c.checksum gem_repo4, "activesupport", "2.3.1"
      c.checksum gem_repo4, "foo", "1.0"
      c.checksum gem_repo4, "rails", "2.3.1"
      c.checksum gem_repo4, "rake", "10.0.1"
      c.checksum gem_repo4, "weakling", "0.0.3"
    end

    lockfile_with_outdated_rails_and_rake = <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          actionmailer (2.3.1)
            activesupport (= 2.3.1)
          actionpack (2.3.1)
            activesupport (= 2.3.1)
          activerecord (2.3.1)
            activesupport (= 2.3.1)
          activeresource (2.3.1)
            activesupport (= 2.3.1)
          activesupport (2.3.1)
          foo (1.0)
          rails (2.3.1)
            actionmailer (= 2.3.1)
            actionpack (= 2.3.1)
            activerecord (= 2.3.1)
            activeresource (= 2.3.1)
            rake (= 10.0.1)
          rake (10.0.1)
          weakling (0.0.3)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
        rails
        weakling
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L

    lockfile lockfile_with_outdated_rails_and_rake

    bundle "lock --update rails rake"

    expect(read_lockfile).to eq(expected_lockfile)
  end

  it "updates specific gems using --update, even if that requires unlocking other top level gems" do
    build_repo4 do
      build_gem "prism", "0.15.1"
      build_gem "prism", "0.24.0"

      build_gem "ruby-lsp", "0.12.0" do |s|
        s.add_dependency "prism", "< 0.24.0"
      end

      build_gem "ruby-lsp", "0.16.1" do |s|
        s.add_dependency "prism", ">= 0.24.0"
      end

      build_gem "tapioca", "0.11.10" do |s|
        s.add_dependency "prism", "< 0.24.0"
      end

      build_gem "tapioca", "0.13.1" do |s|
        s.add_dependency "prism", ">= 0.24.0"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"

      gem "tapioca"
      gem "ruby-lsp"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4
        specs:
          prism (0.15.1)
          ruby-lsp (0.12.0)
            prism (< 0.24.0)
          tapioca (0.11.10)
            prism (< 0.24.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        ruby-lsp
        tapioca

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    bundle "lock --update tapioca --verbose"

    expect(lockfile).to include("tapioca (0.13.1)")
  end

  it "updates specific gems using --update, even if that requires unlocking other top level gems, but only as few as possible" do
    build_repo4 do
      build_gem "prism", "0.15.1"
      build_gem "prism", "0.24.0"

      build_gem "ruby-lsp", "0.12.0" do |s|
        s.add_dependency "prism", "< 0.24.0"
      end

      build_gem "ruby-lsp", "0.16.1" do |s|
        s.add_dependency "prism", ">= 0.24.0"
      end

      build_gem "tapioca", "0.11.10" do |s|
        s.add_dependency "prism", "< 0.24.0"
      end

      build_gem "tapioca", "0.13.1" do |s|
        s.add_dependency "prism", ">= 0.24.0"
      end

      build_gem "other-prism-dependent", "1.0.0" do |s|
        s.add_dependency "prism", ">= 0.15.1"
      end

      build_gem "other-prism-dependent", "1.1.0" do |s|
        s.add_dependency "prism", ">= 0.15.1"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"

      gem "tapioca"
      gem "ruby-lsp"
      gem "other-prism-dependent"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4
        specs:
          other-prism-dependent (1.0.0)
            prism (>= 0.15.1)
          prism (0.15.1)
          ruby-lsp (0.12.0)
            prism (< 0.24.0)
          tapioca (0.11.10)
            prism (< 0.24.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        ruby-lsp
        tapioca

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    bundle "lock --update tapioca"

    expect(lockfile).to include("tapioca (0.13.1)")
    expect(lockfile).to include("other-prism-dependent (1.0.0)")
  end

  it "preserves unknown checksum algorithms" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile.gsub(/(sha256=[a-f0-9]+)$/, "constant=true,\\1,xyz=123")

    previous_lockfile = read_lockfile

    bundle "lock"

    expect(read_lockfile).to eq(previous_lockfile)
  end

  it "does not unlock git sources when only uri shape changes" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    build_git("foo")

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "foo", :git => "#{lib_path("foo-1.0")}"
    G

    # Change uri format to end with "/" and reinstall
    install_gemfile <<-G, verbose: true
      source "https://gem.repo1"
      gem "foo", :git => "#{lib_path("foo-1.0")}/"
    G

    expect(out).to include("using resolution from the lockfile")
    expect(out).not_to include("re-resolving dependencies because the list of sources changed")
  end

  it "updates specific gems using --update using the locked revision of unrelated git gems for resolving" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    ref = build_git("foo").ref_for("HEAD")

    gemfile <<-G
      source "https://gem.repo1"
      gem "rake"
      gem "foo", :git => "#{lib_path("foo-1.0")}", :branch => "deadbeef"
    G

    lockfile <<~L
      GIT
        remote: #{lib_path("foo-1.0")}
        revision: #{ref}
        branch: deadbeef
        specs:
          foo (1.0)

      GEM
        remote: https://gem.repo1/
        specs:
          rake (10.0.1)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo!
        rake

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    bundle "lock --update rake --verbose"
    expect(out).to match(/Writing lockfile to.+lock/)
    expect(lockfile).to include("rake (#{rake_version})")
  end

  it "errors when updating a missing specific gems using --update" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile expected_lockfile

    bundle "lock --update blahblah", raise_on_error: false
    expect(err).to eq("Could not find gem 'blahblah'.")

    expect(read_lockfile).to eq(expected_lockfile)
  end

  it "can lock without downloading gems" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    gemfile <<-G
      source "https://gem.repo1"

      gem "thin"
      gem "myrack_middleware", :group => "test"
    G
    bundle "config set without test"
    bundle "config set path vendor/bundle"
    bundle "lock", verbose: true
    expect(bundled_app("vendor/bundle")).not_to exist
  end

  # see update_spec for more coverage on same options. logic is shared so it's not necessary
  # to repeat coverage here.
  context "conservative updates" do
    before do
      build_repo4 do
        build_gem "foo", %w[1.4.3 1.4.4] do |s|
          s.add_dependency "bar", "~> 2.0"
        end
        build_gem "foo", %w[1.4.5 1.5.0] do |s|
          s.add_dependency "bar", "~> 2.1"
        end
        build_gem "foo", %w[1.5.1] do |s|
          s.add_dependency "bar", "~> 3.0"
        end
        build_gem "foo", %w[2.0.0.pre] do |s|
          s.add_dependency "bar"
        end
        build_gem "bar", %w[2.0.3 2.0.4 2.0.5 2.1.0 2.1.1 2.1.2.pre 3.0.0 3.1.0.pre 4.0.0.pre]
        build_gem "qux", %w[1.0.0 1.0.1 1.1.0 2.0.0]
      end

      # establish a lockfile set to 1.4.3
      install_gemfile <<-G
        source "https://gem.repo4"
        gem 'foo', '1.4.3'
        gem 'bar', '2.0.3'
        gem 'qux', '1.0.0'
      G

      # remove 1.4.3 requirement and bar altogether
      # to setup update specs below
      gemfile <<-G
        source "https://gem.repo4"
        gem 'foo'
        gem 'qux'
      G

      allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    end

    it "single gem updates dependent gem to minor" do
      bundle "lock --update foo --patch"

      expect(the_bundle.locked_specs).to eq(%w[foo-1.4.5 bar-2.1.1 qux-1.0.0].sort)
    end

    it "minor preferred with strict" do
      bundle "lock --update --minor --strict"

      expect(the_bundle.locked_specs).to eq(%w[foo-1.5.0 bar-2.1.1 qux-1.1.0].sort)
    end

    it "shows proper error when Gemfile changes forbid patch upgrades, and --patch --strict is given" do
      # force next minor via Gemfile
      gemfile <<-G
        source "https://gem.repo4"
        gem 'foo', '1.5.0'
        gem 'qux'
      G

      bundle "lock --update foo --patch --strict", raise_on_error: false

      expect(err).to include(
        "foo is locked to 1.4.3, while Gemfile is requesting foo (= 1.5.0). " \
        "--strict --patch was specified, but there are no patch level upgrades from 1.4.3 satisfying foo (= 1.5.0), so version solving has failed"
      )
    end

    context "pre" do
      it "defaults to major" do
        bundle "lock --update --pre"

        expect(the_bundle.locked_specs).to eq(%w[foo-2.0.0.pre bar-4.0.0.pre qux-2.0.0].sort)
      end

      it "patch preferred" do
        bundle "lock --update --patch --pre"

        expect(the_bundle.locked_specs).to eq(%w[foo-1.4.5 bar-2.1.2.pre qux-1.0.1].sort)
      end

      it "minor preferred" do
        bundle "lock --update --minor --pre"

        expect(the_bundle.locked_specs).to eq(%w[foo-1.5.1 bar-3.1.0.pre qux-1.1.0].sort)
      end

      it "major preferred" do
        bundle "lock --update --major --pre"

        expect(the_bundle.locked_specs).to eq(%w[foo-2.0.0.pre bar-4.0.0.pre qux-2.0.0].sort)
      end
    end
  end

  context "conservative updates when minor update adds a new dependency" do
    before do
      build_repo4 do
        build_gem "sequel", "5.71.0"
        build_gem "sequel", "5.72.0" do |s|
          s.add_dependency "bigdecimal", ">= 0"
        end
        build_gem "bigdecimal", %w[1.4.4 99.1.4]
      end

      gemfile <<~G
        source "https://gem.repo4"
        gem 'sequel'
      G

      lockfile <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            sequel (5.71.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          sequel

        BUNDLED WITH
           #{Bundler::VERSION}
      L

      allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    end

    it "adds the latest version of the new dependency" do
      bundle "lock --minor --update sequel"

      expect(the_bundle.locked_specs).to eq(%w[sequel-5.72.0 bigdecimal-99.1.4].sort)
    end
  end

  it "updates the bundler version in the lockfile to the latest bundler version" do
    build_repo4 do
      build_gem "bundler", "55"
    end

    system_gems "bundler-55", gem_repo: gem_repo4

    install_gemfile <<-G, artifice: "compact_index", env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo4.to_s }
      source "https://gem.repo4"
    G
    lockfile lockfile.sub(/(^\s*)#{Bundler::VERSION}($)/, '\11.0.0\2')

    bundle "lock --update --bundler --verbose", artifice: "compact_index", env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo4.to_s }
    expect(lockfile).to end_with("BUNDLED WITH\n   55\n")

    update_repo4 do
      build_gem "bundler", "99"
    end

    bundle "lock --update --bundler --verbose", artifice: "compact_index", env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo4.to_s }
    expect(lockfile).to end_with("BUNDLED WITH\n   99\n")
  end

  it "supports adding new platforms when there's no previous lockfile" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --add-platform java x86-mingw32 --verbose"
    expect(out).to include("Resolving dependencies because there's no lockfile")

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(the_bundle.locked_platforms).to match_array(default_platform_list("java", "x86-mingw32"))
  end

  it "supports adding new platforms when a previous lockfile exists" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock"
    bundle "lock --add-platform java x86-mingw32 --verbose"
    expect(out).to include("Found changes from the lockfile, re-resolving dependencies because you are adding a new platform to your lockfile")

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(the_bundle.locked_platforms).to match_array(default_platform_list("java", "x86-mingw32"))
  end

  it "supports adding new platforms, when most specific locked platform is not the current platform, and current resolve is not compatible with the target platform" do
    simulate_platform "arm64-darwin-23" do
      build_repo4 do
        build_gem "foo" do |s|
          s.platform = "arm64-darwin"
        end

        build_gem "foo" do |s|
          s.platform = "java"
        end
      end

      gemfile <<-G
        source "https://gem.repo4"

        gem "foo"
      G

      lockfile <<-L
        GEM
          remote: https://gem.repo4/
          specs:
            foo (1.0-arm64-darwin)

        PLATFORMS
          arm64-darwin

        DEPENDENCIES
          foo

        BUNDLED WITH
           #{Bundler::VERSION}
      L

      bundle "lock --add-platform java"

      expect(lockfile).to eq <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            foo (1.0-arm64-darwin)
            foo (1.0-java)

        PLATFORMS
          arm64-darwin
          java

        DEPENDENCIES
          foo

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end

  it "supports adding new platforms with force_ruby_platform = true" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    lockfile <<-L
      GEM
        remote: https://gem.repo1/
        specs:
          platform_specific (1.0)
          platform_specific (1.0-x86-64_linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        platform_specific
    L

    bundle "config set force_ruby_platform true"
    bundle "lock --add-platform java x86-mingw32"

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(the_bundle.locked_platforms).to contain_exactly(Gem::Platform::RUBY, "x86_64-linux", "java", "x86-mingw32")
  end

  it "supports adding the `ruby` platform" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --add-platform ruby"

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(the_bundle.locked_platforms).to match_array(default_platform_list("ruby"))
  end

  it "fails when adding an unknown platform" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --add-platform foobarbaz", raise_on_error: false
    expect(err).to include("The platform `foobarbaz` is unknown to RubyGems and can't be added to the lockfile")
    expect(last_command).to be_failure
  end

  it "allows removing platforms" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --add-platform java x86-mingw32"

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(the_bundle.locked_platforms).to match_array(default_platform_list("java", "x86-mingw32"))

    bundle "lock --remove-platform java"

    expect(the_bundle.locked_platforms).to match_array(default_platform_list("x86-mingw32"))
  end

  it "also cleans up redundant platform gems when removing platforms" do
    build_repo4 do
      build_gem "nokogiri", "1.12.0"
      build_gem "nokogiri", "1.12.0" do |s|
        s.platform = "x86_64-darwin"
      end
    end

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "nokogiri", "1.12.0"
      c.checksum gem_repo4, "nokogiri", "1.12.0", "x86_64-darwin"
    end

    simulate_platform "x86_64-darwin-22" do
      install_gemfile <<~G
        source "https://gem.repo4"

        gem "nokogiri"
      G
    end

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.12.0)
          nokogiri (1.12.0-x86_64-darwin)

      PLATFORMS
        ruby
        x86_64-darwin

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L

    checksums.delete("nokogiri", Gem::Platform::RUBY)

    simulate_platform "x86_64-darwin-22" do
      bundle "lock --remove-platform ruby"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.12.0-x86_64-darwin)

      PLATFORMS
        x86_64-darwin

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  it "errors when removing all platforms" do
    gemfile_with_rails_weakling_and_foo_from_repo4

    bundle "lock --remove-platform #{local_platform}", raise_on_error: false
    expect(err).to include("Removing all platforms from the bundle is not allowed")
  end

  # from https://github.com/rubygems/bundler/issues/4896
  it "properly adds platforms when platform requirements come from different dependencies" do
    build_repo4 do
      build_gem "ffi", "1.9.14"
      build_gem "ffi", "1.9.14" do |s|
        s.platform = "x86-mingw32"
      end

      build_gem "gssapi", "0.1"
      build_gem "gssapi", "0.2"
      build_gem "gssapi", "0.3"
      build_gem "gssapi", "1.2.0" do |s|
        s.add_dependency "ffi", ">= 1.0.1"
      end

      build_gem "mixlib-shellout", "2.2.6"
      build_gem "mixlib-shellout", "2.2.6" do |s|
        s.platform = "universal-mingw32"
        s.add_dependency "win32-process", "~> 0.8.2"
      end

      # we need all these versions to get the sorting the same as it would be
      # pulling from rubygems.org
      %w[0.8.3 0.8.2 0.8.1 0.8.0].each do |v|
        build_gem "win32-process", v do |s|
          s.add_dependency "ffi", ">= 1.0.0"
        end
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "mixlib-shellout"
      gem "gssapi"
    G

    simulate_platform("x86-mingw32") { bundle :lock }

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "ffi", "1.9.14", "x86-mingw32"
      c.checksum gem_repo4, "gssapi", "1.2.0"
      c.checksum gem_repo4, "mixlib-shellout", "2.2.6", "universal-mingw32"
      c.checksum gem_repo4, "win32-process", "0.8.3"
    end

    expect(lockfile).to eq <<~G
      GEM
        remote: https://gem.repo4/
        specs:
          ffi (1.9.14-x86-mingw32)
          gssapi (1.2.0)
            ffi (>= 1.0.1)
          mixlib-shellout (2.2.6-universal-mingw32)
            win32-process (~> 0.8.2)
          win32-process (0.8.3)
            ffi (>= 1.0.0)

      PLATFORMS
        x86-mingw32

      DEPENDENCIES
        gssapi
        mixlib-shellout
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    G

    bundle "config set --local force_ruby_platform true"
    bundle :lock

    checksums.checksum gem_repo4, "ffi", "1.9.14"
    checksums.checksum gem_repo4, "mixlib-shellout", "2.2.6"

    expect(lockfile).to eq <<~G
      GEM
        remote: https://gem.repo4/
        specs:
          ffi (1.9.14)
          ffi (1.9.14-x86-mingw32)
          gssapi (1.2.0)
            ffi (>= 1.0.1)
          mixlib-shellout (2.2.6)
          mixlib-shellout (2.2.6-universal-mingw32)
            win32-process (~> 0.8.2)
          win32-process (0.8.3)
            ffi (>= 1.0.0)

      PLATFORMS
        ruby
        x86-mingw32

      DEPENDENCIES
        gssapi
        mixlib-shellout
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    G
  end

  it "doesn't crash when an update candidate doesn't have any matching platform" do
    build_repo4 do
      build_gem "libv8", "8.4.255.0"
      build_gem "libv8", "8.4.255.0" do |s|
        s.platform = "x86_64-darwin-19"
      end

      build_gem "libv8", "15.0.71.48.1beta2" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "libv8"
    G

    lockfile <<-G
      GEM
        remote: https://gem.repo4/
        specs:
          libv8 (8.4.255.0)
          libv8 (8.4.255.0-x86_64-darwin-19)

      PLATFORMS
        ruby
        x86_64-darwin-19

      DEPENDENCIES
        libv8

      BUNDLED WITH
         #{Bundler::VERSION}
    G

    simulate_platform("x86_64-darwin-19") { bundle "lock --update" }

    expect(out).to match(/Writing lockfile to.+Gemfile\.lock/)
  end

  it "adds all more specific candidates when they all have the same dependencies" do
    build_repo4 do
      build_gem "libv8", "8.4.255.0" do |s|
        s.platform = "x86_64-darwin-19"
      end

      build_gem "libv8", "8.4.255.0" do |s|
        s.platform = "x86_64-darwin-20"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "libv8"
    G

    simulate_platform("x86_64-darwin-19") { bundle "lock" }

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "libv8", "8.4.255.0", "x86_64-darwin-19"
      c.checksum gem_repo4, "libv8", "8.4.255.0", "x86_64-darwin-20"
    end

    expect(lockfile).to eq <<~G
      GEM
        remote: https://gem.repo4/
        specs:
          libv8 (8.4.255.0-x86_64-darwin-19)
          libv8 (8.4.255.0-x86_64-darwin-20)

      PLATFORMS
        x86_64-darwin-19
        x86_64-darwin-20

      DEPENDENCIES
        libv8
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    G
  end

  it "respects the previous lockfile if it had a matching less specific platform already locked, and installs the best variant for each platform" do
    build_repo4 do
      build_gem "libv8", "8.4.255.0" do |s|
        s.platform = "x86_64-darwin-19"
      end

      build_gem "libv8", "8.4.255.0" do |s|
        s.platform = "x86_64-darwin-20"
      end
    end

    checksums = checksums_section_when_enabled do |c|
      c.checksum gem_repo4, "libv8", "8.4.255.0", "x86_64-darwin-19"
      c.checksum gem_repo4, "libv8", "8.4.255.0", "x86_64-darwin-20"
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "libv8"
    G

    lockfile <<-G
      GEM
        remote: https://gem.repo4/
        specs:
          libv8 (8.4.255.0-x86_64-darwin-19)
          libv8 (8.4.255.0-x86_64-darwin-20)

      PLATFORMS
        x86_64-darwin

      DEPENDENCIES
        libv8
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    G

    previous_lockfile = lockfile

    %w[x86_64-darwin-19 x86_64-darwin-20].each do |platform|
      simulate_platform(platform) do
        bundle "lock"
        expect(lockfile).to eq(previous_lockfile)

        bundle "install"
        expect(the_bundle).to include_gem("libv8 8.4.255.0 #{platform}")
      end
    end
  end

  it "does not conflict on ruby requirements when adding new platforms" do
    build_repo4 do
      build_gem "raygun-apm", "1.0.78" do |s|
        s.platform = "x86_64-linux"
        s.required_ruby_version = "< #{next_ruby_minor}.dev"
      end

      build_gem "raygun-apm", "1.0.78" do |s|
        s.platform = "universal-darwin"
        s.required_ruby_version = "< #{next_ruby_minor}.dev"
      end

      build_gem "raygun-apm", "1.0.78" do |s|
        s.platform = "x64-mingw-ucrt"
        s.required_ruby_version = "< #{next_ruby_minor}.dev"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "raygun-apm"
    G

    lockfile <<-L
      GEM
        remote: https://gem.repo4/
        specs:
          raygun-apm (1.0.78-universal-darwin)

      PLATFORMS
        x86_64-darwin-19

      DEPENDENCIES
        raygun-apm

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    bundle "lock --add-platform x86_64-linux"
  end

  it "adds platform specific gems as necessary, even when adding the current platform" do
    build_repo4 do
      build_gem "nokogiri", "1.16.0"

      build_gem "nokogiri", "1.16.0" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "nokogiri"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.16.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        nokogiri

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    simulate_platform "x86_64-linux" do
      bundle "lock --add-platform x86_64-linux"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.16.0)
          nokogiri (1.16.0-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri

      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  it "refuses to add platforms incompatible with the lockfile" do
    build_repo4 do
      build_gem "sorbet-static", "0.5.11989" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"

      gem "sorbet-static"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          sorbet-static (0.5.11989-x86_64-linux)

      PLATFORMS
        x86_64-linux

      DEPENDENCIES
        sorbet-static

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    simulate_platform "x86_64-linux" do
      bundle "lock --add-platform ruby", raise_on_error: false
    end

    nice_error = <<~E.strip
      Could not find gems matching 'sorbet-static' valid for all resolution platforms (x86_64-linux, ruby) in rubygems repository https://gem.repo4/ or installed locally.

      The source contains the following gems matching 'sorbet-static':
        * sorbet-static-0.5.11989-x86_64-linux
    E
    expect(err).to include(nice_error)
  end

  it "respects lower bound ruby requirements" do
    build_repo4 do
      build_gem "our_private_gem", "0.1.0" do |s|
        s.required_ruby_version = ">= #{Gem.ruby_version}"
      end
    end

    gemfile <<-G
      source "https://localgemserver.test"

      gem "our_private_gem"
    G

    lockfile <<-L
      GEM
        remote: https://localgemserver.test/
        specs:
          our_private_gem (0.1.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        our_private_gem

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    bundle "install", artifice: "compact_index", env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo4.to_s }
  end

  context "when an update is available" do
    before do
      gemfile_with_rails_weakling_and_foo_from_repo4

      update_repo4 do
        build_gem "foo", "2.0"
      end

      lockfile(expected_lockfile)
    end

    it "does not implicitly update" do
      bundle "lock"

      checksums = checksums_section_when_enabled do |c|
        c.checksum gem_repo4, "actionmailer", "2.3.2"
        c.checksum gem_repo4, "actionpack", "2.3.2"
        c.checksum gem_repo4, "activerecord", "2.3.2"
        c.checksum gem_repo4, "activeresource", "2.3.2"
        c.checksum gem_repo4, "activesupport", "2.3.2"
        c.checksum gem_repo4, "foo", "1.0"
        c.checksum gem_repo4, "rails", "2.3.2"
        c.checksum gem_repo4, "rake", rake_version
        c.checksum gem_repo4, "weakling", "0.0.3"
      end

      expected_lockfile = <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            actionmailer (2.3.2)
              activesupport (= 2.3.2)
            actionpack (2.3.2)
              activesupport (= 2.3.2)
            activerecord (2.3.2)
              activesupport (= 2.3.2)
            activeresource (2.3.2)
              activesupport (= 2.3.2)
            activesupport (2.3.2)
            foo (1.0)
            rails (2.3.2)
              actionmailer (= 2.3.2)
              actionpack (= 2.3.2)
              activerecord (= 2.3.2)
              activeresource (= 2.3.2)
              rake (= #{rake_version})
            rake (#{rake_version})
            weakling (0.0.3)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          foo
          rails
          weakling
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L

      expect(read_lockfile).to eq(expected_lockfile)
    end

    it "accounts for changes in the gemfile" do
      gemfile gemfile.gsub('"foo"', '"foo", "2.0"')
      bundle "lock"

      checksums = checksums_section_when_enabled do |c|
        c.checksum gem_repo4, "actionmailer", "2.3.2"
        c.checksum gem_repo4, "actionpack", "2.3.2"
        c.checksum gem_repo4, "activerecord", "2.3.2"
        c.checksum gem_repo4, "activeresource", "2.3.2"
        c.checksum gem_repo4, "activesupport", "2.3.2"
        c.checksum gem_repo4, "foo", "2.0"
        c.checksum gem_repo4, "rails", "2.3.2"
        c.checksum gem_repo4, "rake", rake_version
        c.checksum gem_repo4, "weakling", "0.0.3"
      end

      expected_lockfile = <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            actionmailer (2.3.2)
              activesupport (= 2.3.2)
            actionpack (2.3.2)
              activesupport (= 2.3.2)
            activerecord (2.3.2)
              activesupport (= 2.3.2)
            activeresource (2.3.2)
              activesupport (= 2.3.2)
            activesupport (2.3.2)
            foo (2.0)
            rails (2.3.2)
              actionmailer (= 2.3.2)
              actionpack (= 2.3.2)
              activerecord (= 2.3.2)
              activeresource (= 2.3.2)
              rake (= #{rake_version})
            rake (#{rake_version})
            weakling (0.0.3)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          foo (= 2.0)
          rails
          weakling
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L

      expect(read_lockfile).to eq(expected_lockfile)
    end
  end

  context "when a system gem has incorrect dependencies, different from the lockfile" do
    before do
      build_repo4 do
        build_gem "debug", "1.6.3" do |s|
          s.add_dependency "irb", ">= 1.3.6"
        end

        build_gem "irb", "1.5.0"
      end

      system_gems "irb-1.5.0", gem_repo: gem_repo4
      system_gems "debug-1.6.3", gem_repo: gem_repo4

      # simulate gemspec with wrong empty dependencies
      debug_gemspec_path = system_gem_path("specifications/debug-1.6.3.gemspec")
      debug_gemspec = Gem::Specification.load(debug_gemspec_path.to_s)
      debug_gemspec.dependencies.clear
      File.write(debug_gemspec_path, debug_gemspec.to_ruby)
    end

    it "respects the existing lockfile, even when reresolving" do
      gemfile <<~G
        source "https://gem.repo4"

        gem "debug"
      G

      checksums = checksums_section_when_enabled do |c|
        c.checksum gem_repo4, "debug", "1.6.3"
        c.checksum gem_repo4, "irb", "1.5.0"
      end

      lockfile <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            debug (1.6.3)
              irb (>= 1.3.6)
            irb (1.5.0)

        PLATFORMS
          x86_64-linux

        DEPENDENCIES
          debug
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L

      simulate_platform "arm64-darwin-22" do
        bundle "lock"
      end

      expect(lockfile).to eq <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            debug (1.6.3)
              irb (>= 1.3.6)
            irb (1.5.0)

        PLATFORMS
          arm64-darwin-22
          x86_64-linux

        DEPENDENCIES
          debug
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end

  context "when a system gem has incorrect dependencies, different from remote gems" do
    before do
      build_repo4 do
        build_gem "foo", "1.0.0" do |s|
          s.add_dependency "bar"
        end

        build_gem "bar", "1.0.0"
      end

      system_gems "foo-1.0.0", gem_repo: gem_repo4, path: default_bundle_path

      # simulate gemspec with wrong empty dependencies
      foo_gemspec_path = default_bundle_path("specifications/foo-1.0.0.gemspec")
      foo_gemspec = Gem::Specification.load(foo_gemspec_path.to_s)
      foo_gemspec.dependencies.clear
      File.write(foo_gemspec_path, foo_gemspec.to_ruby)
    end

    it "generates a lockfile using remote dependencies, and prints a warning" do
      gemfile <<~G
        source "https://gem.repo4"

        gem "foo"
      G

      checksums = checksums_section_when_enabled do |c|
        c.checksum gem_repo4, "foo", "1.0.0"
        c.checksum gem_repo4, "bar", "1.0.0"
      end

      simulate_platform "x86_64-linux" do
        bundle "lock --verbose"
      end

      expect(err).to eq("Local specification for foo-1.0.0 has different dependencies than the remote gem, ignoring it")

      expect(lockfile).to eq <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            bar (1.0.0)
            foo (1.0.0)
              bar

        PLATFORMS
          ruby
          x86_64-linux

        DEPENDENCIES
          foo
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end

  it "properly shows resolution errors including OR requirements" do
    build_repo4 do
      build_gem "activeadmin", "2.13.1" do |s|
        s.add_dependency "railties", ">= 6.1", "< 7.1"
      end
      build_gem "actionpack", "6.1.4"
      build_gem "actionpack", "7.0.3.1"
      build_gem "actionpack", "7.0.4"
      build_gem "railties", "6.1.4" do |s|
        s.add_dependency "actionpack", "6.1.4"
      end
      build_gem "rails", "7.0.3.1" do |s|
        s.add_dependency "railties", "7.0.3.1"
      end
      build_gem "rails", "7.0.4" do |s|
        s.add_dependency "railties", "7.0.4"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"

      gem "rails", ">= 7.0.3.1"
      gem "activeadmin", "2.13.1"
    G

    bundle "lock", raise_on_error: false

    expect(err).to eq <<~ERR.strip
      Could not find compatible versions

      Because rails >= 7.0.4 depends on railties = 7.0.4
        and rails < 7.0.4 depends on railties = 7.0.3.1,
        railties = 7.0.3.1 OR = 7.0.4 is required.
      So, because railties = 7.0.3.1 OR = 7.0.4 could not be found in rubygems repository https://gem.repo4/ or installed locally,
        version solving has failed.
    ERR
  end

  it "is able to display some explanation on crazy irresolvable cases" do
    build_repo4 do
      build_gem "activeadmin", "2.13.1" do |s|
        s.add_dependency "ransack", "= 3.1.0"
      end

      # Activemodel is missing as a dependency in lockfile
      build_gem "ransack", "3.1.0" do |s|
        s.add_dependency "activemodel", ">= 6.0.4"
        s.add_dependency "activesupport", ">= 6.0.4"
      end

      %w[6.0.4 7.0.2.3 7.0.3.1 7.0.4].each do |version|
        build_gem "activesupport", version

        # Activemodel is only available on 6.0.4
        if version == "6.0.4"
          build_gem "activemodel", version do |s|
            s.add_dependency "activesupport", version
          end
        end

        build_gem "rails", version do |s|
          # Depednencies of Rails 7.0.2.3 are in reverse order
          if version == "7.0.2.3"
            s.add_dependency "activesupport", version
            s.add_dependency "activemodel", version
          else
            s.add_dependency "activemodel", version
            s.add_dependency "activesupport", version
          end
        end
      end
    end

    gemfile <<~G
      source "https://gem.repo4"

      gem "rails", ">= 7.0.2.3"
      gem "activeadmin", "= 2.13.1"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          activeadmin (2.13.1)
            ransack (= 3.1.0)
          ransack (3.1.0)
            activemodel (>= 6.0.4)

      PLATFORMS
        #{local_platform}

      DEPENDENCIES
        activeadmin (= 2.13.1)
        ransack (= 3.1.0)

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    expected_error = <<~ERR.strip
      Could not find compatible versions

          Because rails >= 7.0.4 depends on activemodel = 7.0.4
            and rails >= 7.0.3.1, < 7.0.4 depends on activemodel = 7.0.3.1,
            rails >= 7.0.3.1 requires activemodel = 7.0.3.1 OR = 7.0.4.
      (1) So, because rails >= 7.0.2.3, < 7.0.3.1 depends on activemodel = 7.0.2.3
            and every version of activemodel depends on activesupport = 6.0.4,
            rails >= 7.0.2.3 requires activesupport = 6.0.4.

          Because rails >= 7.0.2.3, < 7.0.3.1 depends on activesupport = 7.0.2.3
            and rails >= 7.0.3.1, < 7.0.4 depends on activesupport = 7.0.3.1,
            rails >= 7.0.2.3, < 7.0.4 requires activesupport = 7.0.2.3 OR = 7.0.3.1.
          And because rails >= 7.0.4 depends on activesupport = 7.0.4,
            rails >= 7.0.2.3 requires activesupport = 7.0.2.3 OR = 7.0.3.1 OR = 7.0.4.
          And because rails >= 7.0.2.3 requires activesupport = 6.0.4 (1),
            rails >= 7.0.2.3 cannot be used.
          So, because Gemfile depends on rails >= 7.0.2.3,
            version solving has failed.
    ERR

    bundle "lock", raise_on_error: false
    expect(err).to eq(expected_error)

    lockfile lockfile.gsub(/PLATFORMS\n  #{local_platform}/m, "PLATFORMS\n  #{lockfile_platforms("ruby")}")

    bundle "lock", raise_on_error: false
    expect(err).to eq(expected_error)
  end

  it "does not accidentally resolves to prereleases" do
    build_repo4 do
      build_gem "autoproj", "2.0.3" do |s|
        s.add_dependency "autobuild", ">= 1.10.0.a"
        s.add_dependency "tty-prompt"
      end

      build_gem "tty-prompt", "0.6.0"
      build_gem "tty-prompt", "0.7.0"

      build_gem "autobuild", "1.10.0.b3"
      build_gem "autobuild", "1.10.1" do |s|
        s.add_dependency "tty-prompt", "~> 0.6.0"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"
      gem "autoproj", ">= 2.0.0"
    G

    bundle "lock"
    expect(lockfile).to_not include("autobuild (1.10.0.b3)")
    expect(lockfile).to include("autobuild (1.10.1)")
  end

  # Newer rails depends on Bundler, while ancient Rails does not. Bundler tries
  # a first resolution pass that does not consider pre-releases. However, when
  # using a pre-release Bundler (like the .dev version), that results in that
  # pre-release being ignored and resolving to a version that does not depend on
  # Bundler at all. We should avoid that and still consider .dev Bundler.
  #
  it "does not ignore prereleases with there's only one candidate" do
    build_repo4 do
      build_gem "rails", "7.4.0.2" do |s|
        s.add_dependency "bundler", ">= 1.15.0"
      end

      build_gem "rails", "2.3.18"
    end

    gemfile <<~G
      source "https://gem.repo4"
      gem "rails"
    G

    bundle "lock"
    expect(lockfile).to_not include("rails (2.3.18)")
    expect(lockfile).to include("rails (7.4.0.2)")
  end

  it "deals with platform specific incompatibilities" do
    build_repo4 do
      build_gem "activerecord", "6.0.6"
      build_gem "activerecord-jdbc-adapter", "60.4" do |s|
        s.platform = "java"
        s.add_dependency "activerecord", "~> 6.0.0"
      end
      build_gem "activerecord-jdbc-adapter", "61.0" do |s|
        s.platform = "java"
        s.add_dependency "activerecord", "~> 6.1.0"
      end
    end

    gemfile <<~G
      source "https://gem.repo4"
      gem "activerecord", "6.0.6"
      gem "activerecord-jdbc-adapter", "61.0"
    G

    simulate_platform "universal-java-19" do
      bundle "lock", raise_on_error: false
    end

    expect(err).to include("Could not find compatible versions")
    expect(err).not_to include("ERROR REPORT TEMPLATE")
  end

  it "adds checksums to an existing lockfile, when re-resolving is necessary" do
    build_repo4 do
      build_gem "nokogiri", "1.14.2"
      build_gem "nokogiri", "1.14.2" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "nokogiri"
    G

    # lockfile has a typo (nogokiri) in the dependencies section, so Bundler
    # sees dependencies have changed, and re-resolves
    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nogokiri

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    simulate_platform "x86_64-linux" do
      bundle "lock --add-checksums"
    end

    checksums = checksums_section do |c|
      c.checksum gem_repo4, "nokogiri", "1.14.2"
      c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  it "adds checksums to an existing lockfile, when no re-resolve is necessary" do
    build_repo4 do
      build_gem "nokogiri", "1.14.2"
      build_gem "nokogiri", "1.14.2" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "nokogiri"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    simulate_platform "x86_64-linux" do
      bundle "lock --add-checksums"
    end

    checksums = checksums_section do |c|
      c.checksum gem_repo4, "nokogiri", "1.14.2"
      c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  it "adds checksums to an existing lockfile, when gems are already installed" do
    build_repo4 do
      build_gem "nokogiri", "1.14.2"
      build_gem "nokogiri", "1.14.2" do |s|
        s.platform = "x86_64-linux"
      end
    end

    gemfile <<-G
      source "https://gem.repo4"

      gem "nokogiri"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    simulate_platform "x86_64-linux" do
      bundle "install"

      bundle "lock --add-checksums"
    end

    checksums = checksums_section do |c|
      c.checksum gem_repo4, "nokogiri", "1.14.2"
      c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  it "generates checksums by default if configured to do so" do
    build_repo4 do
      build_gem "nokogiri", "1.14.2"
      build_gem "nokogiri", "1.14.2" do |s|
        s.platform = "x86_64-linux"
      end
    end

    bundle "config lockfile_checksums true"

    simulate_platform "x86_64-linux" do
      install_gemfile <<-G
        source "https://gem.repo4"

        gem "nokogiri"
      G
    end

    checksums = checksums_section do |c|
      c.checksum gem_repo4, "nokogiri", "1.14.2"
      c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
    end

    expect(lockfile).to eq <<~L
      GEM
        remote: https://gem.repo4/
        specs:
          nokogiri (1.14.2)
          nokogiri (1.14.2-x86_64-linux)

      PLATFORMS
        ruby
        x86_64-linux

      DEPENDENCIES
        nokogiri
      #{checksums}
      BUNDLED WITH
         #{Bundler::VERSION}
    L
  end

  context "when re-resolving to include prereleases" do
    before do
      build_repo4 do
        build_gem "tzinfo-data", "1.2022.7"
        build_gem "rails", "7.1.0.alpha" do |s|
          s.add_dependency "activesupport"
        end
        build_gem "activesupport", "7.1.0.alpha"
      end
    end

    it "does not end up including gems scoped to other platforms in the lockfile" do
      gemfile <<-G
        source "https://gem.repo4"
        gem "rails"
        gem "tzinfo-data", platform: :windows
      G

      simulate_platform "x86_64-darwin-22" do
        bundle "lock"
      end

      expect(lockfile).not_to include("tzinfo-data (1.2022.7)")
    end
  end

  context "when resolving platform specific gems as indirect dependencies on truffleruby", :truffleruby_only do
    before do
      build_lib "foo", path: bundled_app do |s|
        s.add_dependency "nokogiri"
      end

      build_repo4 do
        build_gem "nokogiri", "1.14.2"
        build_gem "nokogiri", "1.14.2" do |s|
          s.platform = "x86_64-linux"
        end
      end

      gemfile <<-G
        source "https://gem.repo4"
        gemspec
      G
    end

    it "locks both ruby and platform specific specs" do
      checksums = checksums_section_when_enabled do |c|
        c.no_checksum "foo", "1.0"
        c.checksum gem_repo4, "nokogiri", "1.14.2"
        c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
      end

      simulate_platform "x86_64-linux" do
        bundle "lock"
      end

      expect(lockfile).to eq <<~L
        PATH
          remote: .
          specs:
            foo (1.0)
              nokogiri

        GEM
          remote: https://gem.repo4/
          specs:
            nokogiri (1.14.2)
            nokogiri (1.14.2-x86_64-linux)

        PLATFORMS
          ruby
          x86_64-linux

        DEPENDENCIES
          foo!
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    context "and a lockfile with platform specific gems only already exists" do
      before do
        checksums = checksums_section_when_enabled do |c|
          c.no_checksum "foo", "1.0"
          c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
        end

        lockfile <<~L
          PATH
            remote: .
            specs:
              foo (1.0)
                nokogiri

          GEM
            remote: https://gem.repo4/
            specs:
              nokogiri (1.14.2-x86_64-linux)

          PLATFORMS
            x86_64-linux

          DEPENDENCIES
            foo!
          #{checksums}
          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end

      it "keeps platform specific gems" do
        checksums = checksums_section_when_enabled do |c|
          c.no_checksum "foo", "1.0"
          c.checksum gem_repo4, "nokogiri", "1.14.2"
          c.checksum gem_repo4, "nokogiri", "1.14.2", "x86_64-linux"
        end

        simulate_platform "x86_64-linux" do
          bundle "install"
        end

        expect(lockfile).to eq <<~L
          PATH
            remote: .
            specs:
              foo (1.0)
                nokogiri

          GEM
            remote: https://gem.repo4/
            specs:
              nokogiri (1.14.2)
              nokogiri (1.14.2-x86_64-linux)

          PLATFORMS
            x86_64-linux

          DEPENDENCIES
            foo!
          #{checksums}
          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end
    end
  end

  context "when adding a new gem that requires unlocking other transitive deps" do
    before do
      build_repo4 do
        build_gem "govuk_app_config", "0.1.0"

        build_gem "govuk_app_config", "4.13.0" do |s|
          s.add_dependency "railties", ">= 5.0"
        end

        %w[7.0.4.1 7.0.4.3].each do |v|
          build_gem "railties", v do |s|
            s.add_dependency "actionpack", v
            s.add_dependency "activesupport", v
          end

          build_gem "activesupport", v
          build_gem "actionpack", v
        end
      end

      gemfile <<~G
        source "https://gem.repo4"

        gem "govuk_app_config"
        gem "activesupport", "7.0.4.3"
      G

      # Simulate out of sync lockfile because top level dependency on
      # activesuport has just been added to the Gemfile, and locked to a higher
      # version
      lockfile <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            actionpack (7.0.4.1)
            activesupport (7.0.4.1)
            govuk_app_config (4.13.0)
              railties (>= 5.0)
            railties (7.0.4.1)
              actionpack (= 7.0.4.1)
              activesupport (= 7.0.4.1)

        PLATFORMS
          arm64-darwin-22

        DEPENDENCIES
          govuk_app_config

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    it "does not downgrade top level dependencies" do
      checksums = checksums_section_when_enabled do |c|
        c.no_checksum "actionpack", "7.0.4.3"
        c.no_checksum "activesupport", "7.0.4.3"
        c.no_checksum "govuk_app_config", "4.13.0"
        c.no_checksum "railties", "7.0.4.3"
      end

      simulate_platform "arm64-darwin-22" do
        bundle "lock"
      end

      expect(lockfile).to eq <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            actionpack (7.0.4.3)
            activesupport (7.0.4.3)
            govuk_app_config (4.13.0)
              railties (>= 5.0)
            railties (7.0.4.3)
              actionpack (= 7.0.4.3)
              activesupport (= 7.0.4.3)

        PLATFORMS
          arm64-darwin-22

        DEPENDENCIES
          activesupport (= 7.0.4.3)
          govuk_app_config
        #{checksums}
        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end

  context "when lockfile has incorrectly indented platforms" do
    before do
      build_repo4 do
        build_gem "ffi", "1.1.0" do |s|
          s.platform = "x86_64-linux"
        end

        build_gem "ffi", "1.1.0" do |s|
          s.platform = "arm64-darwin"
        end
      end

      gemfile <<~G
        source "https://gem.repo4"

        gem "ffi"
      G

      lockfile <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            ffi (1.1.0-arm64-darwin)

        PLATFORMS
           arm64-darwin

        DEPENDENCIES
          ffi

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    it "does not remove any gems" do
      simulate_platform "x86_64-linux" do
        bundle "lock --update"
      end

      expect(lockfile).to eq <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            ffi (1.1.0-arm64-darwin)
            ffi (1.1.0-x86_64-linux)

        PLATFORMS
          arm64-darwin
          x86_64-linux

        DEPENDENCIES
          ffi

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end

  describe "--normalize-platforms on linux" do
    let(:normalized_lockfile) do
      <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            irb (1.0.0)
            irb (1.0.0-x86_64-linux)

        PLATFORMS
          ruby
          x86_64-linux

        DEPENDENCIES
          irb

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    before do
      build_repo4 do
        build_gem "irb", "1.0.0"

        build_gem "irb", "1.0.0" do |s|
          s.platform = "x86_64-linux"
        end
      end

      gemfile <<~G
        source "https://gem.repo4"

        gem "irb"
      G
    end

    context "when already normalized" do
      before do
        lockfile normalized_lockfile
      end

      it "is a noop" do
        simulate_platform "x86_64-linux" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end

    context "when not already normalized" do
      before do
        lockfile <<~L
          GEM
            remote: https://gem.repo4/
            specs:
              irb (1.0.0)

          PLATFORMS
             ruby

          DEPENDENCIES
            irb

          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end

      it "normalizes the list of platforms and native gems in the lockfile" do
        simulate_platform "x86_64-linux" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end
  end

  describe "--normalize-platforms on darwin" do
    let(:normalized_lockfile) do
      <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            irb (1.0.0)
            irb (1.0.0-arm64-darwin)

        PLATFORMS
          arm64-darwin
          ruby

        DEPENDENCIES
          irb

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    before do
      build_repo4 do
        build_gem "irb", "1.0.0"

        build_gem "irb", "1.0.0" do |s|
          s.platform = "arm64-darwin"
        end
      end

      gemfile <<~G
        source "https://gem.repo4"

        gem "irb"
      G
    end

    context "when already normalized" do
      before do
        lockfile normalized_lockfile
      end

      it "is a noop" do
        simulate_platform "arm64-darwin-23" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end

    context "when having only ruby" do
      before do
        lockfile <<~L
          GEM
            remote: https://gem.repo4/
            specs:
              irb (1.0.0)

          PLATFORMS
             ruby

          DEPENDENCIES
            irb

          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end

      it "normalizes the list of platforms and native gems in the lockfile" do
        simulate_platform "arm64-darwin-23" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end

    context "when having only the current platform with version" do
      before do
        lockfile <<~L
          GEM
            remote: https://gem.repo4/
            specs:
              irb (1.0.0-arm64-darwin)

          PLATFORMS
             arm64-darwin-23

          DEPENDENCIES
            irb

          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end

      it "normalizes the list of platforms by removing version" do
        simulate_platform "arm64-darwin-23" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end

    context "when having other platforms with version" do
      before do
        lockfile <<~L
          GEM
            remote: https://gem.repo4/
            specs:
              irb (1.0.0-arm64-darwin)

          PLATFORMS
             arm64-darwin-22

          DEPENDENCIES
            irb

          BUNDLED WITH
             #{Bundler::VERSION}
        L
      end

      it "normalizes the list of platforms by removing version" do
        simulate_platform "arm64-darwin-23" do
          bundle "lock --normalize-platforms"
        end

        expect(lockfile).to eq(normalized_lockfile)
      end
    end
  end

  describe "--normalize-platforms with gems without generic variant" do
    let(:original_lockfile) do
      <<~L
        GEM
          remote: https://gem.repo4/
          specs:
            sorbet-static (1.0-x86_64-linux)

        PLATFORMS
          ruby
          x86_64-linux

        DEPENDENCIES
          sorbet-static

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end

    before do
      build_repo4 do
        build_gem "sorbet-static" do |s|
          s.platform = "x86_64-linux"
        end
      end

      gemfile <<~G
        source "https://gem.repo4"

        gem "sorbet-static"
      G

      lockfile original_lockfile
    end

    it "removes invalid platforms" do
      simulate_platform "x86_64-linux" do
        bundle "lock --normalize-platforms"
      end

      expect(lockfile).to eq(original_lockfile.gsub(/^  ruby\n/m, ""))
    end
  end
end
