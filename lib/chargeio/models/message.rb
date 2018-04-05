#
# ChargeIO::Message
# -----------------

# Simple class for serializing ChargeIO <message> responses
class ChargeIO::Message
  attr_accessor :attributes, :level, :code, :context, :sub_code, :message, :facility

  def initialize(attributes)
    @attributes = attributes
    @level = attributes.with_indifferent_access['level']
    @code = attributes.with_indifferent_access['code']
    @sub_code = attributes.with_indifferent_access['sub_code']
    @context = attributes.with_indifferent_access['context']
    @message = attributes.with_indifferent_access['message']
    @facility = attributes.with_indifferent_access['facility']
  end

  DEFAULT_RESPONSE_MAPPINGS = {
    'error timeout' => 'The operation timed out'
  }

  def self.response_mappings
    @@response_mappings ||= DEFAULT_RESPONSE_MAPPINGS
  end
  def self.response_mappings=(_mappings)
    @@response_mappings = DEFAULT_RESPONSE_MAPPINGS.merge(_mappings)
  end

  def description
    # Check for overridden message definition
    _key = [level, code, context, sub_code].find_all{|i| i != nil}.join(' ')
    if self.class.response_mappings[_key].present?
      return self.class.response_mappings[_key]
    end

    _key = [level, code, context].find_all{|i| i != nil}.join(' ')
    if self.class.response_mappings[_key].present?
      return self.class.response_mappings[_key]
    end

    _key = [level, code].find_all{|i| i != nil}.join(' ')
    if self.class.response_mappings[_key].present?
      self.class.response_mappings[_key]
    end

    message || "Unknown ChargeIO #{level.capitalize}"
  end

end
