module Transactionata
  #
  # Hook for creating test data ONCE alongside fixtures that will then be rolled back
  # via transactions after each test, so you can set up complex data via Factories etc.
  # without the speed drop.
  #
  # Please note that you'll have to set up empty fixture files (and load them, see
  # the list of fixtures above) in order to clean up the database before you launch
  # your tests.
  #
  # Usage: In your test class, do:
  #   test_data do
  #     Factory.create(:foobar)
  #     # etc...
  #
  #     # or for Machinist
  #     @person =  Person.make
  #   end
  #
  # The foobar and @person record will be available in all your tests and rolls back
  # even if you modify it in your test cases thanks to transactions.
  #
  def test_data(&blk)
    self.class_eval do
      class << self
      end

      class_attribute :_test_data_block
      class_attribute :_test_data_vars

      setup :load_test_data_vars

      alias_method :original_load_fixtures, :load_fixtures
      def load_fixtures(*config)
        # We need to return the value of the original load_fixtures method, so that all the fixtures magic works
        hash = original_load_fixtures(*config)
        existing_klass_instance_vars = self.class.instance_variables
        self.class._test_data_block.call
        self.class._test_data_vars ||= {}

        vars = (self.class.instance_variables - existing_klass_instance_vars)

        vars.each do |var|
          self.class._test_data_vars[var] = self.class.instance_variable_get(var)
        end

        if defined?(ActiveRecord::FixtureSet) # Rails 4
          ActiveRecord::FixtureSet.reset_cache
        elsif defined?(ActiveRecord::Fixtures) # Rails 3.1
          ActiveRecord::Fixtures.reset_cache
        else
          Fixtures.reset_cache # Required to enforce purging tables for every test file
        end
        hash
      end

      def load_test_data_vars
        self.class._test_data_vars.each do |(new_ivar, value)| # Added block
          self.instance_variable_set(new_ivar, value)
        end
      end
    end

    self._test_data_block = blk
  end
end

if defined?(ActiveSupport::TestCase)
  ActiveSupport::TestCase.send :extend, Transactionata
end
