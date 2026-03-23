class MachinesController < ApplicationController
  def index
    @machines = Machine.order(:name, :ph_id)
  end

  def update
    @machine = Machine.find(params[:id])
    if @machine.update(machine_params)
      redirect_to machines_path, notice: "#{@machine.display_name} updated."
    else
      @machines = Machine.order(:name, :ph_id)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def machine_params
    params.require(:machine).permit(:name, :muscle_group)
  end
end
