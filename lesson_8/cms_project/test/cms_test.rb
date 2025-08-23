ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils" # for working with (making) files/paths

require_relative "../cms.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_get
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_viewing_txt_file
    content = "The History File."
    create_document "history.txt", content

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    
    assert_includes last_response.body, content
  end

  def test_viewing_markdown_file
    md_content = "# Ruby is..."
    create_document "about.md", md_content

    html_content = "<h1>Ruby is...</h1>"

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, html_content
  end

  def test_document_not_found
    get '/notrealdocument.txt'
    assert_equal 302, last_response.status

    get last_response["Location"]
    error_msg = "notrealdocument.txt does not exist."
    assert_equal 200, last_response.status
    assert_includes last_response.body, error_msg

    get '/'
    assert_equal 200, last_response.status
    refute_includes last_response.body, error_msg
  end

  def test_edit_content
    content = "The Changes Text File"
    create_document "changes.txt", content

    get '/changes.txt/edit'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of changes.txt:"

    # copied/pasted:
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_content
    content = "The Changes Text File"
    create_document "changes.txt", content

    post "/changes.txt/edit", new_content: "New test content."
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "changes.txt has been updated."

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "New test content."
  end

  def test_view_new_file_form
    get '/new'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, %q(<input type="text")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_file
    post '/new', filename: "new_file.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new_file.txt was created."
    assert_includes last_response.body, %q(<a href="/new_file.txt">)
  end

  def test_create_invalid_file
    post '/new', filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Filename must not be empty."
  end

  def test_delete_btns
    create_document("test.txt")
    button = %q(<button type="submit">Delete</button>)

    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, button
  end

  def test_delete_file
    create_document("test.txt")

    post '/test.txt/delete'
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted."
    refute_includes last_response.body, %q(<a href="/test.txt">)
  end
end