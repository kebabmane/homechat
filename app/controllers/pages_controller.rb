class PagesController < ApplicationController
  layout 'authentication'

  skip_before_action :mark_active
  skip_before_action :set_sidebar_data

  def privacy; end
  def terms; end
  def about; end
end

