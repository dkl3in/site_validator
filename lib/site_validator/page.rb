# -*- encoding: utf-8 -*-

require 'timeout'
require 'w3c_validators'
include W3CValidators

module SiteValidator
  ##
  # A page has an URL to be validated, and a collection of errors
  # In case of an exception happens when validating, it is tracked
  #
  class Page
    attr_accessor :url, :timeout, :exception

    def initialize(url, timeout = 20)
      @url      = url
      @timeout  = timeout
    end

    ##
    # Checks for errors and returns true if none found, false otherwise.
    # Warnings are not considered as validation errors so a page with
    # warnings but without errors will return true.
    # If the validation goes well, errors should be an array. Otherwise
    # it will still be nil, which will not be considered validated.
    def valid?
      !errors.nil? && errors.empty?
    end

    ##
    # Returns the collection of errors from the validations of this page.
    # If it has no validation errors, it will be an empty array.
    # It an exception occurs, it will be nil.
    def errors
      @errors ||= validations.errors
                    .select {|e| e.message_id && !e.message_id.empty?}
                    .map do |e|
        SiteValidator::Message.new(e.message_id, e.line, e.col, e.message, :error, e.source, prepare_w3c_explanation(e))
      end
    rescue Exception => e
      @exception = e.to_s
      nil
    end

    ##
    # Returns the collection of warnings from the validations of this page.
    # If it has no validation warnings, it will be an empty array.
    # It an exception occurs, it will be nil.
    def warnings
      @warnings ||= validations.warnings
                     .select {|w| w.message_id && !w.message_id.empty?}
                     .map do |w|
        SiteValidator::Message.new(w.message_id, w.line, w.col, w.message, :warning, w.source, prepare_w3c_explanation(w))
      end
    rescue Exception => e
      @exception = e.to_s
      nil
    end

    private

    ##
    # Gets the validations for this page, ensuring it times out soon
    def validations
      @validations ||= Timeout::timeout(timeout) { markup_validator.validate_uri(url) }
    end

    ##
    # Returns an instance of MarkupValidator, with the URL set to the one in ENV or its default
    def markup_validator
      @markup_validator ||= MarkupValidator.new(:validator_uri => ENV['W3C_MARKUP_VALIDATOR_URI'] || 'http://validator.w3.org/check')
    end

    ##
    # Fixes the link to give feedback to the W3C
    def prepare_w3c_explanation(message)
      explanation = message.explanation

      if explanation
        explanation.strip!
        explanation.gsub!("our feedback channels", "the W3C feedback channels")
        explanation.gsub!("feedback.html", "http://validator.w3.org/feedback.html")
      end

      explanation
    end
  end
end
