class SettingsController < ApplicationController
  def show
    @username   = Setting.get("mywellness_username") || ""
    @has_password = Setting.get("mywellness_password").present?
    @club_slug  = Setting.get("mywellness_club_slug") || ""
  end

  def update
    Setting.set("mywellness_username", params[:username].to_s.strip) if params[:username].present?
    Setting.set("mywellness_password", params[:password].to_s)        if params[:password].present?
    Setting.set("mywellness_club_slug", params[:club_slug].to_s.strip) if params[:club_slug].present?
    redirect_to settings_path, notice: "Settings saved."
  end
end