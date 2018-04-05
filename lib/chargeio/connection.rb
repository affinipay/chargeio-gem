module ChargeIO::Connection
  DEFAULT_TIMEOUT = 300
  USER_AGENT = "chargeio-gem/#{ChargeIO::VERSION}"

  private

  def get(uri, id=nil, params={}, headers={})
    request = HTTParty::Request.new(Net::HTTP::Get,
                                    id.blank? ? "#{self.gateway.url}#{uri}" : "#{self.gateway.url}#{uri}/#{id}",
                                    :headers => headers.merge({'content-type' => 'application/json', 'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    :format => :json,
                                    :default_params => params,
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def post(uri, params=nil, headers={})
    request = HTTParty::Request.new(Net::HTTP::Post,
                                    "#{self.gateway.url}#{uri}",
                                    :headers => headers.merge({'content-type' => 'application/json', 'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    :format => :json,
                                    :body => params,
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def form_post(uri, params=nil, headers={})
    params_urlenc = URI.encode_www_form(params)
    request = HTTParty::Request.new(Net::HTTP::Post,
                                    "#{self.gateway.url}#{uri}",
                                    :headers => headers.merge({'content-type' => 'application/x-www-form-urlencoded', 'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    :format => :plain,
                                    :body => params_urlenc,
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def put(uri, id, params, headers={})
    request = HTTParty::Request.new(Net::HTTP::Put,
                                    id.blank? ? "#{self.gateway.url}#{uri}" : "#{self.gateway.url}#{uri}/#{id}",
                                    :headers => headers.merge({'content-type' => 'application/json', 'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    :format => :json,
                                    :body => params,
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def patch(uri, id, params, headers={})
    request = HTTParty::Request.new(Net::HTTP::Patch,
                                    id.blank? ? "#{self.gateway.url}#{uri}" : "#{self.gateway.url}#{uri}/#{id}",
                                    :headers => headers.merge({'content-type' => 'application/json', 'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    :format => :json,
                                    :body => params,
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def delete(uri, id, headers={})
    request = HTTParty::Request.new(Net::HTTP::Delete,
                                    id.blank? ? "#{self.gateway.url}#{uri}" : "#{self.gateway.url}#{uri}/#{id}",
                                    :headers => headers.merge({'User-Agent' => USER_AGENT}),
                                    :timeout => DEFAULT_TIMEOUT,
                                    #:format => :json,
                                    #:body => '',
                                    :basic_auth => self.gateway.auth)
    request.perform
  end

  def process_list_response(klass, response, key)
    return nil if response.nil? or response.code == 204
    handle_not_authorized response if response.code == 401
    handle_not_found response if response.code == 404
    handle_server_error response if response.code >= 500

    attrs = ActiveSupport::JSON.decode(response.body)
    list = attrs['page'].present? ? ChargeIO::Collection.new(attrs['page'],attrs['page_size'],attrs['total_entries']) : []
    if attrs[key].present?
      attrs[key].each do |attributes|
        narrowed_klass = narrow_class(attributes, klass)
        list << narrowed_klass.new(attributes.merge(:gateway => self.gateway))
      end
    end
    list
  end

  def process_response(klass, response)
    return nil if response.nil? or response.code == 204
    handle_not_authorized response if response.code == 401
    handle_not_found response if response.code == 404
    handle_server_error response if response.code >= 500

    attributes = ActiveSupport::JSON.decode(response.body)
    narrowed_klass = narrow_class(attributes, klass)
    obj = narrowed_klass.new attributes.merge(:gateway => gateway)
    mod = Module.new do
      obj.attributes.keys.each do |k|
        next if k == "messages"

        define_method(k) do
          return self.attributes[k]
        end

        define_method("#{k}=") do |val|
          self.attributes[k] = val
        end
      end
    end
    obj.send(:extend, mod)
    obj.process_response_errors(obj.attributes)
    obj
  end

  def narrow_class(attributes, klass)
    narrowed_klass = klass
    if klass == ChargeIO::Transaction
      transaction_type = attributes['type']
      case transaction_type
        when 'CHARGE'
          narrowed_klass = ChargeIO::Charge
        when 'REFUND'
          narrowed_klass = ChargeIO::Refund
        when 'CREDIT'
          narrowed_klass = ChargeIO::Credit
      end
    end

    narrowed_klass
  end

  def handle_not_found(response)
    response_json = ActiveSupport::JSON.decode(response.body)

    if response_json['messages']
      msg = ChargeIO::Message.new response_json['messages'].first
      raise ChargeIO::ResourceNotFound.new msg.context
    end
    raise ChargeIO::ResourceNotFound.new "The requested resource was not found"
  end

  def handle_not_authorized(response)
    response_json = ActiveSupport::JSON.decode(response.body)

    if response_json['messages']
      msg = ChargeIO::Message.new response_json['messages'].first
      raise ChargeIO::Unauthorized.new msg.message, msg.attributes['entity_id']
    end
    raise ChargeIO::Unauthorized.new "You do not have permission to access this resource"
  end

  def handle_server_error(response)
    response_json = ActiveSupport::JSON.decode(response.body)

    if response_json['messages']
      msg = ChargeIO::Message.new response_json['messages'].first
      raise ChargeIO::ServerError.new msg.message, msg.code, msg.attributes['entity_id']
    end
    raise ChargeIO::ServerError.new "An unexpected error occurred"
  end
end
