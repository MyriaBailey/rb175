=begin
sorting/linking:

file handling:
1. create a list of files (in get '/' or home.erb?)
  - files from base public, so no public directory
  - arr of file paths
2. 
=end

require 'sinatra'
require 'sinatra/reloader'

get '/' do
  # show listing of all files in public directory
  # - only filename, NO directories AT ALL (even if nested)

  # on a file click, be taken directly to the file
  # - use sinatra's built-in serving of public directory

  # make at least 5 public files to test listing page
  # add parameter for sort order (alpha by default, or rev. alpha)
  # add link to reverse the order (use ?= query params!)
  @default_sort = !(params['sort'] == "descending")
  @files = Dir.glob("**/*.*", base: "public")

  erb :home
end