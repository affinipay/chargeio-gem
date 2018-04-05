module ChargeIO
  class ServerError < StandardError
    attr_accessor :code
    attr_accessor :entity_id

    def initialize(message, code=nil, entity_id=nil)
      super(message)
      @code = code
      @entity_id = entity_id
    end
  end
end