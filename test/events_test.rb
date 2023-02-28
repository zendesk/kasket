# frozen_string_literal: true

require_relative "helper"

describe Kasket::Events do
  before do
    @previous = Kasket::CONFIGURATION[:events_callback]
    Kasket::Events.remove_instance_variable(:@fn) if Kasket::Events.instance_variable_defined?(:@fn)
  end

  after { Kasket::CONFIGURATION[:events_callback] = @previous }

  describe ".report" do
    describe "when there is no stats callback configured" do
      before do
        Kasket::CONFIGURATION[:events_callback] = nil
      end

      it "does nothing and returns safely" do
        assert_nil Kasket::Events.report("something", Author)
      end
    end

    describe "when a stats callback is configured" do
      before do
        @event = nil
        @ar_klass = nil

        callback = proc do |event, ar_klass|
          @event = event
          @ar_klass = ar_klass
        end

        Kasket::CONFIGURATION[:events_callback] = callback
      end

      it "returns safely" do
        assert_nil Kasket::Events.report("something", Author)
      end

      it "invokes the callback" do
        assert_nil @event
        assert_nil @ar_klass

        Kasket::Events.report("something", Author)

        assert_equal "something", @event
        assert_equal Author, @ar_klass
      end
    end
  end
end
