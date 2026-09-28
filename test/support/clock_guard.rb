module ClockGuard
  def forbidding_clock_reads
    originals = { now: Time.method(:now), current: Time.method(:current) }
    originals.each_key do |name|
      Time.define_singleton_method(name) { raise "the code under test read Time.#{name}" }
    end
    yield
  ensure
    originals.each { |name, original| Time.define_singleton_method(name, original) }
  end
end
