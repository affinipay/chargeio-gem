module ChargeIO

  class Collection < Array
    attr_reader :current_page, :per_page, :total_entries

    def initialize(page, per_page, total)
      @current_page = page.to_i
      @per_page = per_page.to_i
      @total_entries = total.to_i
    end

    def total_pages
      total_entries.zero? ? 1 : (total_entries / per_page.to_f).ceil
    end

    # current_page - 1 or nil if there is no previous page
    def previous_page
      current_page > 1 ? (current_page - 1) : nil
    end

    # current_page + 1 or nil if there is no next page
    def next_page
      current_page < total_pages ? (current_page + 1) : nil
    end

    # Helper method that is true when someone tries to fetch a page with a
    # larger number than the last page. Can be used in combination with flashes
    # and redirecting.
    def out_of_bounds?
      current_page > total_pages
    end

  end

end
