module Kasket
  VERSION = '4.4.3'
  class Version
    MAJOR = Kasket::VERSION.split('.')[0]
    MINOR = Kasket::VERSION.split('.')[1]
    PATCH = Kasket::VERSION.split('.')[2]
    STRING = "#{MAJOR}.#{MINOR}.#{PATCH}"
    PROTOCOL = 4
  end
end
