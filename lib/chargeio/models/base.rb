class ChargeIO::Base
  include ChargeIO::Connection
  attr_reader :gateway, :messages, :errors, :attributes

  def initialize(_attributes={})
    if _attributes[:gateway].present?
      @gateway = _attributes.delete(:gateway)
    else
      @gateway = ChargeIO::Gateway.new(:site => _attributes.delete(:site) || ChargeIO::DEFAULT_SITE,
                                       :secret_key => _attributes.delete(:secret_key),
                                       :auth_user => _attributes.delete(:auth_user),
                                       :auth_password => _attributes.delete(:auth_password))
    end
    raise ArgumentError.new("Gateway not set") unless gateway

    @attributes = _attributes.with_indifferent_access
    @errors     = {}
    @messages   = []

  end

  def inspect(full_output=false)
    full_output ? super() : attributes.inspect
  end

  def as_json(options={})
    { 'attributes' => @attributes, 'errors' => @errors, 'messages' => @messages}
  end

  def id
    attributes['id']
  end

  def created
    attributes[:created].present? ? Time.parse(attributes[:created]) : nil
  end


  def method_missing(method_symbol, *arguments)
    method_name = method_symbol.to_s

    if method_name =~ /(\?)$/
      case $1
        when "?"
          attributes[$`]
      end
    else
      return attributes[method_name] if attributes.include?(method_name)
      # not set right now but we know about it
      #return nil if known_attributes.include?(method_name)
      super
    end
  end

  def process_response_errors(attributes)
    messages.clear
    errors.clear

    messages_attributes = attributes['messages']
    if messages_attributes.present?
      add_messages(messages_attributes)
    end
    self
  end

  protected
  def add_messages(messages_attributes)
    messages_attributes.each do |message_attributes|
      message = ChargeIO::Message.new(message_attributes)
      messages << message
      if message.level == 'error'
        index = message.context.present? ? message.context : 'base'
        self.errors[index] = self.errors[index] || []
        self.errors[index] << message.description if self.errors[index].blank?
      end
    end
  end

  def replace(obj)
    obj.errors.blank? ? attributes.replace(obj.attributes) : errors.replace(obj.errors)
    messages.replace(obj.messages)
  end

  def update(params={})
    @attributes = attributes.update(params).with_indifferent_access
  end
end
