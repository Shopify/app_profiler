# frozen_string_literal: true

module AppProfiler
  module TestHelper
    def setup
      super
      FileUtils.rm(tmp_profiles)
    end

    def assert_profiles_dumped(n = 1)
      assert_empty(tmp_profiles)
      yield
      assert_equal(n, tmp_profiles.count, "Expected #{n} new profiles in block, but got #{tmp_profiles.count}")
    end

    def assert_profiles_uploaded(autoredirect: false)
      AppProfiler.stubs(:storage).returns(MockStorage)
      AppProfiler.logger.expects(:info).with { |value| value =~ /uploaded profile/ }

      response = yield

      assert_predicate(response[1][AppProfiler.profile_header], :present?)
      assert_predicate(response[1][AppProfiler.profile_data_header], :present?)

      if autoredirect
        assert_predicate(response[1]["Location"], :present?)
        assert_equal(response[0], 303)
      else
        assert_predicate(response[1]["Location"], :blank?)
        assert_equal(response[0], 200)
      end
    end

    def with_context(new_context)
      old_context = AppProfiler.context
      AppProfiler.context = new_context
      yield
    ensure
      AppProfiler.context = old_context
    end

    def with_authorization_required
      AppProfiler.request_authorization_required = true
      yield
    ensure
      AppProfiler.send(:deauthorize_request)
      AppProfiler.request_authorization_required = false
    end

    private

    def tmp_profiles
      AppProfiler.profile_root.glob("*.json")
    end
  end
end
