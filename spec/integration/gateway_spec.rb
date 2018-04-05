require 'spec_helper'

describe 'Gateway' do
  before(:all) do
    skip("No secret_key specified in environment") unless ENV['secret_key']
    @gateway = ChargeIO::Gateway.new(DEFAULT_MERCHANT_TEST_MODE_OPTIONS.clone)
    @invalid_gateway = ChargeIO::Gateway.new(:secret_key => 'invalid')
  end

  describe 'with invalid credentials' do
    it 'should error accessing the merchant' do
      expect { @invalid_gateway.merchant }.to raise_exception(ChargeIO::Unauthorized)
    end
  end

  describe 'with valid credentials' do
    it 'should retrieve the merchant' do
      merchant = @gateway.merchant
      merchant.name.should_not be_nil
      merchant.primary_merchant_account.should_not be_nil
      merchant.primary_merchant_account.attributes.has_key?('credit_enabled').should be false
      merchant.primary_merchant_account.attributes.has_key?('manual_capture_enabled').should be false
    end
  end

end
