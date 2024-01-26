# frozen_string_literal: true

module Kasket
  # Interface to the internal instrumentation event.
  module Events
    class << self
      # Invokes the configured events callback, if provided.
      #
      # The callback behaves like a listener, and receives the same arguments
      # that are passed to this `report` method.
      #
      # @param [String] event the type of event being instrumented.
      # @param [class] ar_klass the ActiveRecord::Base subclass that the event
      #   refers to.
      #
      # @return [nil]
      #
      def report(event, ar_klass)
        return unless fn

        fn.call(event, ar_klass)
        nil
      end

      private

      def fn
        return @fn if defined?(@fn)

        @fn = Kasket::CONFIGURATION[:events_callback]
      end
    end
  end
end
