require 'spec_helper'

describe "Account" do
  before(:all) do
    skip("No secret_key specified in environment") unless ENV['secret_key']
    @gateway = ChargeIO::Gateway.new(DEFAULT_MERCHANT_TEST_MODE_OPTIONS.clone)
    @card_params = DEFAULT_CARD_PARAMS.clone
  end

  describe 'authorize' do
    it 'should be successful' do
      t = @gateway.authorize(1256, :method => @card_params, :reference => 'auth ref 1256')
      t.id.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.amount.should == 1256
      t.currency.should == 'USD'
      t.status.should == 'AUTHORIZED'
      t.reference.should eq 'auth ref 1256'
      t.auto_capture.should be false
      t.cvv_result.should eq 'MATCHED'
      t.avs_result.should eq 'ADDRESS_AND_POSTAL_CODE'
      t.attributes.should_not have_key :gratuity
      t.attributes.should_not have_key :signature_id
    end
    it 'should allow the relayed IP address to perform the operation' do
      t = @gateway.authorize(1256, :method => @card_params, :ip_address => '216.239.32.4')
      t.id.should_not be_nil
      t.errors.present?.should be false
      t.status.should == 'AUTHORIZED'
    end
    it 'should reject the charge operation due to IP outside of countries list and amount beyond default foreign country exception limit' do
      expect {
        @gateway.authorize(50000, :method => @card_params, :ip_address => '95.27.173.123')
      }.to raise_exception(ChargeIO::Unauthorized)
    end
    it 'should reject the charge operation due to IP from a prohibited country' do
      expect {
        @gateway.authorize(500, :method => @card_params, :ip_address => '190.92.112.1')
      }.to raise_exception(ChargeIO::Unauthorized)
    end
  end

  describe 'charge' do
    it 'should be successful' do
      t = @gateway.charge(Money.new(1312, 'USD'), :method => @card_params)
      t.id.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.amount.should == 1312
      t.currency.should == 'USD'
      t.status.should == 'AUTHORIZED'
      t.auto_capture.should be true
      t.cvv_result.should eq 'MATCHED'
      t.avs_result.should eq 'ADDRESS_AND_POSTAL_CODE'
    end
  end

  describe 'capture full amount' do
    it 'should be successful' do
      t = @gateway.authorize(1256, :method => @card_params, :reference => 'auth ref 1256')
      t.id.should_not be_nil
      t.capture(1256, :reference => 'cap ref 1256')
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.status.should == 'COMPLETED'
      t.amount.should == 1256
      t.reference.should eq 'auth ref 1256'
      t.capture_reference.should eq 'cap ref 1256'
    end
  end

  describe 'capture partial amount' do
    it 'should be successful' do
      t = @gateway.authorize(1200, :method => @card_params)
      t.id.should_not be_nil
      t.capture(1150, :reference => 'cap ref 1150')
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.status.should == 'COMPLETED'
      t.amount.should == 1150
      t.capture_reference.should eq 'cap ref 1150'
    end
  end

  describe 'fail on amount' do
    it 'should return below_minimum_value' do
      t = @gateway.authorize(0, :method => @card_params)
      t.errors.present?.should be true
      t.errors['amount'].should == [ 'Amount is less than the minimum value' ]
    end
  end

  describe 'fail on card_number' do
    it 'should return is_blank' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => ''))
      t.errors.present?.should be true
      t.errors['method.number'].should == [ 'Card number cannot be blank' ]
    end
    it 'should return invalid_length (too short)' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '41111'))
      t.errors.present?.should be true
      t.errors['method.number'].should == [ 'Card number length is invalid' ]
    end
    it 'should return invalid_length (too long)' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '411111111111111111112'))
      t.errors.present?.should be true
      t.errors['method.number'].should == [ 'Card number length is invalid' ]
    end
    it 'should return card_number_invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4242424242424241'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card number is invalid' ]
      t.messages[0].attributes['level'].should == 'error'
      t.messages[0].attributes['code'].should == 'card_number_invalid'
    end
  end

  describe 'fail on card expiration' do
    it 'should return below_minimum_value' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_month => 0))
      t.errors.present?.should be true
      t.errors['method.exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return exceeds_maximum_value' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_month => 13))
      t.errors.present?.should be true
      t.errors['method.exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_month => 'Feb'))
      t.errors.present?.should be true
      t.errors['method.exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_year => '201B'))
      t.errors.present?.should be true
      t.errors['method.exp_year'].should == [ 'Expiration year is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_year => 10001))
      t.errors.present?.should be true
      t.errors['method.exp_year'].should == [ 'Expiration year is invalid' ]
    end
    it 'should return card_expired' do
      t = @gateway.authorize(34, :method => @card_params.merge(:exp_year => 2012))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card is expired' ]
    end
  end

  describe  'fail on card cvv' do
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:cvv => '12'))
      t.errors.present?.should be true
      t.errors['method.cvv'].should == [ 'Card code length is invalid' ]
    end
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:cvv => '12345'))
      t.errors.present?.should be true
      t.errors['method.cvv'].should == [ 'Card code length is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:cvv => '54!'))
      t.errors.present?.should be true
      t.errors['method.cvv'].should == [ 'Card code is invalid' ]
    end
    it 'should return card_cvv_incorrect' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000101'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card code is incorrect' ]
    end
  end

  describe 'fail on card name' do
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:name => 'Aname Thatiswaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaytooooooooooooooooooooooooooooooooolong'))
      t.errors.present?.should be true
      t.errors['method.name'].should == [ 'Name length is invalid' ]
    end
  end

  it 'should return invalid_length' do
    t = @gateway.authorize(34, :method => @card_params.merge(:address1 => '1503908349058459834 Reallylongnameofastreetintheunitedstatesofamericathatiwouldntwanttoliveon'))
    t.errors.present?.should be true
    t.errors['method.address1'].should == [ 'Street number length is invalid' ]
  end
  it 'should return invalid_length' do
    t = @gateway.authorize(34, :method => @card_params.merge(:address2 => 'Building 783624872348923423498723948723, Suite 983425908234098234, Apt 3987345897345'))
    t.errors.present?.should be true
    t.errors['method.address2'].should == [ 'Address length is invalid' ]
  end
  it 'should return invalid_length' do
    t = @gateway.authorize(34, :method => @card_params.merge(:city => 'Areallylongnameofacityintheunitedstatesofamericamanwouldieverhatetohavetowritethis'))
    t.errors.present?.should be true
    t.errors['method.city'].should == [ 'City length is invalid' ]
  end

  describe 'fail on card state' do
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:state => 'F', :country => 'US'))
      t.errors.present?.should be true
      t.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:state => 'BIG', :country => 'US'))
      t.errors.present?.should be true
      t.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:state => 'FX', :country => 'US'))
      t.errors.present?.should be true
      t.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:state => 'TX', :country => 'CA'))
      t.errors.present?.should be true
      t.errors['method.state'].should == [ 'State or province is invalid' ]
    end
  end

  describe 'fail on card postal code' do
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:postal_code => '78'))
      t.errors.present?.should be true
      t.errors['method.postal_code'].should == [ 'Postal code is invalid' ]
    end
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:postal_code => '78726-12345'))
      t.errors.present?.should be true
      t.errors['method.postal_code'].should == [ 'Postal code is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:postal_code => '78726+62A'))
      t.errors.present?.should be true
      t.errors['method.postal_code'].should == [ 'Postal code is invalid' ]
    end
  end

  describe 'fail on card country' do
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:country => 'U'))
      t.errors.present?.should be true
      t.errors['method.country'].should == [ 'Country length is invalid' ]
    end
    it 'should return invalid_length' do
      t = @gateway.authorize(34, :method => @card_params.merge(:country => 'USA'))
      t.errors.present?.should be true
      t.errors['method.country'].should == [ 'Country length is invalid' ]
    end
    it 'should return invalid' do
      t = @gateway.authorize(34, :method => @card_params.merge(:country => 'ZZ'))
      t.errors.present?.should be true
      t.errors['method.country'].should == [ 'Country is invalid' ]
    end
  end

  describe 'processing failures' do
    it 'should return card_declined' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000002'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card was declined' ]
    end
    it 'should return card_address_check_failed' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000010'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Address verification failed' ]
    end
    it 'should return card_declined_processing_error' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000119'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card was declined due to a processing error' ]
    end
    it 'should return card_declined_insufficient_funds' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000044'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card was declined due to insufficient funds' ]
    end
    it 'should return card_declined_limit_exceeded' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000051'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card was declined due to limits exceeded' ]
    end
    it 'should return card_declined_hold' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000127'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card was declined' ]
    end
    it 'should return card_type_not_accepted' do
      t = @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000135'))
      t.errors.present?.should be true
      t.errors['base'].should == [ 'Card type is not accepted' ]
    end
    it 'should raise a card processing exception' do
      expect { @gateway.authorize(34, :method => @card_params.merge(:number => '4000000000000143')) }.to raise_exception { |ex|
        ex.should be_a(ChargeIO::ServerError)
        ex.code.should == 'card_processing_error'
        ex.entity_id.should_not be_nil
      }
    end
  end

  describe 'authorize with a one-time token' do
    it 'should be successful' do
      token = @gateway.create_token(@card_params)
      token.should_not be_nil
      token.errors.present?.should be false
      token.messages.present?.should be false
      token.id.should_not be_nil

      t = @gateway.authorize(15501, :method => token.id)
      t.id.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.amount.should == 15501
      t.currency.should == 'USD'
      t.status.should == 'AUTHORIZED'
      t.auto_capture.should be false
      t.cvv_result.should eq 'MATCHED'
      t.avs_result.should eq 'ADDRESS_AND_POSTAL_CODE'
    end
    it 'should return not found after token is used' do
      token = @gateway.create_token(@card_params)

      t = @gateway.authorize(102, :method => token.id)
      t.id.should_not be_nil
      t.errors.present?.should be false

      expect { @gateway.authorize(91, :method => token.id) }.to raise_exception(ChargeIO::ResourceNotFound)
    end
  end

  describe 'charge with a one-time token' do
    it 'should be successful' do
      token = @gateway.create_token(@card_params)
      token.should_not be_nil
      token.errors.present?.should be false
      token.messages.present?.should be false
      token.id.should_not be_nil

      t = @gateway.charge(15502, :method => token.id)
      t.id.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.amount.should == 15502
      t.currency.should == 'USD'
      t.status.should == 'AUTHORIZED'
      t.auto_capture.should be true
      t.cvv_result.should eq 'MATCHED'
      t.avs_result.should eq 'ADDRESS_AND_POSTAL_CODE'
    end
  end

  describe 'charge multiple times with a card token' do
    it 'should be successful' do
      card = @gateway.create_card(@card_params)
      card.should_not be_nil
      card.errors.present?.should be false
      card.messages.present?.should be false
      card.id.should_not be_nil

      t1 = @gateway.authorize(15502, :method => card.id)
      t1.id.should_not be_nil
      t1.errors.present?.should be false
      t1.status.should == 'AUTHORIZED'

      t2 = @gateway.authorize(15503, :method => card.id)
      t2.id.should_not be_nil
      t2.errors.present?.should be false
      t2.status.should == 'AUTHORIZED'

      @gateway.delete_card(card.id)
      expect { @gateway.authorize(15504, :method => card.id) }.to raise_exception(ChargeIO::ResourceNotFound)
    end
  end

  describe 'retrieving transactions' do
    before(:all) do
      @account = @gateway.primary_merchant_account
      @authorized = @account.authorize(8955, :method => @card_params, :authorization_reference => '122')
      @captured = @account.authorize(36529, :method => @card_params, :authorization_reference => '341')
      @captured.capture
      @refund = @captured.refund(800)

      # Wait a second to ensure propagation to the search indexes
      sleep(1)
    end
    it 'should return the charge' do
      t = @gateway.find_transaction(@authorized.id)
      t.should_not be_nil
      t.id.should eq @authorized.id
      t.refunded?.should be false
    end
    it 'should return the charge with refunds' do
      t = @gateway.find_transaction(@captured.id)
      t.should_not be_nil
      t.id.should eq @captured.id
      t.refunded?.should be true
      t.refunds.size.should == 1
      t.refunds[0]['id'].should == @refund.id
    end
    it 'should return the refund' do
      t = @gateway.find_transaction(@refund.id)
      t.should_not be_nil
      t.id.should eq @refund.id
    end
    it 'should return the transactions created above' do
      query = @gateway.transactions
      query.current_page.should == 1
      query.total_pages.should be >= 1
      query.total_entries.should be >= 3
      query.size.should be >= 3

      t = query.find {|t| t.id == @authorized.id }
      t.should_not be_nil
      t.type.should eq 'CHARGE'
      t.refunded?.should be false

      t = query.find {|t| t.id == @captured.id }
      t.should_not be_nil
      t.type.should eq 'CHARGE'
      t.refunded?.should be false

      r = query.find {|t| t.id == @refund.id }
      r.should_not be_nil
      r.type.should eq 'REFUND'
      r.amount.should == @refund.amount
    end
    it 'should return an empty results page' do
      query = @gateway.transactions(:page => 1000000)
      query.current_page.should == 1000000
      query.total_pages.should be >= 1
      query.total_entries.should be >= 3
      query.size.should == 0
    end
  end

  describe 'purging test data' do
    charge = refund = token = card = bank = nil
    before(:each) do
      charge = @gateway.charge(1400, :method => @card_params)
      refund = charge.refund(200)
      token = @gateway.create_token(DEFAULT_CARD_PARAMS)
      card = @gateway.create_card(DEFAULT_CARD_PARAMS)
      bank = @gateway.create_bank(DEFAULT_ACH_PARAMS)
    end
    it 'should delete all the test data' do
      @gateway.purge_test_data
      expect { @gateway.find_transaction(charge.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_transaction(refund.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_token(token.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_card(card.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_bank(bank.id) }.to raise_exception(ChargeIO::ResourceNotFound)
    end
    it 'should only delete all test transactions' do
      @gateway.purge_test_data(:delete_transactions => true)
      expect { @gateway.find_transaction(charge.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_transaction(refund.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      @gateway.find_token(token.id).should_not be_nil
      @gateway.find_card(card.id).should_not be_nil
      @gateway.find_bank(bank.id).should_not be_nil
    end
    it 'should only delete payment methods' do
      @gateway.purge_test_data(:delete_payment_methods => true)
      @gateway.find_transaction(charge.id).should_not be_nil
      @gateway.find_transaction(refund.id).should_not be_nil
      expect { @gateway.find_token(token.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_card(card.id) }.to raise_exception(ChargeIO::ResourceNotFound)
      expect { @gateway.find_bank(bank.id) }.to raise_exception(ChargeIO::ResourceNotFound)
    end
  end
end

