require "test_helper"

class HomeAssistantIngressMiddlewareTest < ActiveSupport::TestCase
  INGRESS_PATH = "/api/hassio_ingress/demo"

  test "stores ingress path as Rack script name" do
    app = ->(env) { [ 200, {}, [ env["SCRIPT_NAME"] ] ] }
    middleware = HomeAssistantIngressMiddleware.new(app)

    _status, _headers, body = middleware.call({
      "HTTP_X_INGRESS_PATH" => INGRESS_PATH,
      "SCRIPT_NAME" => ""
    })

    assert_equal INGRESS_PATH, body.join
  end

  test "normalizes ingress path without changing existing path info" do
    app = ->(env) { [ 200, {}, [ "#{env['homechat.ingress_path']} #{env['PATH_INFO']}" ] ] }
    middleware = HomeAssistantIngressMiddleware.new(app)

    _status, _headers, body = middleware.call({
      "HTTP_X_INGRESS_PATH" => "api/hassio_ingress/demo/",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => "/assets/application.css"
    })

    assert_equal "/api/hassio_ingress/demo /assets/application.css", body.join
  end

  test "renders app shell urls under ingress path" do
    with_relative_url_root(INGRESS_PATH) do
      session = ActionDispatch::Integration::Session.new(HomeAssistantIngressMiddleware.new(Rails.application))

      session.get "/", headers: { "X-Ingress-Path" => INGRESS_PATH }

      assert_equal 200, session.response.status
      assert_match %r{href="#{Regexp.escape(INGRESS_PATH)}/assets/tailwind-[^"]+\.css"}, session.response.body
      assert_match %r{"application": "#{Regexp.escape(INGRESS_PATH)}/assets/application-[^"]+\.js"}, session.response.body
      assert_match %r{rel="modulepreload" href="#{Regexp.escape(INGRESS_PATH)}/assets/application-[^"]+\.js"}, session.response.body
      assert_includes session.response.body, %(<link rel="manifest" href="#{INGRESS_PATH}/manifest.json">)
      assert_includes session.response.body, %(navigator.serviceWorker.register('#{INGRESS_PATH}/service-worker'))
      assert_includes session.response.body, %(href="#{INGRESS_PATH}/signin")
      assert_includes session.response.body, %(name="homechat-base-path" content="#{INGRESS_PATH}")
    end
  end

  test "renders logged in dashboard urls under ingress path" do
    user = create_user(username: "ingress_user", role: "admin")
    channel = user.channels.where(channel_type: "public").first

    with_relative_url_root(INGRESS_PATH) do
      session = ActionDispatch::Integration::Session.new(HomeAssistantIngressMiddleware.new(Rails.application))

      session.post "/signin",
        params: { username: user.username, password: "password123" },
        headers: { "X-Ingress-Path" => INGRESS_PATH }

      assert_equal 302, session.response.status
      assert_equal "#{INGRESS_PATH}/dashboard", URI(session.response.location).path

      session.get "/dashboard", headers: { "X-Ingress-Path" => INGRESS_PATH }

      assert_equal 200, session.response.status
      assert_includes session.response.body, %(class="dashboard-page")
      assert_includes session.response.body, %(name="action-cable-url" content="#{INGRESS_PATH}/cable")
      assert_match %r{href="#{Regexp.escape(INGRESS_PATH)}/assets/tailwind-[^"]+\.css"}, session.response.body
      assert_match %r{"channels": "#{Regexp.escape(INGRESS_PATH)}/assets/channels/index-[^"]+\.js"}, session.response.body
      assert_includes session.response.body, %(&quot;url&quot;:&quot;#{INGRESS_PATH}/channels/#{channel.id}&quot;)
      assert_includes session.response.body, %(href="#{INGRESS_PATH}/channels")
      assert_includes session.response.body, %(href="#{INGRESS_PATH}/settings")
      assert_includes session.response.body, %(navigator.serviceWorker.register('#{INGRESS_PATH}/service-worker'))
    end
  end

  test "ignores unsafe ingress paths" do
    app = ->(env) { [ 200, {}, [ env["SCRIPT_NAME"].to_s ] ] }
    middleware = HomeAssistantIngressMiddleware.new(app)

    _status, _headers, body = middleware.call({
      "HTTP_X_INGRESS_PATH" => "/api/../admin",
      "SCRIPT_NAME" => ""
    })

    assert_equal "", body.join
  end

  private

  def with_relative_url_root(path)
    previous = ApplicationController.config.relative_url_root
    ApplicationController.config.relative_url_root = path
    yield
  ensure
    ApplicationController.config.relative_url_root = previous
  end
end
