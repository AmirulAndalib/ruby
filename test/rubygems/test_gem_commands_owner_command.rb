# frozen_string_literal: true

require_relative "helper"
require_relative "multifactor_auth_utilities"
require "rubygems/commands/owner_command"

class TestGemCommandsOwnerCommand < Gem::TestCase
  def setup
    super

    credential_setup

    ENV["RUBYGEMS_HOST"] = nil
    @stub_ui = Gem::MockGemUi.new
    @stub_fetcher = Gem::MultifactorAuthFetcher.new
    Gem::RemoteFetcher.fetcher = @stub_fetcher
    Gem.configuration = nil
    Gem.configuration.rubygems_api_key = "ed244fbf2b1a52e012da8616c512fa47f9aa5250"

    @cmd = Gem::Commands::OwnerCommand.new
  end

  def teardown
    credential_teardown

    super
  end

  def test_show_owners
    response = <<EOF
---
- email: user1@example.com
  id: 1
  handle: user1
- email: user2@example.com
- id: 3
  handle: user3
- id: 4
EOF

    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    use_ui @stub_ui do
      @cmd.show_owners("freewill")
    end

    assert_equal Gem::Net::HTTP::Get, @stub_fetcher.last_request.class
    assert_equal Gem.configuration.rubygems_api_key, @stub_fetcher.last_request["Authorization"]

    assert_match(/Owners for gem: freewill/, @stub_ui.output)
    assert_match(/- user1@example.com/, @stub_ui.output)
    assert_match(/- user2@example.com/, @stub_ui.output)
    assert_match(/- user3/, @stub_ui.output)
    assert_match(/- 4/, @stub_ui.output)
  end

  def test_show_owners_dont_load_objects
    pend "testing a psych-only API" unless defined?(::Psych::DisallowedClass)

    response = <<EOF
---
- email: !ruby/object:Object {}
  id: 1
  handle: user1
- email: user2@example.com
- id: 3
  handle: user3
- id: 4
EOF

    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    assert_raise Psych::DisallowedClass do
      use_ui @ui do
        @cmd.show_owners("freewill")
      end
    end
  end

  def test_show_owners_setting_up_host_through_env_var
    response = "- email: user1@example.com\n"
    host = "http://rubygems.example"
    ENV["RUBYGEMS_HOST"] = host

    @stub_fetcher.data["#{host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    use_ui @stub_ui do
      @cmd.show_owners("freewill")
    end

    assert_match(/Owners for gem: freewill/, @stub_ui.output)
    assert_match(/- user1@example.com/, @stub_ui.output)
  end

  def test_show_owners_setting_up_host
    response = "- email: user1@example.com\n"
    host = "http://rubygems.example"
    @cmd.host = host

    @stub_fetcher.data["#{host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    use_ui @stub_ui do
      @cmd.show_owners("freewill")
    end

    assert_match(/Owners for gem: freewill/, @stub_ui.output)
    assert_match(/- user1@example.com/, @stub_ui.output)
  end

  def test_show_owners_denied
    response = "You don't have permission to push to this gem"
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 403, msg: "Forbidden")

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.show_owners("freewill")
      end
    end

    assert_match response, @stub_ui.output
  end

  def test_show_owners_permanent_redirect
    host = "http://rubygems.example"
    ENV["RUBYGEMS_HOST"] = host
    path = "/api/v1/gems/freewill/owners.yaml"
    redirected_uri = "https://rubygems.example#{path}"

    @stub_fetcher.data["#{host}#{path}"] = HTTPResponseFactory.create(
      body: "",
      code: "301",
      msg: "Moved Permanently",
      headers: { "location" => redirected_uri }
    )

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.show_owners("freewill")
      end
    end

    response = "The request has redirected permanently to #{redirected_uri}. Please check your defined push host URL."
    assert_match response, @stub_ui.output
  end

  def test_show_owners_key
    response = "- email: user1@example.com\n"
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")
    File.open Gem.configuration.credentials_path, "a" do |f|
      f.write ":other: 701229f217cdf23b1344c7b4b54ca97"
    end
    Gem.configuration.load_api_keys

    @cmd.handle_options %w[-k other]
    @cmd.show_owners("freewill")

    assert_equal "701229f217cdf23b1344c7b4b54ca97", @stub_fetcher.last_request["Authorization"]
  end

  def test_add_owners
    response = "Owner added successfully."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    use_ui @stub_ui do
      @cmd.add_owners("freewill", ["user-new1@example.com"])
    end

    assert_equal Gem::Net::HTTP::Post, @stub_fetcher.last_request.class
    assert_equal Gem.configuration.rubygems_api_key, @stub_fetcher.last_request["Authorization"]
    assert_equal "email=user-new1%40example.com", @stub_fetcher.last_request.body

    assert_match response, @stub_ui.output
  end

  def test_add_owners_denied
    response = "You don't have permission to push to this gem"
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 403, msg: "Forbidden")

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.add_owners("freewill", ["user-new1@example.com"])
      end
    end

    assert_match response, @stub_ui.output
  end

  def test_add_owners_permanent_redirect
    host = "http://rubygems.example"
    ENV["RUBYGEMS_HOST"] = host
    path = "/api/v1/gems/freewill/owners"
    redirected_uri = "https://rubygems.example#{path}"

    @stub_fetcher.data["#{host}#{path}"] = HTTPResponseFactory.create(
      body: "",
      code: "308",
      msg: "Permanent Redirect",
      headers: { "location" => redirected_uri }
    )

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.add_owners("freewill", ["user-new1@example.com"])
      end
    end

    response = "The request has redirected permanently to #{redirected_uri}. Please check your defined push host URL."
    assert_match response, @stub_ui.output
  end

  def test_add_owner_with_host_option_through_execute
    host = "http://rubygems.example"
    add_owner_response = "Owner added successfully."
    show_owners_response = "- email: user1@example.com\n"
    @stub_fetcher.data["#{host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: add_owner_response, code: 200, msg: "OK")
    @stub_fetcher.data["#{host}/api/v1/gems/freewill/owners.yaml"] = HTTPResponseFactory.create(body: show_owners_response, code: 200, msg: "OK")

    @cmd.handle_options %W[--host #{host} --add user-new1@example.com freewill]

    use_ui @stub_ui do
      @cmd.execute
    end

    assert_match add_owner_response, @stub_ui.output
    assert_match(/Owners for gem: freewill/, @stub_ui.output)
    assert_match(/- user1@example.com/, @stub_ui.output)
  end

  def test_add_owners_key
    response = "Owner added successfully."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")
    File.open Gem.configuration.credentials_path, "a" do |f|
      f.write ":other: 701229f217cdf23b1344c7b4b54ca97"
    end
    Gem.configuration.load_api_keys

    @cmd.handle_options %w[-k other]
    @cmd.add_owners("freewill", ["user-new1@example.com"])

    assert_equal "701229f217cdf23b1344c7b4b54ca97", @stub_fetcher.last_request["Authorization"]
  end

  def test_remove_owners
    response = "Owner removed successfully."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")

    use_ui @stub_ui do
      @cmd.remove_owners("freewill", ["user-remove1@example.com"])
    end

    assert_equal Gem::Net::HTTP::Delete, @stub_fetcher.last_request.class
    assert_equal Gem.configuration.rubygems_api_key, @stub_fetcher.last_request["Authorization"]
    assert_equal "email=user-remove1%40example.com", @stub_fetcher.last_request.body

    assert_match response, @stub_ui.output
  end

  def test_remove_owners_denied
    response = "You don't have permission to push to this gem"
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 403, msg: "Forbidden")

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.remove_owners("freewill", ["user-remove1@example.com"])
      end
    end

    assert_match response, @stub_ui.output
  end

  def test_remove_owners_permanent_redirect
    host = "http://rubygems.example"
    ENV["RUBYGEMS_HOST"] = host
    path = "/api/v1/gems/freewill/owners"
    redirected_uri = "https://rubygems.example#{path}"
    @stub_fetcher.data["#{host}#{path}"] = HTTPResponseFactory.create(
      body: "",
      code: "308",
      msg: "Permanent Redirect",
      headers: { "location" => redirected_uri }
    )

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.remove_owners("freewill", ["user-remove1@example.com"])
      end
    end

    response = "The request has redirected permanently to #{redirected_uri}. Please check your defined push host URL."
    assert_match response, @stub_ui.output

    path = "/api/v1/gems/freewill/owners"
    redirected_uri = "https://rubygems.example#{path}"

    @stub_fetcher.data["#{host}#{path}"] = HTTPResponseFactory.create(
      body: "",
      code: "308",
      msg: "Permanent Redirect",
      headers: { "location" => redirected_uri }
    )

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.add_owners("freewill", ["user-new1@example.com"])
      end
    end

    response = "The request has redirected permanently to #{redirected_uri}. Please check your defined push host URL."
    assert_match response, @stub_ui.output
  end

  def test_remove_owners_key
    response = "Owner removed successfully."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 200, msg: "OK")
    File.open Gem.configuration.credentials_path, "a" do |f|
      f.write ":other: 701229f217cdf23b1344c7b4b54ca97"
    end
    Gem.configuration.load_api_keys

    @cmd.handle_options %w[-k other]
    @cmd.remove_owners("freewill", ["user-remove1@example.com"])

    assert_equal "701229f217cdf23b1344c7b4b54ca97", @stub_fetcher.last_request["Authorization"]
  end

  def test_remove_owners_missing
    response = "Owner could not be found."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 404, msg: "Not Found")

    assert_raise Gem::MockGemUi::TermError do
      use_ui @stub_ui do
        @cmd.remove_owners("freewill", ["missing@example"])
      end
    end

    assert_equal "Removing missing@example: #{response}\n", @stub_ui.output
  end

  def test_otp_verified_success
    response_success = "Owner added successfully."
    @stub_fetcher.respond_with_require_otp("#{Gem.host}/api/v1/gems/freewill/owners", response_success)

    @otp_ui = Gem::MockGemUi.new "111111\n"
    use_ui @otp_ui do
      @cmd.add_owners("freewill", ["user-new1@example.com"])
    end

    assert_match "You have enabled multi-factor authentication. Please enter OTP code.", @otp_ui.output
    assert_match "Code: ", @otp_ui.output
    assert_match response_success, @otp_ui.output
    assert_equal "111111", @stub_fetcher.last_request["OTP"]
  end

  def test_otp_verified_failure
    response = "You have enabled multifactor authentication but your request doesn't have the correct OTP code. Please check it and retry."
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = HTTPResponseFactory.create(body: response, code: 401, msg: "Unauthorized")
    @stub_fetcher.data["#{Gem.host}/api/v1/webauthn_verification"] =
      HTTPResponseFactory.create(body: "You don't have any security devices", code: 422, msg: "Unprocessable Entity")

    @otp_ui = Gem::MockGemUi.new "111111\n"

    assert_raise Gem::MockGemUi::TermError do
      use_ui @otp_ui do
        @cmd.add_owners("freewill", ["user-new1@example.com"])
      end
    end

    assert_match response, @otp_ui.output
    assert_match "You have enabled multi-factor authentication. Please enter OTP code.", @otp_ui.output
    assert_match "Code: ", @otp_ui.output
    assert_equal "111111", @stub_fetcher.last_request["OTP"]
  end

  def test_with_webauthn_enabled_success
    response_success = "Owner added successfully."
    server = Gem::MockTCPServer.new

    @stub_fetcher.respond_with_require_otp("#{Gem.host}/api/v1/gems/freewill/owners", response_success)
    @stub_fetcher.respond_with_webauthn_url

    TCPServer.stub(:new, server) do
      Gem::GemcutterUtilities::WebauthnListener.stub(:listener_thread, Thread.new { Thread.current[:otp] = "Uvh6T57tkWuUnWYo" }) do
        use_ui @stub_ui do
          @cmd.add_owners("freewill", ["user-new1@example.com"])
        end
      end
    end

    assert_match "You have enabled multi-factor authentication. Please visit the following URL " \
      "to authenticate via security device. If you can't verify using WebAuthn but have OTP enabled, " \
      "you can re-run the gem signin command with the `--otp [your_code]` option.", @stub_ui.output
    assert_match @stub_fetcher.webauthn_url_with_port(server.port), @stub_ui.output
    assert_match "You are verified with a security device. You may close the browser window.", @stub_ui.output
    assert_equal "Uvh6T57tkWuUnWYo", @stub_fetcher.last_request["OTP"]
    assert_match response_success, @stub_ui.output
  end

  def test_with_webauthn_enabled_failure
    response_success = "Owner added successfully."
    server = Gem::MockTCPServer.new
    error = Gem::WebauthnVerificationError.new("Something went wrong")

    @stub_fetcher.respond_with_require_otp("#{Gem.host}/api/v1/gems/freewill/owners", response_success)
    @stub_fetcher.respond_with_webauthn_url

    TCPServer.stub(:new, server) do
      Gem::GemcutterUtilities::WebauthnListener.stub(:listener_thread, Thread.new { Thread.current[:error] = error }) do
        assert_raise Gem::MockGemUi::TermError do
          use_ui @stub_ui do
            @cmd.add_owners("freewill", ["user-new1@example.com"])
          end
        end
      end
    end

    assert_match @stub_fetcher.last_request["Authorization"], Gem.configuration.rubygems_api_key
    assert_match "You have enabled multi-factor authentication. Please visit the following URL " \
      "to authenticate via security device. If you can't verify using WebAuthn but have OTP enabled, " \
      "you can re-run the gem signin command with the `--otp [your_code]` option.", @stub_ui.output
    assert_match @stub_fetcher.webauthn_url_with_port(server.port), @stub_ui.output
    assert_match "ERROR:  Security device verification failed: Something went wrong", @stub_ui.error
    refute_match "You are verified with a security device. You may close the browser window.", @stub_ui.output
    refute_match response_success, @stub_ui.output
  end

  def test_with_webauthn_enabled_success_with_polling
    response_success = "Owner added successfully."
    server = Gem::MockTCPServer.new

    @stub_fetcher.respond_with_require_otp("#{Gem.host}/api/v1/gems/freewill/owners", response_success)
    @stub_fetcher.respond_with_webauthn_url
    @stub_fetcher.respond_with_webauthn_polling("Uvh6T57tkWuUnWYo")

    TCPServer.stub(:new, server) do
      use_ui @stub_ui do
        @cmd.add_owners("freewill", ["user-new1@example.com"])
      end
    end

    assert_match "You have enabled multi-factor authentication. Please visit the following URL " \
      "to authenticate via security device. If you can't verify using WebAuthn but have OTP enabled, you can re-run the gem signin " \
      "command with the `--otp [your_code]` option.", @stub_ui.output
    assert_match @stub_fetcher.webauthn_url_with_port(server.port), @stub_ui.output
    assert_match "You are verified with a security device. You may close the browser window.", @stub_ui.output
    assert_equal "Uvh6T57tkWuUnWYo", @stub_fetcher.last_request["OTP"]
    assert_match response_success, @stub_ui.output
  end

  def test_with_webauthn_enabled_failure_with_polling
    response_success = "Owner added successfully."
    server = Gem::MockTCPServer.new

    @stub_fetcher.respond_with_require_otp(
      "#{Gem.host}/api/v1/gems/freewill/owners",
      response_success
    )
    @stub_fetcher.respond_with_webauthn_url
    @stub_fetcher.respond_with_webauthn_polling_failure

    TCPServer.stub(:new, server) do
      assert_raise Gem::MockGemUi::TermError do
        use_ui @stub_ui do
          @cmd.add_owners("freewill", ["user-new1@example.com"])
        end
      end
    end

    assert_match @stub_fetcher.last_request["Authorization"], Gem.configuration.rubygems_api_key
    assert_match "You have enabled multi-factor authentication. Please visit the following URL " \
      "to authenticate via security device. If you can't verify using WebAuthn but have OTP enabled, you can re-run the gem signin " \
      "command with the `--otp [your_code]` option.", @stub_ui.output
    assert_match @stub_fetcher.webauthn_url_with_port(server.port), @stub_ui.output
    assert_match "ERROR:  Security device verification failed: The token in the link you used has either expired " \
      "or been used already.", @stub_ui.error
    refute_match "You are verified with a security device. You may close the browser window.", @stub_ui.output
    refute_match response_success, @stub_ui.output
  end

  def test_remove_owners_unauthorized_api_key
    response_forbidden = "The API key doesn't have access"
    response_success   = "Owner removed successfully."

    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = [
      HTTPResponseFactory.create(body: response_forbidden, code: 403, msg: "Forbidden"),
      HTTPResponseFactory.create(body: response_success, code: 200, msg: "OK"),
    ]
    @stub_fetcher.data["#{Gem.host}/api/v1/api_key"] = HTTPResponseFactory.create(body: "", code: 200, msg: "OK")
    @cmd.instance_variable_set :@scope, :remove_owner

    @stub_ui = Gem::MockGemUi.new "some@mail.com\npass\n"
    use_ui @stub_ui do
      @cmd.remove_owners("freewill", ["some@example"])
    end

    access_notice = "The existing key doesn't have access of remove_owner on RubyGems.org. Please sign in to update access."
    assert_match access_notice, @stub_ui.output
    assert_match "Username/email:", @stub_ui.output
    assert_match "Password:", @stub_ui.output
    assert_match "Added remove_owner scope to the existing API key", @stub_ui.output
    assert_match response_success, @stub_ui.output
  end

  def test_add_owners_no_api_key_webauthn_enabled_does_not_reuse_otp_codes
    response_profile = "mfa: ui_and_api\n"
    response_mfa_enabled = "You have enabled multifactor authentication but no OTP code provided. Please fill it and retry."
    response_not_found = "Owner could not be found."
    Gem.configuration.rubygems_api_key = nil

    path_token = "odow34b93t6aPCdY"
    webauthn_url = "#{Gem.host}/webauthn_verification/#{path_token}"

    @stub_fetcher.data["#{Gem.host}/api/v1/profile/me.yaml"] = HTTPResponseFactory.create(body: response_profile, code: 200, msg: "OK")
    @stub_fetcher.data["#{Gem.host}/api/v1/api_key"] = [
      HTTPResponseFactory.create(body: response_mfa_enabled, code: 401, msg: "Unauthorized"),
      HTTPResponseFactory.create(body: "", code: 200, msg: "OK"),
    ]
    @stub_fetcher.data["#{Gem.host}/api/v1/webauthn_verification"] = Gem::HTTPResponseFactory.create(body: webauthn_url, code: 200, msg: "OK")
    @stub_fetcher.data["#{Gem.host}/api/v1/webauthn_verification/#{path_token}/status.json"] = [
      Gem::HTTPResponseFactory.create(body: { status: "success", code: "Uvh6T57tkWuUnWYo" }.to_json, code: 200, msg: "OK"),
      Gem::HTTPResponseFactory.create(body: { status: "success", code: "Uvh6T57tkWuUnWYz" }.to_json, code: 200, msg: "OK"),
    ]
    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = [
      HTTPResponseFactory.create(body: response_mfa_enabled, code: 401, msg: "Unauthorized"),
      HTTPResponseFactory.create(body: response_not_found, code: 404, msg: "Not Found"),
    ]
    @cmd.handle_options %W[--add some@example freewill]

    @stub_ui = Gem::MockGemUi.new "some@mail.com\npass\n"

    server = Gem::MockTCPServer.new

    assert_raise Gem::MockGemUi::TermError do
      TCPServer.stub(:new, server) do
        use_ui @stub_ui do
          @cmd.execute
        end
      end
    end

    reused_otp_codes = @stub_fetcher.requests.filter_map {|req| req["OTP"] }.tally.filter_map {|el, count| el if count > 1 }
    assert_empty reused_otp_codes
  end

  def test_add_owners_unauthorized_api_key
    response_forbidden = "The API key doesn't have access"
    response_success   = "Owner added successfully."

    @stub_fetcher.data["#{Gem.host}/api/v1/gems/freewill/owners"] = [
      HTTPResponseFactory.create(body: response_forbidden, code: 403, msg: "Forbidden"),
      HTTPResponseFactory.create(body: response_success, code: 200, msg: "OK"),
    ]
    @stub_fetcher.data["#{Gem.host}/api/v1/api_key"] = HTTPResponseFactory.create(body: "", code: 200, msg: "OK")
    @cmd.instance_variable_set :@scope, :add_owner

    @stub_ui = Gem::MockGemUi.new "some@mail.com\npass\n"
    use_ui @stub_ui do
      @cmd.add_owners("freewill", ["some@example"])
    end

    access_notice = "The existing key doesn't have access of add_owner on RubyGems.org. Please sign in to update access."
    assert_match access_notice, @stub_ui.output
    assert_match "Username/email:", @stub_ui.output
    assert_match "Password:", @stub_ui.output
    assert_match "Added add_owner scope to the existing API key", @stub_ui.output
    assert_match response_success, @stub_ui.output
  end
end
