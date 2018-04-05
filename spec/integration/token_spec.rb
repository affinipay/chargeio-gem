require 'spec_helper'
require 'securerandom'

describe "Token" do
  before(:all) do
    skip("No secret_key specified in environment") unless ENV['secret_key']
    @gateway = ChargeIO::Gateway.new(DEFAULT_MERCHANT_TEST_MODE_OPTIONS.clone)
    @token_params = DEFAULT_CARD_PARAMS.clone
    @card_params = DEFAULT_CARD_PARAMS.clone
  end

  describe 'token creation and deletion' do
    it 'should succeed with one-time tokens' do
      t = @gateway.create_token(@token_params)
      t.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.id.should_not be_nil
    end
    it 'should succeed with card tokens' do
      t = @gateway.create_card(@card_params.merge(:description => 'My card desc'))
      t.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.id.should_not be_nil
      t.description.should eq 'My card desc'

      t = @gateway.delete_card(t.id)
      t.should_not be_nil
      t.errors.present?.should be false
    end
    it 'should default the saved card type when not specified' do
      token_params = @card_params.clone
      token_params.delete('type')

      t = @gateway.create_card(token_params)
      t.should_not be_nil
      t.errors.present?.should be false
      t.id.should_not be_nil
      t.card_type.should eq 'VISA'
    end
    it 'should succeed in creating a card from a token' do
      t = @gateway.create_token(@token_params.merge(:description => 'Some desc'))
      t.should_not be_nil
      t.errors.present?.should be false
      t.messages.present?.should be false
      t.id.should_not be_nil
      t.description.should eq 'Some desc'

      c = @gateway.create_card(:token_id => t.id)
      c.should_not be_nil
      c.errors.present?.should be false
      c.id.should_not be_nil
      c.card_type.should eq t.card_type
      c.number.should eq t.number
      c.exp_month.should eq t.exp_month
      c.exp_year.should eq t.exp_year
      c.attributes.has_key?('cvv').should be false
      c.name.should eq t.name
      c.address1.should eq t.address1
      c.postal_code.should eq t.postal_code
      c.description.should eq 'Some desc'
    end
  end

  describe 'one-time token creation failures' do
    it 'should return is_blank' do
      token = @gateway.create_token(@token_params.merge(:number => ''))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.number'].should == [ 'Card number cannot be blank' ]
    end
    it 'should return invalid_length (too short)' do
      token = @gateway.create_token(@token_params.merge(:number => '41111'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.number'].should == [ 'Card number length is invalid' ]
    end
    it 'should return card invalid due to truncation' do
      token = @gateway.create_token(@token_params.merge(:number => '411111111111111111112'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['base'].should == [ 'Card number is invalid' ]
    end
    it 'should return card_number_invalid' do
      token = @gateway.create_token(@token_params.merge(:number => '4242424242424241'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['base'].should == [ 'Card number is invalid' ]
    end

    it 'should return below_minimum_value' do
      token = @gateway.create_token(@token_params.merge(:exp_month => 0))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return exceeds_maximum_value' do
      token = @gateway.create_token(@token_params.merge(:exp_month => 13))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return card_expired' do
      token = @gateway.create_token(@token_params.merge(:exp_year => 2012))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['base'].should == [ 'Card is expired' ]
    end
    it 'should return invalid' do
      token = @gateway.create_token(@token_params.merge(:exp_month => 'Feb'), 'form')
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.exp_month'].should == [ 'Expiration month cannot be blank' ]
    end
    it 'should return invalid' do
      token = @gateway.create_token(@token_params.merge(:exp_year => '201B'), 'form')
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.exp_year'].should == [ 'Expiration year cannot be blank' ]
    end
    it 'should return invalid' do
      token = @gateway.create_token(@token_params.merge(:exp_year => 10001))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.exp_year'].should == [ 'Expiration year is invalid' ]
    end

    it 'should return invalid_length' do
      token = @gateway.create_token(@token_params.merge(:cvv => '12'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.cvv'].should == [ 'Card code length is invalid' ]
    end
    it 'should accept due to CVV truncation' do
      token = @gateway.create_token(@token_params.merge(:cvv => '12345'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
    end
    it 'should return invalid' do
      token = @gateway.create_token(@token_params.merge(:cvv => '54!'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.cvv'].should == [ 'Card code is invalid' ]
    end

    it 'should accept due to name truncation' do
      token = @gateway.create_token(@token_params.merge(:name => 'Aname Thatiswaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaytooooooooooooooooooooooooooooooooolong'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:name].should == 'Aname Thatiswaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaytooooooooooooo'
    end

    it 'should accept due to address1 truncation' do
      token = @gateway.create_token(@token_params.merge(:address1 => '1503908349058459834 Reallylongnameofastreetintheunitedstatesofamericathatiwouldntwanttoliveon'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:address1].should == '1503908349058459834 Reallylongnameofastreetintheunitedstatesofam'
    end
    it 'should accept due to address2 truncation' do
      token = @gateway.create_token(@token_params.merge(:address2 => 'Building 783624872348923423498723948723, Suite 983425908234098234, Apt 3987345897345'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:address2].should == 'Building 783624872348923423498723948723, Suite 98342590823409823'
    end
    it 'should accept due to city truncation' do
      token = @gateway.create_token(@token_params.merge(:city => 'Areallylongnameofacityintheunitedstatesofamericamanwouldieverhatetohavetowritethis'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:city].should == 'Areallylongnameofacityintheunitedstatesofamericamanwouldieverhat'
    end

    it 'should return invalid state' do
      token = @gateway.create_token(@token_params.merge(:state => 'F', :country => 'US'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      token = @gateway.create_token(@token_params.merge(:state => 'BIG', :country => 'US'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      token = @gateway.create_token(@token_params.merge(:state => 'FX', :country => 'US'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      token = @gateway.create_token(@token_params.merge(:state => 'TX', :country => 'CA'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be true
      transaction.errors['method.state'].should == [ 'State or province is invalid' ]
    end

    it 'should accept due to postal code truncation' do
      token = @gateway.create_token(@token_params.merge(:postal_code => '78726-12345'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:postal_code].should == '78726-1234'
    end
    it 'should strip invalid characters and accept the alphanumeric value' do
      token = @gateway.create_token(@token_params.merge(:postal_code => '78_726+62A'))
      token.errors.present?.should be false

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.method[:postal_code].should == '7872662A';
    end

    it 'should authorize with empty country due to too-short invalid country code' do
      token = @gateway.create_token(@token_params.merge(:country => 'U'))
      token.errors.present?.should be false
      token.attributes.should_not have_key :country

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.attributes['method'].should_not have_key :country
    end
    it 'should authorize with empty country due to too-long invalid country code' do
      token = @gateway.create_token(@token_params.merge(:country => 'USA'))
      token.errors.present?.should be false
      token.attributes.should_not have_key :country

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.attributes['method'].should_not have_key :country
    end
    it 'should authorize with empty country due to invalid country code' do
      token = @gateway.create_token(@token_params.merge(:country => 'ZZ'))
      token.errors.present?.should be false
      token.attributes.should_not have_key :country

      transaction = @gateway.authorize(100, :method => token.id)
      transaction.errors.present?.should be false
      transaction.attributes['method'].should_not have_key :country
    end
  end

  describe 'card creation failures' do
    it 'should return number is_blank' do
      card = @gateway.create_card(@card_params.merge(:number => ''))
      card.errors.present?.should be true
      card.errors['number'].should == [ 'Card number cannot be blank' ]
    end
    it 'should return number invalid_length (too short)' do
      card = @gateway.create_card(@card_params.merge(:number => '41111'))
      card.errors.present?.should be true
      card.errors['number'].should == [ 'Card number length is invalid' ]
    end
    it 'should return number invalid_length (too long)' do
      card = @gateway.create_card(@card_params.merge(:number => '411111111111111111112'))
      card.errors.present?.should be true
      card.errors['number'].should == [ 'Card number length is invalid' ]
    end

    it 'should return exp_month is_blank' do
      card = @gateway.create_card(@card_params.merge(:exp_month => ''))
      card.errors.present?.should be true
      card.errors['exp_month'].should == [ 'Expiration month cannot be blank' ]
    end
    it 'should return exp_month below_minimum_value' do
      card = @gateway.create_card(@card_params.merge(:exp_month => 0))
      card.errors.present?.should be true
      card.errors['exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return exp_month exceeds_maximum_value' do
      card = @gateway.create_card(@card_params.merge(:exp_month => 13))
      card.errors.present?.should be true
      card.errors['exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return exp_month invalid' do
      card = @gateway.create_card(@card_params.merge(:exp_month => 'Feb'))
      card.errors.present?.should be true
      card.errors['exp_month'].should == [ 'Expiration month is invalid' ]
    end
    it 'should return exp_year is_blank' do
      card = @gateway.create_card(@card_params.merge(:exp_year => ''))
      card.errors.present?.should be true
      card.errors['exp_year'].should == [ 'Expiration year cannot be blank' ]
    end
    it 'should return exp_year invalid' do
      card = @gateway.create_card(@card_params.merge(:exp_year => '201B'))
      card.errors.present?.should be true
      card.errors['exp_year'].should == [ 'Expiration year is invalid' ]
    end
    it 'should return exp_year invalid' do
      card = @gateway.create_card(@card_params.merge(:exp_year => 10001))
      card.errors.present?.should be true
      card.errors['exp_year'].should == [ 'Expiration year is invalid' ]
    end

    it 'should return cvv invalid_length' do
      card = @gateway.create_card(@card_params.merge(:cvv => '12'))
      card.errors.present?.should be true
      card.errors['cvv'].should == [ 'Card code length is invalid' ]
    end
    it 'should return cvv invalid_length' do
      card = @gateway.create_card(@card_params.merge(:cvv => '12345'))
      card.errors.present?.should be true
      card.errors['cvv'].should == [ 'Card code length is invalid' ]
    end
    it 'should return cvv invalid' do
      card = @gateway.create_card(@card_params.merge(:cvv => '54!'))
      card.errors.present?.should be true
      card.errors['cvv'].should == [ 'Card code is invalid' ]
    end

    it 'should return name invalid_length' do
      card = @gateway.create_card(@card_params.merge(:name => 'Aname Thatiswaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaytooooooooooooooooooooooooooooooooolong'))
      card.errors.present?.should be true
      card.errors['name'].should == [ 'Name length is invalid' ]
    end

    it 'should return address1 invalid_length' do
      card = @gateway.create_card(@card_params.merge(:address1 => '1503908349058459834 Reallylongnameofastreetintheunitedstatesofamericathatiwouldntwanttoliveon'))
      card.errors.present?.should be true
      card.errors['address1'].should == [ 'Street number length is invalid' ]
    end
    it 'should return address2 invalid_length' do
      card = @gateway.create_card(@card_params.merge(:address2 => 'Building 783624872348923423498723948723, Suite 983425908234098234, Apt 3987345897345'))
      card.errors.present?.should be true
      card.errors['address2'].should == [ 'Address length is invalid' ]
    end
    it 'should return city invalid_length' do
      card = @gateway.create_card(@card_params.merge(:city => 'Areallylongnameofacityintheunitedstatesofamericamanwouldieverhatetohavetowritethis'))
      card.errors.present?.should be true
      card.errors['city'].should == [ 'City length is invalid' ]
    end

    it 'should return invalid state' do
      card = @gateway.create_card(@card_params.merge(:state => 'F', :country => 'US'))
      card.errors.present?.should be true
      card.errors['state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      card = @gateway.create_card(@card_params.merge(:state => 'BIG', :country => 'US'))
      card.errors.present?.should be true
      card.errors['state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      card = @gateway.create_card(@card_params.merge(:state => 'FX', :country => 'US'))
      card.errors.present?.should be true
      card.errors['state'].should == [ 'State or province is invalid' ]
    end
    it 'should return invalid state' do
      card = @gateway.create_card(@card_params.merge(:state => 'TX', :country => 'CA'))
      card.errors.present?.should be true
      card.errors['state'].should == [ 'State or province is invalid' ]
    end

    it 'should return postal_code invalid_length' do
      card = @gateway.create_card(@card_params.merge(:postal_code => '78726-12345'))
      card.errors.present?.should be true
      card.errors['postal_code'].should == [ 'Postal code is invalid' ]
    end
    it 'should return postal_code invalid' do
      card = @gateway.create_card(@card_params.merge(:postal_code => '78_726+62A'))
      card.errors.present?.should be true
      card.errors['postal_code'].should == [ 'Postal code is invalid' ]
    end

    it 'should return country invalid_length' do
      card = @gateway.create_card(@card_params.merge(:country => 'U'))
      card.errors.present?.should be true
      card.errors['country'].should == [ 'Country length is invalid' ]
    end
    it 'should return country invalid_length' do
      card = @gateway.create_card(@card_params.merge(:country => 'USA'))
      card.errors.present?.should be true
      card.errors['country'].should == [ 'Country length is invalid' ]
    end
    it 'should return country invalid' do
      card = @gateway.create_card(@card_params.merge(:country => 'ZZ'))
      card.errors.present?.should be true
      card.errors['country'].should == [ 'Country is invalid' ]
    end
  end
end
