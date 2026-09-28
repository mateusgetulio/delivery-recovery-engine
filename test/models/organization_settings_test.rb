require "test_helper"

class OrganizationSettingsTest < ActiveSupport::TestCase
  test "there is one settings row and it starts unregistered" do
    settings = OrganizationSettings.current

    refute settings.relay_domain_registered
    assert_equal settings, OrganizationSettings.current
    assert_equal settings, OrganizationSettings.current(lock: true)
    assert_equal 1, OrganizationSettings.count
  end
end
