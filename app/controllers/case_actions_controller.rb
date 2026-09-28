class CaseActionsController < ApplicationController
  def create
    action = params[:action_name].to_s
    Recovery::Act.call(
      params[:case_id],
      action,
      expected_lock_version: Integer(params[:lock_version], exception: false),
      now: Time.current,
      params: params.permit(:destination).to_h.symbolize_keys
    )
    Demo::Tour.advance_after_action(session, action)
    redirect_to case_path(params[:case_id]), notice: "#{CasePresenter.action_label(action)} recorded. Nothing was sent."
  rescue Recovery::StaleCaseVersion
    redirect_to case_path(params[:case_id]), alert: "This case changed since it was shown. Reload and decide again."
  rescue Recovery::Error => e
    redirect_to case_path(params[:case_id]), alert: e.message
  end
end
