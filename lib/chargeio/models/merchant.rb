class ChargeIO::Merchant < ChargeIO::Base

  def primary_merchant_account
    if attributes['merchant_accounts'].present?
      attributes['merchant_accounts'].each do |a|
        return ChargeIO::MerchantAccount.new(a.merge(:gateway => self.gateway, :merchant_id => self.id)) if a['primary']
      end
    end
    nil
  end

  def all_merchant_accounts
    list = []
    if attributes['merchant_accounts'].present?
      attributes['merchant_accounts'].each do |a|
        list << ChargeIO::MerchantAccount.new(a.merge(:gateway => self.gateway, :merchant_id => self.id))
      end
    end
    list
  end

  def primary_ach_account
    if attributes['ach_accounts'].present?
      attributes['ach_accounts'].each do |a|
        return ChargeIO::AchAccount.new(a.merge(:gateway => self.gateway, :merchant_id => self.id)) if a['primary']
      end
    end
    nil
  end

  def all_ach_accounts
    list = []
    if attributes['ach_accounts'].present?
      attributes['ach_accounts'].each do |a|
        list << ChargeIO::AchAccount.new(a.merge(:gateway => self.gateway, :merchant_id => self.id))
      end
    end
    list
  end

  def save
    res = gateway.update_merchant(attributes)
    replace(res)
  end

  def transactions
    gateway.transactions()
  end

  def tokens(reference)
    gateway.tokens(reference)
  end
end
