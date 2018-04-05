class ChargeIO::RecurringCharge < ChargeIO::Base
  def find_occurrences(params={})
    gateway.recurring_charge_occurrences(id, params)
  end

  def cancel
    res = gateway.cancel_recurring_charge(id)
    replace(res)
  end
end
