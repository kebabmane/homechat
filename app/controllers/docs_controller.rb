class DocsController < ApplicationController
  layout "documentation"

  skip_before_action :mark_active
  skip_before_action :set_sidebar_data

  def index
  end
end
