require "test_helper"

class LinkPreviewServiceTest < ActiveSupport::TestCase
  test "extract_urls deduplicates and limits to two urls" do
    text = "A https://example.com B https://example.org C https://example.com D https://example.net"

    urls = LinkPreviewService.extract_urls(text)

    assert_equal [ "https://example.com", "https://example.org" ], urls
  end

  test "cached_preview rejects private network urls" do
    assert_nil LinkPreviewService.cached_preview("http://127.0.0.1/private")
    assert_nil LinkPreviewService.cached_preview("http://10.0.0.1/private")
    assert_nil LinkPreviewService.cached_preview("http://169.254.169.254/latest/meta-data")
    assert_nil LinkPreviewService.cached_preview("http://[::1]/private")
    assert_nil LinkPreviewService.cached_preview("http://[fc00::1]/private")
  end

  test "extract_urls strips punctuation commonly surrounding links" do
    text = "See (https://example.com/path), then https://example.org/end."

    assert_equal [ "https://example.com/path", "https://example.org/end" ], LinkPreviewService.extract_urls(text)
  end
end
