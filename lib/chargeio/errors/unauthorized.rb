module ChargeIO
  class Unauthorized < Error
    attr_accessor :entity_id

    def initialize(message, entity_id=nil)
      super(message)
      @entity_id = entity_id
    end
  end
end