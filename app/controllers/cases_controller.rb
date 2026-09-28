class CasesController < ApplicationController
  def index
    now = Time.current
    settings = OrganizationSettings.current
    config = Recovery.config
    cases = DeliveryCase.order(latest_event_at: :desc, id: :desc).to_a
    @rows = cases.map { |c| CasePresenter.new(c, Recovery::Policy.call(c.facts(settings), now: now, config: config)) }
    @rows = @rows.select { |row| row.decision.recommended_action.to_s == params[:recommendation] } if params[:recommendation].present?
    @counts = cases.group_by { |c| Recovery::Policy.call(c.facts(settings), now: now, config: config).recommended_action }.transform_values(&:size)
    @inbox = {
      pending: InboundEvent.pending.count,
      failed: InboundEvent.where(status: "failed").count,
      rejected_requests: RejectedRequest.count,
      rejected_signatures: IngestionCounter.current.rejected_signatures,
      duplicates: InboundEvent.sum(:duplicates_seen)
    }
  end

  def show
    @delivery_case = DeliveryCase.find(params[:id])
    @settings = OrganizationSettings.current
    @decision = Recovery::Policy.call(@delivery_case.facts(@settings), now: Time.current, config: Recovery.config)
    @presenter = CasePresenter.new(@delivery_case, @decision)
    @history = history(@delivery_case)
  end

  private

  def history(delivery_case)
    events = InboundEvent.where("payload ->> 'reward_id' = ?", delivery_case.reward_id).map { |e| [ e.received_at, :event, e ] }
    transitions = delivery_case.transitions.order(:id).map { |t| [ t.created_at, :transition, t ] }
    (events + transitions).sort_by { |time, kind, record| [ time, kind == :event ? 0 : 1, record.id ] }
  end
end
