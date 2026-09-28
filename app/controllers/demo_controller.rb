class DemoController < ApplicationController
  def show
    @case_count = DeliveryCase.count
  end

  def start
    Demo::Tour.begin!(session)
    redirect_to demo_step_path(1)
  end

  def restart
    start
  end

  def step
    return redirect_to(demo_path) if Demo::Tour.current(session).nil?

    number = Integer(params[:number], exception: false)
    step = number && Demo::Tour.step(number)
    return redirect_to(demo_path, alert: "There is no demo step #{params[:number]}.") if step.nil?

    Demo::Tour.go_to(session, step.number)
    return redirect_to(root_path) if step.reward_id.nil?

    delivery_case = Demo::Tour.destination_case(step)
    if delivery_case
      redirect_to case_path(delivery_case)
    else
      Demo::Tour.go_to(session, 1)
      redirect_to root_path, alert: "Simulate incoming delivery events first."
    end
  end

  def simulate
    return redirect_to(demo_path) if Demo::Tour.current(session).nil?

    Demo::Tour.go_to(session, 1)
    result = Demo::Tour.simulate!
    flash[:demo] = "#{result.accepted} events accepted · #{result.duplicates} duplicates ignored"
    redirect_to root_path
  end

  def finish
    Demo::Tour.go_to(session, Demo::Tour::FINISH)
  end

  def leave
    Demo::Tour.leave(session)
    redirect_to root_path
  end
end
