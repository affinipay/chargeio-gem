# rspec documentation: http://rubydoc.info/gems/rspec-core/frames/file/README.md

require 'rspec'
require 'pp'
require 'money'

# uncomment below to see requests
#require 'net-http-spy'
# uncomment below to set higher verbosity
#Net::HTTP.http_logger_options = {:verbose => true}

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

SITE = 'https://api.chargeio.com/'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

include ChargeIO::Helpers

require 'chargeio'

DEFAULT_MERCHANT_TEST_MODE_OPTIONS = {
  :site => ENV['site'] || SITE,
  :secret_key => ENV['secret_key']
}

DEFAULT_CARD_PARAMS = {
    type: 'card',
    number: '4242424242424242',
    card_type: 'VISA',
    exp_month: 10,
    exp_year: 2020,
    cvv: 123,
    name: 'Some Customer',
    address1: '123 Main St',
    postal_code: '78730',
    email_address: 'customer@example.com'
}

MC_CARD_PARAMS = {
    type: 'card',
    number: '5499740000000057',
    card_type: 'MASTERCARD',
    exp_month: 12,
    exp_year: 2020,
    cvv: '998',
    name: 'Test Customer',
    address1: '123 N. Main St.',
    address2: 'Apt. 4-D',
    postal_code: '99997-0008',
    email_address: 'mc_user@example.com'
}

DEFAULT_ACH_PARAMS = {
    type: 'bank',
    routing_number: '000000013',
    account_number: '1234567890',
    account_type: 'CHECKING',
    name: 'Some Customer'
}

DEFAULT_SIGNATURE_DATA = '[{"x":[179,179,179,179,180,188,195,206,218,228,245,252,261,267,270,270,269,262,254,246,237,230,225,221,219,219,222,229,239,251,263,274,282,286,288,289,286],"y":[77,84,89,97,104,113,120,127,132,133,133,133,128,121,114,106,99,93,87,85,85,85,87,93,99,109,120,129,138,144,146,147,145,141,134,130,127]}]'
