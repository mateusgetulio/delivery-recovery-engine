class CaseActionsController < ApplicationController
  def create
    Recovery::Act.call(
      params[:case_id],
      params[:action_name],
      expected_lock_version: Integer(params[:lock_version]),
      now: Time.current,
      params: params.permit(:destination).to_h.symbolize_keys
    )
    redirect_to case_path(params[:case_id]), notice: "Recorded #{params[:action_name].to_s.humanize.downcase}."
  rescue Recovery::StaleCaseVersion
    redirect_to case_path(params[:case_id]), alert: "This case changed since it was shown. Reload and decide again."
  rescue Recovery::Error => e
    redirect_to case_path(params[:case_id]), alert: e.message
  end
end
