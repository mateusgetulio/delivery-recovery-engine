module ApplicationHelper
  def demo_panel
    return @demo_panel if defined?(@demo_panel)

    number = Demo::Tour.current(session)
    @demo_panel = number && number < Demo::Tour::FINISH ? DemoPanel.new(number) : nil
  end
end
