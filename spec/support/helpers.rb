module ChargeIO
  module Helpers
    def payment_method_attributes
      {
        :name   => "FirstName LastName",
        :address1    => "123 Main St.",
        :address2    => "Apt #3",
        :city         => "Chicago",
        :state        => "IL",
        :postal_code  => "10101",
        :card_number  => "4111-1111-1111-1111",
        :cvv          => "123",
        :expiration_month => '03',
        :expiration_year  => "2015",
      }
    end

    def random_string(length=16)
      chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
      value = ''
      length.times { value << chars[rand(chars.size)] }
      value
    end
  end
end
