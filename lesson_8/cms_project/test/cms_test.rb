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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => {username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]

    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
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
    create_document "about.md", "# Ruby is..."
    html_content = "<h1>Ruby is...</h1>"

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, html_content
  end

  def test_document_not_found
    get '/notrealdocument.txt'
    assert_equal 302, last_response.status
    assert_equal "notrealdocument.txt does not exist.", session[:error]
  end

  def test_view_edit_content_form
    content = "The Changes Text File"
    create_document "changes.txt", content

    get '/changes.txt/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit content of changes.txt:"

    # copied/pasted:
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_edit_content_form_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_updating_content
    content = "The Changes Text File"
    create_document "changes.txt", content

    post "/changes.txt/edit", { new_content: "New test content."}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:success]

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "New test content."
  end

  def test_updating_content_signed_out
    post "/changes.txt/edit", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_view_new_file_form
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, %q(<input type="text")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_file_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_new_file
    post '/new', { filename: "new_file.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "new_file.txt was created.", session[:success]

    get last_response["Location"]
    assert_includes last_response.body, %q(<a href="/new_file.txt">)
  end

  def test_create_new_file_signed_out
    post "/new", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_invalid_file
    post '/new', { filename: "" }, admin_session
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

    post '/test.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:success]

    get last_response["Location"]
    refute_includes last_response.body, %q(<a href="/test.txt">)
  end

  def test_deleting_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_sign_in_form
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, "Sign In"
  end

  def test_signing_in
    post '/users/signin', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
    assert_includes last_response.body, "Sign Out"
  end

  def test_signin_with_bad_credentials
    post '/users/signin', username: 'fake', password: 'invalid'
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signed_out
    get '/'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"
  end

  def test_signing_out
    get '/', {}, { "rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin."

    post '/users/signout'
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:success]
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end