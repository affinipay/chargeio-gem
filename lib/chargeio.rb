module ChargeIO
  DEFAULT_SITE = 'https://api.chargeio.com'
end

require 'active_support/core_ext/object'
require 'active_support/core_ext/hash'
require 'active_support/json'
require 'httparty'
require 'uri'


require 'chargeio/version'

require 'chargeio/errors/resource_not_found'
require 'chargeio/errors/server_error'
require 'chargeio/errors/unauthorized'

require 'chargeio/connection'
require 'chargeio/models/collection'
require 'chargeio/models/gateway'
require 'chargeio/models/base'
require 'chargeio/models/message'

require 'chargeio/models/merchant'
require 'chargeio/models/merchant_account'
require 'chargeio/models/ach_account'

require 'chargeio/models/token'
require 'chargeio/models/card'
require 'chargeio/models/bank'

require 'chargeio/models/transaction'
require 'chargeio/models/charge'
require 'chargeio/models/refund'
require 'chargeio/models/credit'
require 'chargeio/models/recurring_charge'
require 'chargeio/models/recurring_charge_occurrence'
require 'chargeio/models/signature'

require 'chargeio/models/event'