class ChargeIO::Charge < ChargeIO::Transaction

  def refunded?
    attributes['refunds'].present?
  end

  def capture(amount = self.amount, params={})
    res = gateway.capture(id, amount, params)
    replace(res)
  end

  def refunds
    list = []
    attributes['refunds'].each do |a|
      list << ChargeIO::Refund.new(a.merge(:gateway => self.gateway))
    end if attributes['refunds'].present?
    list
  end

  def refund(amount = self.amount, params={})
    gateway.refund(id, amount, params)
  end
end
