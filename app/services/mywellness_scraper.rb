require "mechanize"
require "json"
require "net/http"
require "uri"

class MywellnessScraper
  BASE_URL      = "https://v1.mywellness.com"
  LOGIN_PATH    = "/Cloud/User/Register"
  SERVICES_BASE = "https://services.mywellness.com"
  API_APP_ID    = "ec1d38d7-d359-48d0-a60c-d8c0b8fb9df9"
  USER_AGENT    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"

  attr_reader :club_slug

  def initialize
    @agent = Mechanize.new do |a|
      a.user_agent   = USER_AGENT
      a.open_timeout = 30
      a.read_timeout = 60
    end
  end

  def login(username, password)
    page = @agent.get(BASE_URL + LOGIN_PATH)
    form = page.form_with(id: "login-page") || page.forms.first
    return { success: false, error: "No login form found." } unless form

    form.field_with(name: "UserBinder.Username")&.tap { |f| f.value = username }
    form.field_with(name: "UserBinder.Password")&.tap { |f| f.value = password }
    form.field_with(name: "UserBinder.IsFromLogin")&.tap { |f| f.value = "True" }

    result_page = @agent.submit(form)
    return { success: false, error: "Credentials rejected." } if login_failed?(result_page)

    @club_slug = result_page.uri.to_s[%r{mywellness\.com/([^/]+)/}, 1]
    { success: true, club_slug: @club_slug }
  rescue => e
    { success: false, error: e.message }
  end

  def check_export_status(club_slug)
    page      = settings_page(club_slug)
    export_id = page.search(".download-button[data-val]").first&.attr("data-val")
    export_id.present? ? { status: "ready", export_id: export_id }
                       : { status: "pending", export_id: nil }
  rescue => e
    { status: "error", error: e.message }
  end

  def generate_export(club_slug, username, password)
    page               = settings_page(club_slug)
    token              = authenticated_token(page, username, password)
    user_id            = page.body[/window\.userId\s*=\s*'([^']+)'/, 1]
    existing_export_id = page.search(".download-button[data-val]").first&.attr("data-val")

    ajax_post("#{BASE_URL}/#{club_slug}/UserSettings/GenerateExport",
              { "Id" => user_id }, token, club_slug)

    { success: true, previous_export_id: existing_export_id }
  rescue => e
    { success: false, error: e.message }
  end

  def fetch_export(club_slug, username, password)
    page      = settings_page(club_slug)
    token     = authenticated_token(page, username, password)
    user_id   = page.body[/window\.userId\s*=\s*'([^']+)'/, 1]
    export_id = page.search(".download-button[data-val]").first&.attr("data-val")

    return { success: false, error: "No completed export found." } unless export_id

    body = ajax_get("#{BASE_URL}/#{club_slug}/UserSettings/DownloadExport/",
                    { UserId: user_id, ExportId: export_id }, token, club_slug)

    s3_uri = extract_s3_uri(body)
    return { success: false, error: "Could not extract S3 URL from response." } unless s3_uri

    tmp = Tempfile.new(["mywellness", ".zip"], binmode: true)
    tmp.write(@agent.get(s3_uri).body)
    tmp.flush
    { success: true, zip_path: tmp.path, tempfile: tmp }
  rescue => e
    { success: false, error: e.message }
  end

  private

  def settings_page(club_slug)
    @agent.get("#{BASE_URL}/#{club_slug}/UserSettings/AccountSettings/")
  end

  # Returns the best available token: fresh from services API, or current page token
  def authenticated_token(page, username, password)
    current_token = extract_token(page.body)
    fresh_token   = services_api_login(username, password, current_token)
    token         = fresh_token.presence || current_token
    # Set the _mwappseu cookie required for AJAX endpoints
    set_mwappseu_cookie(token)
    token
  end

  def ajax_post(url, body, token, club_slug)
    uri = URI("#{url}?_c=nl-NL&AppId=#{API_APP_ID}&token=#{URI.encode_www_form_component(token)}")
    http_request(Net::HTTP::Post, uri, body.to_json, token, club_slug)
  end

  def ajax_get(url, params, token, club_slug)
    query = params.merge(_c: "nl-NL", AppId: API_APP_ID,
                         token: token).map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
    uri   = URI("#{url}?#{query}")
    http_request(Net::HTTP::Get, uri, nil, token, club_slug)
  end

  def http_request(method_class, uri, body, token, club_slug)
    http      = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 30

    headers = {
      "Content-Type"     => "application/json",
      "Accept"           => "application/json, text/javascript, */*; q=0.01",
      "X-Requested-With" => "XMLHttpRequest",
      "Referer"          => "#{BASE_URL}/#{club_slug}/UserSettings/AccountSettings/",
      "Origin"           => BASE_URL,
      "User-Agent"       => USER_AGENT,
      "Cookie"           => cookie_header,
    }

    req      = method_class.new(uri.request_uri, headers)
    req.body = body if body
    http.request(req).body
  end

  def services_api_login(username, password, current_token)
    uri  = URI("#{SERVICES_BASE}/Application/#{API_APP_ID}/Login?_c=nl-NL")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 30

    req = Net::HTTP::Post.new(uri.request_uri, {
      "Content-Type"    => "application/json",
      "Accept"          => "application/json, text/javascript, */*; q=0.01",
      "x-mwapps-appid"  => API_APP_ID,
      "x-mwapps-client" => "enduserweb",
      "Origin"          => BASE_URL,
      "Referer"         => "#{BASE_URL}/",
    })
    req.body = { username: username, password: password,
                 "_c" => "nl-NL", AppId: API_APP_ID,
                 token: current_token.to_s }.to_json

    result = JSON.parse(http.request(req).body) rescue {}
    result.dig("data", "token") || result.dig("data", "Token") || result["token"]
  end

  def extract_token(html)
    if html =~ /EU\.currentUser\s*=\s*JSON\.parse\('(.+?)'\);/m
      begin
        return JSON.parse($1.gsub('\\"', '"'))["token"]
      rescue; end
    end
    html[/"token"\s*:\s*"([A-Za-z0-9+\/=._\-]{30,})"/, 1]
  end

  def extract_s3_uri(body)
    raw = body.match(/\\"uri\\":\\"((?:[^\\"]|\\.)*)/)&.[](1)
    return nil unless raw
    raw.gsub('\/', '/').gsub('\u0026', '&').gsub('\"', '"')
       .sub(/(%22|%7[Dd]|["%}])+$/i, '')
  end

  def set_mwappseu_cookie(token)
    cookie = Mechanize::Cookie.new(
      name:   "_mwappseu",
      value:  "#{API_APP_ID}|#{token}",
      domain: "v1.mywellness.com",
      path:   "/",
      secure: true
    )
    @agent.cookie_jar.add(URI("#{BASE_URL}/"), cookie)
  rescue; end

  def cookie_header
    cookies = @agent.cookie_jar.select { |c| c.domain&.include?("mywellness.com") }
    cookies.map { |c| "#{c.name}=#{c.value}" }.join("; ")
  end

  def login_failed?(page)
    page.uri.to_s.downcase.include?("/user/register") ||
    page.uri.to_s.downcase.include?("/user/login")
  end
end
