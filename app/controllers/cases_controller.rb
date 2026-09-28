class CasesController < ApplicationController
  def index
    now = Time.current
    settings = OrganizationSettings.current
    config = Recovery.config
    rows = DeliveryCase.order(latest_event_at: :desc, id: :desc).map { |c| CasePresenter.new(c, Recovery::Policy.call(c.facts(settings), now: now, config: config)) }
    @counts = rows.group_by { |row| row.decision.recommended_action }.transform_values(&:size)
    @rows = filter(rows, params[:recommendation])
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

  def filter(rows, recommendation)
    return rows if recommendation.blank?
    return rows.select { |row| row.decision.recommended_action.nil? } if recommendation == "none"

    rows.select { |row| row.decision.recommended_action.to_s == recommendation }
  end

  def history(delivery_case)
    events = InboundEvent.where(reward_id: delivery_case.reward_id).map { |e| [ e.received_at, :event, e ] }
    transitions = delivery_case.transitions.order(:id).map { |t| [ t.created_at, :transition, t ] }
    (events + transitions).sort_by { |time, kind, record| [ time, kind == :event ? 0 : 1, record.id ] }
  end
end
