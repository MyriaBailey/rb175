# The official solution ruby app file.

# list.rb
require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

get "/" do
  @files = Dir.glob("public/*").map {|file| File.basename(file) }.sort
  @files.reverse! if params[:sort] == "desc"
  erb :list
end