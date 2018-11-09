# frozen_string_literal: true

module Kasket
  module Instrumentation
    def instrument(metric, &block)
      return yield unless Kasket.statsd_client

      model_name = self.class.name == 'Class' ? name : self.class.name

      Kasket.statsd_client.time(metric, tags: %W[model:#{model_name}], &block)
    end
  end
end
