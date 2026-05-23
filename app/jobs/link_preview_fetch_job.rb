class LinkPreviewFetchJob < ApplicationJob
  queue_as :default

  def perform(url)
    LinkPreviewService.fetch_and_cache(url)
  end
end
