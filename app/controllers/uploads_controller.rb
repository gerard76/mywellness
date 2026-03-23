class UploadsController < ApplicationController
  def new
  end

  def create
    file = params[:file]
    return redirect_to new_upload_path, alert: "Please select a file." unless file

    importer = WorkoutImporter.new.import_json(file.read)
    msg = "Import complete: #{importer.new_count} new sessions"
    msg += ", #{importer.updated_count} updated" if importer.updated_count > 0
    redirect_to root_path, notice: msg
  rescue JSON::ParserError => e
    redirect_to new_upload_path, alert: "Invalid JSON: #{e.message.first(80)}"
  rescue => e
    redirect_to new_upload_path, alert: "Import error: #{e.message.first(80)}"
  end
end
