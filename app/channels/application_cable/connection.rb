module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # Minimal connection; we don't strictly identify users here.
    # If needed later, add `identified_by :current_user` and look up from cookies/session.
    def connect
      # Accept all connections for now
    end
  end
end

