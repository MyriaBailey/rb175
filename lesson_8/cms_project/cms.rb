require 'sinatra'
require 'sinatra/reloader'
require 'redcarpet' # for markdown -> html rendering

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

# Homepage
get '/' do
  @files = files.map { |file_path| File.basename(file_path) }
  erb :index
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
  file = full_path(params[:filename])

  redirect_invalid_file(file)
  load_file(file)
end

# Form page to edit a file
get '/:filename/edit' do
  @filename = params[:filename]

  file = full_path(@filename)
  redirect_invalid_file(file)

  @content = File.read(file)
  erb :edit_file_content
end

# Post request to submit file edits
post '/:filename/edit' do
  @filename = params[:filename]

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

=begin
- messages should have yellow bg
- messages disappear on reload (done?)
- text files still plain text
- full site (md, but not txt) use sans-serif typeface

css file
- new layout to put everything in body ??
- body? use sans-serif
- class flash success/error background yellow
=end