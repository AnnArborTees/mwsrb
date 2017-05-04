require 'openssl'

module Mwsrb
  #
  # Represents one of MWS's API "categories" i.e. "Products", or
  # "Fulfillment Inventory".
  #
  class Api
    Quota = Struct.new(:remaining, :resets_on) do
      def self.create(headers)
        remaining = headers['x-mws-quota-remaining']
        resets_on = headers['x-mws-quota-resetson']

        return nil if remaining.blank? || resets_on.blank?

        new(remaining.to_i, DateTime.parse(resets_on))
      end
    end
    ThrottledError = Class.new(StandardError)

    attr_reader :name
    attr_reader :verb
    attr_reader :merchant
    attr_reader :client
    attr_accessor :debug_log

    def initialize(name, options = {})
      @name        = name.to_s
      @verb        = (options[:verb] || 'POST').upcase

      @endpoint    = options[:endpoint]
      @user_agent  = options[:user_agent]  || 'MWSRB'
      @merchant    = options[:merchant]    || options[:seller_id] || options[:merchant_id]
      @marketplace = options[:marketplace] || Mwsrb::Marketplace::US
      @debug_log   = options[:log]         || options[:debug_log]
      @debug_log   = STDOUT.method(:puts) if @debug_log == true

      @params      = resolve_lists_and_dates(options[:params] || {})
      @headers     = default_headers.merge(options[:headers] || {})

      if @params.respond_to?(:stringify_keys)
        @params = @params.stringify_keys
      end

      @client      = options[:client]

      @aws_access_key_id = options[:aws_access_key_id]
      @secret_access_key = options[:secret_access_key]

    end


    #
    # Inspect is overridden so as to not leak the secret access key
    # into logs.
    #
    def inspect
      "<Mwsrb::Api(#{@verb} #{@name}):#{object_id}>"
    end


    def request(operation, params = {})
      raise "Must provide :aws_access_key_id"   if @aws_access_key_id.blank?
      raise "Must provide :secret_access_key"   if @secret_access_key.blank?
      raise "Must provide :seller or :merchant" if @merchant.blank?

      verb = (params.delete(:verb) || @verb).upcase
      endpoint = (params.delete(:endpoint) || @endpoint)

      log { "=== Begin MWS request #{Time.now}" }

      begin
        # Grab throttling data
        throttling_key = "#{name}##{operation}"
        quota = client.throttling[throttling_key]

        # Wait for throttling to cool down
        if quota.present?
          if quota.remaining <= 0 && DateTime.now < quota.resets_on
            sleep_time = quota.resets_on - DateTime.now + 0.5
            log { "Waitng #{sleep_time} seconds to avoid throttling" }
            sleep sleep_time
          end
        end

        # Headers can be specified with special :headers
        # key passed as a param.
        headers =
          @headers
          .merge(params.delete(:headers) || {})

        # Request body will first check the params option
        # sent during construction, then merge in params passed
        # to this method, then merge in necessary options.
        body =
          default_params
          .merge(@params)
          .merge(resolve_lists_and_dates(params.try(:stringify_keys) || params))
          .merge({
            'Action'         => operation,
            'AWSAccessKeyId' => @aws_access_key_id
          })
          .sort
          .to_h
          .with_indifferent_access

        path = "/#{name}/#{body[:Version]}"

        # This 'canonical' is encrypted to form a signature
        # that will be checked by the Amazon API.
        canonical = [
          verb,
          Mwsrb::Client.base_uri.gsub(/^.+:\/\//, ''),
          path,
          body.to_query
        ].join("\n")

        # Generate signature, signed with the secret key.
        signature = generate_signature(@secret_access_key, canonical)
        body[:Signature] = signature

        log do
          [
            "PATH:  #{path}",
            "HEADERS:\n#{JSON.pretty_generate(headers)}",
            "BODY:\n#{JSON.pretty_generate(body)}",
            "CANONICAL:\n  #{canonical.split("\n").join("\n  ")}\n"
          ]
        end

        response = Mwsrb::Response.new(
          Mwsrb::Client.send(
            verb.downcase, "#{path}?#{body.to_query}",
            headers: headers,
            base_uri: endpoint
          )
        )

        # Update throttling information for next request
        quota = Quota.create(response.headers)

        if quota
          client.throttling[throttling_key] = quota
        else
          # See if we've been throttled (some api calls don't provide this information)
          msg = response.at_css "Error Message"

          if msg.present? && msg.content == "Request is throttled"
            sleep_time = 10.seconds

            log { "Request throttled! Waiting #{sleep_time} seconds" }
            sleep sleep_time

            # Try again
            raise ThrottledError
          end
        end

        response

      rescue ThrottledError
        retry
      end

    ensure
      log { "=== End MWS request #{Time.now}" }
    end

    alias_method :call, :request

    def generate_signature(secret_access_key, canonical)
      digest = OpenSSL::Digest.new('sha256')
      Base64.encode64(OpenSSL::HMAC.digest(digest, secret_access_key, canonical)).chomp
    end


    private

    #
    # Turns arrays into the ListName.Element.N format that
    # MWS expects.
    #
    # Encodes time/datetime objects in iso-8601.
    #
    def resolve_lists_and_dates(params)
      new_params = {}

      params.each do |key, value|
        case value
        when Array
          inferred_el_name = element_name(key)

          # element_counts will usually look something like:
          # { Id: 3 }
          element_counts = Hash.new(0)

          value.each do |element|
            if element.is_a?(Hash)
              # `value` is in the form:
              # [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }]
              #
              # NOTE this "each" will generally only hit one element
              element.each do |el_name, el_val|
                count = (element_counts[el_name] += 1)
                new_params["#{key}.#{el_name}.#{count}"] = el_val
              end

            else

              # Here we use the inferred "element names" by the camelcase key name
              count = (element_counts[inferred_el_name] += 1)
              new_params["#{key}.#{inferred_el_name}.#{count}"] = element
            end
          end

        when Time, DateTime
          new_params[key] = value.iso8601
        else
          new_params[key] = value
        end
      end

      new_params
    end

    #
    # Breaks out the "Id" from "OrderId"
    #
    def element_name(key)
      key = key.to_s
      size = key.size

      key.each_char.reverse_each.with_index do |ch, i|
        if ch == ch.upcase
          return key[(size - i - 1)..-1]
        end
      end
      raise "Invalid key '#{key}'"
    end

    #
    # Most recent API versions as of 2017-04-07
    #
    def default_version
      case @name
      when 'Products'             then "2011-10-01"
      when 'Orders'               then "2013-09-01"
      when 'FulfillmentInventory' then "2010-10-01"
      when 'Feeds'                then "2009-01-01"
      when 'Reports'              then "2009-01-01"
      when 'MerchantFulfillment'  then "2015-06-01"
      else "2009-01-01"
      end
    end

    #
    # Headers always present in any request unless overridden.
    #
    def default_headers
      {
        'User-Agent'   => @user_agent,
        'Content-Type' => 'x-www-form-urlencoded'
      }
    end

    #
    # Parameters always present in any request unless overridden.
    #
    def default_params
      {
        'SellerId'         => @merchant,
        'SignatureMethod'  =>'HmacSHA256',
        'SignatureVersion' =>'2',
        'Timestamp'        => Time.now.iso8601,
        'Version'          => default_version
      }
    end

    #
    # Log is called with a block rather than a parameter so that the
    # message expression is not evaluated unless a log function is
    # specified.
    #
    def log
      return if @debug_log.nil?
      msg = yield
      if msg.respond_to?(:each)
        msg.each { |m| @debug_log.call m }
      else
        @debug_log.call msg
      end
    end
  end
end
