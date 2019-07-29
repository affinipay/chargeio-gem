chargeio-gem
============

Ruby gem to access the AffiniPay Payment Gateway

## Installation

To use the library in your application, add the following to your Gemfile:

    gem 'chargeio', :git => 'git@github.com:charge-io/chargeio-gem.git'

Alternatively, you can download and install the library:

    git clone git://github.com/charge-io/chargeio-gem.git
    cd chargeio-gem
    gem build chargeio.gemspec
    gem install chargeio-x.x.x.gem

Access to the AffiniPay Payment Gateway occurs through an instance of ChargeIO::Gateway. Gateway objects
require credentials (a secret key) to access your merchant data on the AffiniPay servers. Specify
the secret key as an argument when instantiating a ChargeIO::Gateway instance:

    gateway = ChargeIO::Gateway.new(:secret_key => secret_key)

You must tokenize all sensitive payment information before you submit it to AffiniPay. On your
payment form, use AffiniPay’s hosted fields to secure payment data and call
window.AffiniPay.HostedFields.getPaymentToken to create a one-time payment token. See
["Creating payment forms using hosted fields"](https://developers.affinipay.com/collect/create-payment-form-hosted-fields.html). Then, POST the payment token ID to your Ruby web application.

With your Gateway instance created, run a charge using the payment token:

    token_id = lUi5VesmStiZo0ss5I0t5w
    charge = gateway.charge(100, :account_id => '12334455667', :method => token_id, :reference => 'Invoice 12345')

## Documentation

The latest AffiniPay Payment Gateway API documentation is available at https://developers.affinipay.com/reference/api.html#PaymentGatewayAPI.

## Development

To successfully run tests, you must have an AffiniPay merchant account that matches the following configuration:
-   At least one test-mode eCheck account (for eCheck payments)
-   At least one test-mode credit account (for credit card payments)
-   No daily/monthly transaction limit set on your test-mode accounts
-   CVV policy set to "_Optional_"
-   AVS policy set to "_Address or Postal Code Match - Lenient_"
-   No additional **Required Payment Fields** checked other than those set by default after selecting a CVV/AVS policy

Contact [support](mailto:devsupport@affinipay.com) if you need an AffiniPay merchant account or to remove transaction limits from your test accounts.

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

## License
  [MIT](./LICENSE.txt) © AffiniPay LLC
