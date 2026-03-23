class SyncController < ApplicationController
  before_action :load_scraper

  def generate
    result = @scraper.generate_export(@club_slug, @username, @password)
    if result[:success]
      Setting.set("mywellness_last_export_id", result[:previous_export_id].to_s)
      redirect_to poll_sync_path
    else
      redirect_to root_path, alert: "Could not start export: #{result[:error].to_s.first(80)}"
    end
  end

  def poll
    last_id        = Setting.get("mywellness_last_export_id").to_s
    status         = @scraper.check_export_status(@club_slug)
    @export_status   = status[:status]
    @refresh_seconds = 15

    if status[:status] == "ready" && status[:export_id].present? && status[:export_id] != last_id
      export_result = @scraper.fetch_export(@club_slug, @username, @password)
      return redirect_to root_path, alert: "Download failed." unless export_result[:success]

      importer = WorkoutImporter.new.import_zip(export_result[:zip_path])
      export_result[:tempfile]&.close
      export_result[:tempfile]&.unlink
      Setting.set("mywellness_last_export_id", status[:export_id])
      redirect_to root_path, notice: "Sync complete! #{importer.new_count} new sessions imported."
    end
  end

  private

  def load_scraper
    @username  = Setting.get("mywellness_username")
    @password  = Setting.get("mywellness_password")
    @club_slug = Setting.get("mywellness_club_slug")

    return redirect_to settings_path, alert: "Please save your credentials first." if @username.blank? || @password.blank?

    @scraper     = MywellnessScraper.new
    login_result = @scraper.login(@username, @password)
    redirect_to root_path, alert: "Login failed." unless login_result[:success]
  end
end