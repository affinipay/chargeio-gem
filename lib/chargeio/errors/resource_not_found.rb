module ChargeIO

  class ResourceNotFound < Error
    attr_accessor :resource_id

    def initialize(resource_id)
      super()
      @resource_id = resource_id
    end
  end

end
