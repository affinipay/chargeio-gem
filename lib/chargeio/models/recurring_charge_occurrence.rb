class ChargeIO::RecurringChargeOccurrence < ChargeIO::Base
  def pay(params={})
    res = gateway.pay_recurring_charge_occurrence(recurring_charge_id, id, params)
    replace(res)
  end

  def ignore
    res = gateway.ignore_recurring_charge_occurrence(recurring_charge_id, id)
    replace(res)
  end
end
