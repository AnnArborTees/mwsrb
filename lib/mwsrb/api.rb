require 'openssl'

module Mwsrb
  #
  # Represents one of MWS's API "categories" i.e. "Products", or
  # "Fulfillment Inventory".
  #
  class Api
    attr_reader :name
    attr_reader :verb
    attr_reader :merchant
    attr_accessor :debug_log

    def initialize(name, options = {})
      @name        = name.to_s
      @verb        = (options[:verb] || 'POST').upcase

      @user_agent  = options[:user_agent]  || 'MWSRB'
      @merchant    = options[:merchant]    || options[:seller_id] || options[:merchant_id]
      @marketplace = options[:marketplace] || Mwsrb::Marketplace::US
      @debug_log   = options[:log]         || options[:debug_log]

      @params      = resolve_lists_and_dates(default_params.merge(options[:params] || {}))
      @headers     = default_headers.merge(options[:headers] || {})

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

      log { "=== Begin MWS request #{Time.now}" }

      # Headers can be specified with special :headers
      # key passed as a param.
      headers =
        @headers
        .merge(params.delete(:headers) || {})

      # Request body will first check the params option
      # sent during construction, then merge in params passed
      # to this method, then merge in necessary options.
      body =
        @params.stringify_keys
        .merge(resolve_lists_and_dates(params.stringify_keys))
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

      Mwsrb::Client.send(verb.downcase, "#{path}?#{body.to_query}", headers: headers)

    ensure
      log { "=== End MWS request #{Time.now}" }
    end

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
          # element_counts will usually look something like:
          # { Id: 3 }
          element_counts = Hash.new(0)

          value.each do |element|
            unless element.is_a?(Hash)
              raise "Array params values must be in the form "\
                    "[{ Id: 'ASDFG' }, { Id: 'FDDSAG' }]"
            end

            # NOTE this "each" will generally only hit one element
            element.each do |el_name, el_val|
              element_counts[el_name] += 1
              new_params["#{key}.#{el_name}.#{element_counts[el_name]}"] = el_val
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
    # Most recent API versions as of 2017-04-07
    #
    def default_version
      case @name
      when 'Products'             then "2011-10-01"
      when 'Orders'               then "2013-09-01"
      when 'FulfillmentInventory' then "2010-10-01"
      when 'Feeds'                then "2009-01-01"
      when 'Reports'              then "2009-01-01"
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
