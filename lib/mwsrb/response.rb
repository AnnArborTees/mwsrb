module Mwsrb
  class Response
    attr_reader :response
    alias_method :httparty, :response

    delegate :body, :headers, to: :response
    delegate :css, :xpath,    to: :nokogiri

    def initialize(httparty_response)
      @response = httparty_response
    end

    def to_h
      @response.parsed_response
    end

    def nokogiri
      @nokogiri ||= Nokogiri::XML(@response.body).tap(&:remove_namespaces!)
    end
  end
end
