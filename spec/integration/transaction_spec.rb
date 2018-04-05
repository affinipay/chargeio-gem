require 'spec_helper'

describe "Transaction" do
  before(:all) do
    skip("No secret_key specified in environment") unless ENV['secret_key']
    @gateway = ChargeIO::Gateway.new(DEFAULT_MERCHANT_TEST_MODE_OPTIONS.clone)
    @card_params = DEFAULT_CARD_PARAMS.clone
  end

  describe 'capture' do
    before :each do
      @authorized = @gateway.authorize(100, :method => @card_params, :reference => 'auth ref 100')
      @authorized.errors.present?.should be false
      @authorized.id.should_not be_nil
      @authorized.status.should == 'AUTHORIZED'
      @authorized.method[:fingerprint].should_not be_nil
      @authorized.auto_capture.should eq false
    end

    it 'should fully capture' do
      @authorized.capture(100, :reference => 'cap ref 100')
      @authorized.errors.present?.should be false
      @authorized.messages.present?.should be false
      @authorized.status.should == 'COMPLETED'
      @authorized.amount.should == 100
      @authorized.reference.should eq 'auth ref 100'
      @authorized.capture_reference.should eq 'cap ref 100'
    end

    it 'should partial capture' do
      @authorized.capture(96)
      @authorized.errors.present?.should be false
      @authorized.messages.present?.should be false
      @authorized.status.should == 'COMPLETED'
      @authorized.amount.should == 96
    end

    it 'should manually capture auto-capture charge' do
      @authorized.capture
      @authorized.errors.present?.should be false
      @authorized.status.should == 'COMPLETED'
      @authorized.amount.should == 100
    end

    describe 'failures' do
      it 'should return exceeds_authorized_amount' do
        @authorized.capture(101)
        @authorized.errors.present?.should be true
        @authorized.errors['base'].should == [ 'Amount to capture exceeds the authorized amount' ]
      end
      it 'should return currency_mismatch' do
        @authorized.capture(Money.new(90, 'GBP'))
        @authorized.errors.present?.should be true
        @authorized.errors['base'].should == [ "Specified currency does not match the transaction's currency" ]
      end
      it 'should return not_valid_for_transaction_status' do
        @authorized.capture
        @authorized.errors.present?.should be false
        @authorized.capture
        @authorized.errors.present?.should be true
        @authorized.errors['base'].should == [ 'The operation cannot be completed in the current status' ]
      end
    end
  end

  describe 'void' do
    before :each do
      @authorized = @gateway.authorize(100, :method => @card_params)
    end

    it 'should void the manual capture charge' do
      @authorized.void
      @authorized.errors.present?.should be false
      @authorized.status.should == 'VOIDED'
    end
    it 'should void the manual capture charge with a ref' do
      @authorized.void(:reference => 'cancel ref')
      @authorized.errors.present?.should be false
      @authorized.status.should == 'VOIDED'
      @authorized.void_reference.should eq 'cancel ref'
    end
    it 'should void the auto-capture charge' do
      t = @gateway.charge(100, :method => @card_params)
      t.void
      t.errors.present?.should be false
      t.status.should eq 'VOIDED'
    end
    it 'should allow voiding a charge with a voided refund' do
      t = @gateway.charge(100, :method => @card_params)
      r = t.refund(5)
      r.void
      t.void
      t.errors.present?.should be false
      t.status.should eq 'VOIDED'
    end

    describe 'failures' do
      it 'should return not_valid_for_transaction_status' do
        @authorized.void
        @authorized.errors.present?.should be false
        @authorized.void
        @authorized.errors.present?.should be true
        @authorized.errors['base'].should == [ 'The operation cannot be completed in the current status' ]
      end
      it 'should prevent voiding a transaction with non-voided refunds' do
        t = @gateway.charge(100, :method => @card_params)
        t.refund(5)
        t.void
        t.errors.present?.should be true
        t.errors['base'].should == [ 'The operation cannot be completed in the current status' ]
      end
    end
  end

  describe 'refund' do
    describe 'manual capture' do
      before :each do
        @authorized = @gateway.authorize(100, :method => @card_params, :reference => 'auth ref 100')
        @authorized.errors.present?.should be false
        @authorized.id.should_not be_nil
        @authorized.status.should == 'AUTHORIZED'
        @authorized.auto_capture.should eq false
      end

      it 'should be successful' do
        @authorized.capture(100)

        refund = @authorized.refund(100)
        refund.id.should_not be_nil
        refund.errors.present?.should be false
        refund.messages.present?.should be false
        refund.amount.should == 100
        refund.type.should eq 'REFUND'
        refund.status.should eq 'COMPLETED'
        refund.auto_capture.should eq true

        charge = @gateway.find_transaction(@authorized.id)
        charge.should_not be_nil
        charge.amount_refunded.should == 100
      end

      it 'should reject refunds for un-captured manual capture charges' do
        refund = @authorized.refund(100)
        refund.errors.present?.should be true
        refund.errors['base'].should == [ "The operation cannot be completed in the current status" ]
      end
    end

    describe 'on charged' do
      before :each do
        @authorized = @gateway.charge(100, :method => @card_params)
      end

      describe 'full refund' do
        it 'should be successful' do
          refund = @authorized.refund(100, :reference => 'refund ref')
          refund.id.should_not be_nil
          refund.errors.present?.should be false
          refund.messages.present?.should be false
          refund.amount.should == 100
          refund.reference.should eq 'refund ref'
          refund.type.should eq 'REFUND'
          refund.status.should eq 'AUTHORIZED'
          refund.auto_capture.should eq true

          charge = @gateway.find_transaction(@authorized.id)
          charge.should_not be_nil
          charge.amount_refunded.should == 100
        end
      end

      describe 'partial refunds' do
        it 'should be successful' do
          refund = @authorized.refund(50)
          refund.id.should_not be_nil
          refund.errors.present?.should be false
          refund.messages.present?.should be false
          refund.amount.should == 50
          refund.type.should eq 'REFUND'

          charge = @gateway.find_transaction(@authorized.id)
          charge.should_not be_nil
          charge.amount_refunded.should == 50

          refund2 = @authorized.refund(40, :reference => 'partial refund 40')
          refund2.id.should_not be_nil
          refund2.errors.present?.should be false
          refund2.messages.present?.should be false
          refund2.amount.should == 40
          refund2.reference.should eq 'partial refund 40'
          refund2.type.should eq 'REFUND'

          charge = @gateway.find_transaction(@authorized.id)
          charge.should_not be_nil
          charge.amount_refunded.should == 90
        end
      end

      describe 'failures' do
        it 'should return currency_mismatch' do
          refund = @authorized.refund(Money.new(90, 'GBP'))
          refund.errors.present?.should be true
          refund.errors['base'].should == [ "Specified currency does not match the transaction's currency" ]
        end
        it 'should return refund_exceeds_transaction' do
          refund = @authorized.refund(Money.new(101, 'USD'))
          refund.errors.present?.should be true
          refund.errors['base'].should == [ 'Amount of refund exceeds remaining transaction balance' ]
        end
      end
    end
  end

  describe 'signing transactions' do
    describe 'on authorization' do
      it 'should authorize with signature' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should fail to authorize with signature containing no data' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature' })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to authorize with signature containing empty data' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => '' })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should authorize with signature containing data that is maximum length' do
        sigdata = @gateway.random_string(8192)
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => sigdata })
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == sigdata
      end
      it 'should fail to authorize with signature containing data that is too long' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => @gateway.random_string(8193) })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'invalid_length'
      end
      it 'should authorize with signature using non-default format' do
        sigdata = @gateway.random_string()
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'something/else', :data => sigdata })
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'something/else'
        s.data.should == sigdata
      end
      it 'should fail to authorize with signature containing no format' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :data => @gateway.random_string() })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.mime_type'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to authorize with signature containing empty format' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => '', :data => @gateway.random_string() })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.mime_type'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to authorize with signature containing invalid format' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => '01234567890123456789012345678901234567890123456789012345678901234', :data => @gateway.random_string() })
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.mime_type'
        t.messages[0].sub_code.should == 'invalid_length'
      end
      it 'should authorize with zero gratuity specified' do
        t = @gateway.authorize(3000, :method => @card_params, :gratuity => 0)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.amount.should == 3000
        t.gratuity.should == 0
      end
      it 'should fail to authorize with invalid gratuity' do
        t = @gateway.authorize(3000, :method => @card_params, :gratuity => -1)
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'gratuity'
        t.messages[0].sub_code.should == 'below_minimum_value'
      end
      it 'should fail to authorize with gratuity without signature' do
        t = @gateway.authorize(3000, :method => @card_params, :gratuity => 1)
        t.id.should be_nil
        t.errors.present?.should be true
        t.messages[0].code.should == 'signature_required'
      end
      it 'should permit refunding the total amount including gratuity' do
        t = @gateway.charge(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => @gateway.random_string() }, :gratuity => 600)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false

        r = t.refund(3600)
        r.errors.present?.should be false
        r.messages.present?.should be false
        r.id.should_not be_nil
        r.amount.should == 3600

        t = @gateway.find_transaction(t.id)
        t.should_not be_nil
        t.amount_refunded.should == 3600

        r2 = t.refund(1)
        r2.errors.present?.should be true
        r2.messages[0].code.should == 'refund_exceeds_transaction'
      end
      it 'should permit refunding the a partial amount including gratuity' do
        t = @gateway.charge(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => @gateway.random_string() }, :gratuity => 600)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false

        r = t.refund(3300)
        r.errors.present?.should be false
        r.messages.present?.should be false
        r.id.should_not be_nil
        r.amount.should == 3300

        t = @gateway.find_transaction(t.id)
        t.should_not be_nil
        t.amount_refunded.should == 3300

        r2 = t.refund(300)
        r2.errors.present?.should be false
        r2.messages.present?.should be false
        r2.id.should_not be_nil
        r2.amount.should == 300

        t = @gateway.find_transaction(t.id)
        t.should_not be_nil
        t.amount_refunded.should == 3600

        r3 = t.refund(1)
        r3.errors.present?.should be true
        r3.messages[0].code.should == 'refund_exceeds_transaction'
      end
      it 'should prevent refunding more than the total amount with gratuity' do
        t = @gateway.charge(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => @gateway.random_string() }, :gratuity => 600)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false

        r = t.refund(3601)
        r.errors.present?.should be true
        r.messages[0].code.should == 'refund_exceeds_transaction'
      end
    end

    describe 'after authorization' do
      it 'should sign an authorized charge' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.amount.should == 3000
        t.currency.should == 'USD'
        t.status.should == 'AUTHORIZED'
        t.attributes.should_not have_key :signature_id
        t.attributes.should_not have_key :gratuity

        t.sign(DEFAULT_SIGNATURE_DATA)
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil
        t.attributes.should_not have_key :gratuity

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should sign an authorized charge with a gratuity' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.amount.should == 3000
        t.currency.should == 'USD'
        t.status.should == 'AUTHORIZED'
        t.attributes.should_not have_key :signature_id
        t.attributes.should_not have_key :gratuity

        t.sign(DEFAULT_SIGNATURE_DATA, 600)
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil
        t.amount.should == 3000
        t.gratuity.should == 600

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should fail to sign a charge that has already been signed' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA

        t.sign(DEFAULT_SIGNATURE_DATA, 600)
        t.errors.present?.should be true
        t.messages[0].code.should == 'not_valid_for_transaction_status'
        t.signature_id.should == s.id
      end
      it 'should fail to add a gratuity without a signature' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.id.should_not be_nil
        t.errors.present?.should be false
        t.messages.present?.should be false

        t.sign(nil, 600)
        t.errors.present?.should be true
        t.messages.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'data'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to sign a charge that is failed' do
        t = @gateway.authorize(3000, :method => @card_params.merge(:number => '4000000000000044'))
        t.id.should be_nil
        t.errors.present?.should be true
        charge_id = t.messages[0].attributes['entity_id']

        t = @gateway.sign(charge_id, DEFAULT_SIGNATURE_DATA)
        t.errors.present?.should be true
        t.messages[0].code.should == 'not_valid_for_transaction_status'
      end
      it 'should fail to sign a charge using a signature with no data' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false
        t.sign(nil)
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'data'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to sign a charge using a signature with empty data' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false
        t.sign('')
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'data'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should sign a charge using a signature with data that is maximum length' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        sigdata = @gateway.random_string(8192)
        t.sign(sigdata)
        t.errors.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == sigdata
      end
      it 'should fail to sign a charge using a signature with data that is too long' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false
        t.sign(@gateway.random_string(8193))
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'data'
        t.messages[0].sub_code.should == 'invalid_length'
      end
      it 'should sign a charge using a signature with non-default format' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        sigdata = @gateway.random_string()
        t.sign(sigdata, nil, 'chargeio/other')
        t.errors.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/other'
        s.data.should == sigdata
      end
      it 'should fail to sign a charge using a signature with no format specified' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.sign(@gateway.random_string(), nil, nil)
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'mime_type'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to sign a charge using a signature with an empty format' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.sign(@gateway.random_string(), nil, '')
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'mime_type'
        t.messages[0].sub_code.should == 'not_blank'
      end
      it 'should fail to sign a charge using a signature with an invalid format' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.sign(@gateway.random_string(), nil, '012345678901234567890123456789012345678901234567890123456789012345')
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'mime_type'
        t.messages[0].sub_code.should == 'invalid_length'
      end
      it 'should fail to sign a charge using an invalid gratuity' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.sign(DEFAULT_SIGNATURE_DATA, -1)
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'gratuity'
        t.messages[0].sub_code.should == 'below_minimum_value'
      end
    end

    describe 'at capture' do
      it 'should apply a signature at capture' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(3000, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 3000
        t.signature_id.should_not be_nil
        t.attributes.should_not have_key :gratuity

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should apply a signature and gratuity at capture' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(2800, :gratuity => 600, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 2800
        t.signature_id.should_not be_nil
        t.gratuity.should == 600

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should apply a signature and zero gratuity at capture' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(2800, :gratuity => 0, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 2800
        t.signature_id.should_not be_nil
        t.gratuity.should == 0

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should capture with zero gratuity without a signature' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(2900, :gratuity => 0)
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 2900
        t.attributes.should_not have_key :signature_id
        t.attributes.should_not have_key :gratuity
      end
      it 'should reject a signature when already signed' do
        t = @gateway.authorize(3000, :method => @card_params, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be false

        t.capture(3000, :signature => { :mime_type => 'chargeio/jsignature', :data => @gateway.random_string() })
        t.errors.present?.should be true
        t.messages[0].code.should == 'not_valid_for_transaction_status'
        t.status.should == 'AUTHORIZED'
      end
      it 'should reject a gratuity without a signature' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(3000, :gratuity => 600)
        t.errors.present?.should be true
        t.messages[0].code.should == 'signature_required'
        t.status.should == 'AUTHORIZED'
      end
      it 'should reject an invalid gratuity' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(3000, :gratuity => -1, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'gratuity'
        t.messages[0].sub_code.should == 'below_minimum_value'
        t.status.should == 'AUTHORIZED'
      end
      it 'should reject a signature with no data' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(3000, :gratuity => -1, :signature => { :mime_type => 'chargeio/jsignature' })
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'not_blank'
        t.status.should == 'AUTHORIZED'
      end
      it 'should reject a signature with empty data' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        t.capture(3000, :gratuity => -1, :signature => { :mime_type => 'chargeio/jsignature', :data => '' })
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'not_blank'
        t.status.should == 'AUTHORIZED'
      end
      it 'should accept a signature with data that is maximum length' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        sigdata = @gateway.random_string(8192)
        t.capture(3000, :signature => { :mime_type => 'chargeio/other', :data => sigdata })
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 3000
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/other'
        s.data.should == sigdata
      end
      it 'should reject a signature with data that is too long' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.errors.present?.should be false

        sigdata = @gateway.random_string(8193)
        t.capture(3000, :signature => { :mime_type => 'chargeio/other', :data => sigdata })
        t.errors.present?.should be true
        t.messages[0].code.should == 'invalid_data'
        t.messages[0].context.should == 'signature.data'
        t.messages[0].sub_code.should == 'invalid_length'
        t.status.should == 'AUTHORIZED'
      end
    end

    describe 'post capture' do
      it 'should sign a captured transaction with no gratuity' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.capture
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'

        t.sign(DEFAULT_SIGNATURE_DATA)
        t.errors.present?.should be false
        t.signature_id.should_not be_nil

        s = @gateway.find_signature(t.signature_id)
        s.should_not be_nil
        s.errors.present?.should be false
        s.messages.present?.should be false
        s.mime_type.should == 'chargeio/jsignature'
        s.data.should == DEFAULT_SIGNATURE_DATA
      end
      it 'should fail to sign a captured transaction with gratuity' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.capture
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'

        t.sign(DEFAULT_SIGNATURE_DATA, 500)
        t.errors.present?.should be true
        t.messages[0].code.should == 'not_valid_for_transaction_status'
        t.attributes.should_not have_key(:signature_id)
      end
      it 'should fail to sign a captured transaction that has already been signed' do
        t = @gateway.authorize(3000, :method => @card_params)
        t.capture(3000, :signature => { :mime_type => 'chargeio/jsignature', :data => DEFAULT_SIGNATURE_DATA })
        t.errors.present?.should be false
        t.status.should == 'COMPLETED'
        t.amount.should == 3000
        t.signature_id.should_not be_nil
        t.attributes.should_not have_key :gratuity
        sig_id = t.signature_id

        t.sign(DEFAULT_SIGNATURE_DATA, 500)
        t.errors.present?.should be true
        t.messages[0].code.should == 'not_valid_for_transaction_status'
        t.signature_id.should == sig_id
      end
    end
  end
end
