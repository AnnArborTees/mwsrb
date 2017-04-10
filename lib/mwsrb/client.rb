require 'httparty'

module Mwsrb
  class Client
    include HTTParty
    base_uri 'https://mws.amazonservices.com'

    attr_reader :options

    # Mwsrb::Client (AKA Amazon::Client) can be used like
    #
    # ``` ruby
    # client = Amazon::Client.new(
    #   aws_access_key_id: '<your access key id>',
    #   secret_access_key: '<your secret access key>',
    #   merchant_id:       '<your merchant/seller-id>',
    #   marketplace:       Amazon::Marketplace::CA # <-- defaults to US
    #   params: { MarketplaceId: '<your marketplace id>' }
    # )
    #
    # response = cilent['Products'].request(
    #   'GetMatchingProductForId',
    #   IdType: 'ASIN',
    #   IdList: => [{ Id: 'ASDFGVWE' }, { Id: 'OOBIEUIH' }]
    # )
    # ```
    #
    #
    # And then `response` will be a straight-up HTTParty response object.
    # The response content can be accessed in two ways:
    #
    #   1. `response.parsed_response`  returns a hash parsed from Amazon's XML response
    #   2. `response.body`             returns the raw XML string
    #
    def initialize(options = {})
      @options = infer_options_from_figaro.merge(options)
    end

    def inspect
      "<Mwsrb::Client:#{object_id}>"
    end

    def [](api_category, options = {})
      category = api_category.gsub(' ', '')
      Mwsrb::Api.new(category, @options.merge(options).merge(client: self))
    end

    # TODO some kind of throttling handling.
    # Perhaps keep a hash of { Operation => Last Throttling Headers }.

    private

    #
    # If no options are supplied, we can infer them from Application.yml
    # through Figaro using some standard key names.
    #
    def infer_options_from_figaro
      return {} unless defined?(Figaro)

      options = {}
      set = -> key {
        if (val = Figaro.env.send("mws_#{key}") || Figaro.env.send(key))
          options[key] = val
        end
        options
      }

      set[:aws_access_key_id]
      set[:secret_access_key]
      set[:merchant_id]
      set[:marketplace]
      set[:user_agent]
    end
  end
end
