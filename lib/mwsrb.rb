require "mwsrb/version"
require "mwsrb/marketplace"
require "mwsrb/response"
require "mwsrb/client"
require "mwsrb/api"

module Mwsrb
end

unless defined?(Amazon)
  Amazon = Mwsrb
end
