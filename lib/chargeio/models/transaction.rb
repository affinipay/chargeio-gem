class ChargeIO::Transaction < ChargeIO::Base
  def void(params={})
    res = gateway.void(id, params)
    replace(res)
  end

  def sign(data, gratuity=nil, mime_type='chargeio/jsignature', params={})
    res = gateway.sign(id, data, gratuity, mime_type, params)
    replace(res)
  end

  def capture(amount, params={})
    res = gateway.capture(id, amount, params)
    replace(res)
  end
end