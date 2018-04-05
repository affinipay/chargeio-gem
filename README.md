chargeio-gem
============

Ruby gem to access the chargeIO gateway

Installation
-----------

To use the library in your application, add the following to your Gemfile:

    gem 'chargeio', :git => 'git@github.com:charge-io/chargeio-gem.git'

Alternatively, you can download and install the library:

    git clone git://github.com/charge-io/chargeio-gem.git
    cd chargeio-gem
    gem build chargeio.gemspec
    gem install chargeio-x.x.x.gem

Access to the ChargeIO Gateway occurs through an instance of ChargeIO::Gateway. Gateway
objects require credentials to access your merchant data on the ChargeIO servers. Your
credentials consist of either your test or live-mode secret key, specified as an
argument to the construction of a Gateway instance:

    gateway = ChargeIO::Gateway.new(:secret_key => secret_key)

With your Gateway instance created, running a basic credit card charge looks like:

    card = {
        type: 'card',
        number: '4242424242424242',
        exp_month: 10,
        exp_year: 2020,
        cvv: 123,
        name: 'Some Customer'
    }
    charge = gateway.charge(100, :method => card, :reference => 'Invoice 12345')

Using the ChargeIO.js library for payment tokenization support on your payment page
simplifies the process even more. Just configure the token callback on your page to
POST the amount and the token ID received to your Ruby web application and then
perform the charge:

    amount = ...
    token_id = ...
    charge = gateway.charge(amount, :method => token_id)

Documentation
-----------

The latest ChargeIO API documentation is available at https://developers.affinipay.com/reference/api.html#PaymentGatewayAPI.


Development
-----------

To successfully run tests, you must have an AffiniPay merchant account that matches the following configuration:
-   At least one test-mode ACH _and_ one test-mode credit account
-   No daily/monthly transaction limit set on your test-mode accounts
-   CVV policy set to "_Optional_"
-   AVS policy set to "_Address or Postal Code Match - Lenient_"
-   No additional **Required Payment Fields** checked other than those set by default after selecting a CVV/AVS policy

Contact [support](mailto:devsupport@affinipay.com) if you need an AffiniPay merchant account or to remove transaction limits from your test account(s). Refer to [AVS and CVV Policies](https://developers.affinipay.com/basics/account-management.html) for policy configuration information.

Run all tests:
```
secret_key=<secret_key> rake
```

Run a test suite:
```
secret_key=<secret_key> rspec spec/integration/<path_to_spec>.rb
```

Where `<path_to_spec.rb>` is one of the following:
-   account_spec.rb
-   ach_spec.rb
-   gateway_spec.rb
-   token_spec.rb
-   transaction_spec.rb
