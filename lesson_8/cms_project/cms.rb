require 'sinatra'
require 'sinatra/reloader'
require 'redcarpet' # for markdown -> html rendering
require 'fileutils' # for making new files
require 'yaml' # for reading yaml files? wow
require 'bcrypt' # for password hashing

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def files
  pattern = File.join(data_path, "*")

  # Dir.glob("**/*.*", base: "data")
  Dir.glob(pattern)
end

def full_path(filename)
  File.join(data_path, filename)
end

def user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end

  YAML.load_file(credentials_path)
end

# Homepage
get '/' do
  @files = files.map { |file_path| File.basename(file_path) }
  @username = session[:username]
  erb :index
end

# Signin Page
get '/users/signin' do
  erb :signin
end

def valid_credentials?(username, password)
  credentials = user_credentials
  return false unless credentials[username] && password
  
  bcrypt_password = BCrypt::Password.new(credentials[username])
  bcrypt_password == password
end

def signed_in?
  !!session[:username]
end

def redirect_signed_out_users
  return if signed_in?
  session[:error] = "You must be signed in to do that."
  redirect '/'
end

post '/users/signin' do
  @username = params[:username]
  password = params[:password]

  if valid_credentials?(@username, password)
    session[:username] = @username
    session[:success] = "Welcome!"
    redirect '/'
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin
  end
end

# Signout Page
post '/users/signout' do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect '/'
end

# Form to add a new document
get '/new' do
  redirect_signed_out_users
  erb :new_file
end

def filename_error(filename)
  # path = full_path(filename)
  extension = File.extname(filename)

  if filename.empty?
    "Filename must not be empty."
  elsif filename.size > 20
    "Filename must be 20 characters or less."
  elsif extension.empty?
    "File must have a valid extension type."
  elsif filename.size <= extension.size
    "File must have a name."
  elsif files.include?(filename)
    "File already exists with that name."
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def sanitize_filename(filename)
  File.basename(filename.strip)
end

# Create new file from filename
post '/new' do
  redirect_signed_out_users
  @filename = sanitize_filename(params[:filename])
  error = filename_error(@filename)
  
  if error
    session[:error] = error
    status 422
    erb :new_file
  else
    create_document(@filename)
    session[:success] = "#{@filename} was created."
    redirect '/'
  end
end

def redirect_invalid_file(file)
  return if File.exist?(file)

  session[:error] = "#{File.basename(file)} does not exist."
  redirect '/'
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file(file)
  content = File.read(file)

  case File.extname(file)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  else
    session[:error] = "Filetype not recognized."
    redirect '/'
  end
end

# View File
get '/:filename' do
  filename = sanitize_filename(params[:filename])
  file = full_path(filename)

  redirect_invalid_file(file)
  load_file(file)
end

# Form page to edit a file
get '/:filename/edit' do
  redirect_signed_out_users
  @filename = sanitize_filename(params[:filename])

  file = full_path(@filename)
  redirect_invalid_file(file)

  @content = File.read(file)
  erb :edit_file_content
end

# Post request to submit file edits
post '/:filename/edit' do
  redirect_signed_out_users
  @filename = sanitize_filename(params[:filename])

  file_path = full_path(@filename)
  redirect_invalid_file(file_path) # optional?

  @content = File.read(file_path)
  @new_content = params[:new_content]

  if false # validate new_content here
    session[:error] = "Error while editing document."
    erb :edit_file_content
  else
    File.write(file_path, @new_content)
    session[:success] = "#{@filename} has been updated."
    redirect '/'
  end  
end

post '/:filename/delete' do
  redirect_signed_out_users
  @filename = sanitize_filename(params[:filename])

  file_path = full_path(@filename)
  redirect_invalid_file(file_path)

  File.delete(file_path)

  session[:success] = "#{@filename} has been deleted."
  redirect '/'
end



=begin
create file "credentials.yaml"
update valid password method
- does yaml hash of key username = value password?
=end