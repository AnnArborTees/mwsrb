module Mwsrb
  class Response
    def self.delegate(*methods, options)
      methods.each do |name|
        class_eval <<-RUBY
        def #{name}(*args, &block)
          #{options[:to]}.#{name}(*args, &block)
        end
        RUBY
      end
    end

    attr_reader :response
    alias_method :httparty, :response

    delegate :body, :headers, :parsed_response, to: :response
    delegate :css, :xpath, :at_css, :at_xpath,  to: :nokogiri

    def initialize(httparty_response)
      @response = httparty_response
    end

    def inspect
      "#<Mwsrb::Response:#{object_id} body=\"#{body}\">"
    end

    def to_h
      @response.parsed_response
    end

    def nokogiri
      @nokogiri ||= Nokogiri::XML(@response.body).tap(&:remove_namespaces!)
    end

    def error
      error_element = css 'Error'
      return nil if error_element.blank?

      "#{error_element.css('Type').content}: #{error_element.css('Message').content}"
    end
  end
end
