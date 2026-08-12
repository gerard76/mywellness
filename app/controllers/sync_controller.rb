class SyncController < ApplicationController
  # How far back to look on a first sync, and how much overlap to re-check on
  # later ones (a workout can be amended after the fact).
  INITIAL_LOOKBACK_DAYS = 365
  OVERLAP_DAYS          = 7

  def create
    username = Setting.get("mywellness_username")
    password = Setting.get("mywellness_password")
    return redirect_to settings_path, alert: "Please save your credentials first." if username.blank? || password.blank?

    api = MywellnessApi.new(username, password).login
    importer = WorkoutImporter.new

    api.workouts(from: sync_from, to: Date.today).each do |summary|
      importer.import_workout(api.workout(summary["idCr"]))
    end
    importer.import_biometric_measurements(api.last_biometrics)

    Setting.set("mywellness_last_synced_at", Time.current.iso8601)
    redirect_to root_path, notice: sync_summary(importer)
  rescue MywellnessApi::AuthError => e
    redirect_to settings_path, alert: "Mywellness login failed: #{e.message.first(160)}"
  rescue MywellnessApi::Error => e
    redirect_to root_path, alert: "Sync failed: #{e.message.first(200)}"
  end

  private

  # Resume from the last workout we already have, minus a small overlap.
  def sync_from
    last = WorkoutSession.maximum(:workout_date)
    last ? last - OVERLAP_DAYS : Date.today - INITIAL_LOOKBACK_DAYS
  end

  def sync_summary(importer)
    parts = ["#{importer.new_count} new sessions"]
    parts << "#{importer.updated_count} updated" if importer.updated_count > 0
    parts << "#{importer.biometric_count} new measurements" if importer.biometric_count > 0
    "Sync complete: #{parts.join(', ')}."
  end
end
