require "test_helper"

class DocsAndPagesControllerTest < ActionDispatch::IntegrationTest
  test "documentation page renders publicly" do
    get docs_path

    assert_response :ok
  end

  test "static legal pages render publicly" do
    get privacy_path
    assert_response :ok

    get terms_path
    assert_response :ok

    get about_path
    assert_response :ok
  end
end
