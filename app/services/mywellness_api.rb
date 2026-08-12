require "net/http"
require "json"

# Client for the Mywellness/Technogym app API.
#
# The legacy v1.mywellness.com web app (which the old export-based sync scraped)
# was retired in favour of the Technogym platform. This talks to the same API the
# Technogym phone app uses:
#
#   POST core.mywellness.com/v2/enduser/authentication/login  -> bearer token
#   GET  workout.mywellness.com/logbook?from=&to=             -> list of workouts
#   GET  workout.mywellness.com/logbook/workout/{idCr}         -> exercise detail
#   POST services.mywellness.com/Biometrics/User/{id}/LastBiometricsMeasurements
class MywellnessApi
  CORE_BASE     = "https://core.mywellness.com"
  WORKOUT_BASE  = "https://workout.mywellness.com"
  SERVICES_BASE = "https://services.mywellness.com"
  APP_ID        = "ec1d38d7-d359-48d0-a60c-d8c0b8fb9df9"
  CLIENT        = "tgapp"
  CLIENT_VER    = "3.45.1,tgapp"
  USER_AGENT    = "Technogym/3.45.1 (iPhone; iOS 26.0)"

  # The logbook endpoint is queried in windows rather than one huge range.
  WINDOW_DAYS = 90

  class Error < StandardError; end
  class AuthError < Error; end

  attr_reader :user_id, :facility_id

  def initialize(username, password)
    @username = username
    @password = password
  end

  def login
    body = post_json("#{CORE_BASE}/v2/enduser/authentication/login",
                     { username: @username, password: @password, keepMeLoggedIn: true },
                     headers)

    @token       = body["token"]
    @user_id     = body.dig("userContext", "id")
    @facility_id = body.dig("facilities", 0, "id")

    raise AuthError, login_error(body) if @token.blank? || @user_id.blank?

    self
  end

  # Workout summaries between two dates. Only "GenericWorkout" entries carry an
  # idCr and hold machine data; lifestyle/manual entries are dropped.
  def workouts(from:, to:)
    each_window(from, to).flat_map do |window_from, window_to|
      body = get_json("#{WORKOUT_BASE}/logbook", from: window_from.strftime("%Y%m%d"),
                                                 to:   window_to.strftime("%Y%m%d"))
      (body.dig("data", "logbooks") || []).select do |entry|
        entry["type"] == "GenericWorkout" && entry["idCr"].present?
      end
    end.uniq { |entry| entry["idCr"] }
  end

  # Full detail for one workout, including every exercise performed.
  def workout(id_cr)
    get_json("#{WORKOUT_BASE}/logbook/workout/#{id_cr}").fetch("data")
  end

  def last_biometrics
    body = post_json("#{SERVICES_BASE}/Biometrics/User/#{@user_id}/LastBiometricsMeasurements",
                     {}, authed_headers)
    body.dig("data", "lastMeasurements") || []
  end

  private

  def each_window(from, to)
    return enum_for(:each_window, from, to) unless block_given?

    cursor = from
    while cursor <= to
      window_end = [cursor + WINDOW_DAYS, to].min
      yield cursor, window_end
      cursor = window_end + 1
    end
  end

  def headers
    {
      "Content-Type"           => "application/json",
      "Accept"                 => "application/json",
      "X-MWAPPS-APPID"         => APP_ID,
      "X-MWAPPS-CLIENT"        => CLIENT,
      "X-MWAPPS-CLIENTVERSION" => CLIENT_VER,
      "User-Agent"             => USER_AGENT,
    }
  end

  def authed_headers
    raise AuthError, "Not logged in." if @token.blank?

    headers.merge("Authorization"       => "Bearer #{@token}",
                  "X-MWAPPS-FACILITYID" => @facility_id.to_s)
  end

  def get_json(url, **query)
    uri = URI(url)
    uri.query = URI.encode_www_form(query.merge(_c: "nl-NL"))
    request(Net::HTTP::Get.new(uri.request_uri, authed_headers), uri)
  end

  def post_json(url, body, request_headers)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri.request_uri, request_headers)
    req.body = body.to_json
    request(req, uri)
  end

  def request(req, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 20
    http.read_timeout = 60

    resp = http.request(req)
    raise AuthError, "Session rejected by Mywellness (HTTP 401)." if resp.code == "401"
    raise Error, "#{uri.host} returned HTTP #{resp.code}: #{resp.body.to_s.first(120)}" unless resp.code == "200"

    parsed = JSON.parse(resp.body.to_s)
    if parsed.is_a?(Hash) && parsed["errors"].present?
      raise Error, parsed["errors"].map { |e| e["message"] || e.to_s }.join(", ")
    end

    parsed
  rescue JSON::ParserError => e
    raise Error, "Could not parse response from #{uri.host}: #{e.message}"
  end

  def login_error(body)
    result = body["result"].presence
    case result
    when "WrongUsernameOrPassword", "InvalidCredentials" then "Credentials rejected by Mywellness."
    when nil then "Login failed - no token returned."
    else "Login failed: #{result}"
    end
  end
end
