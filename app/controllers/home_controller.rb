class HomeController < ApplicationController
  # Always use the unauthenticated layout for marketing/landing,
  # even when the user is logged in (no sidebar).
  layout 'authentication'

  def index
  end
end
