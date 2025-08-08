require 'sinatra'
require 'sinatra/reloader'
require 'yaml'

before do
  @users = YAML.load_file("users.yaml") # returns hash of hashes
end

get '/' do
  redirect '/users'
end

get '/users' do
  erb :users
end

get '/users/:username' do
  @username = params[:username].to_sym
  @userdata = @users[@username]
  # display email address and interests (comma separated)
  # list links to all other user pages (excluding current)
  erb :user_page
end

helpers do
  def user_link(username)
    "<a href='/users/#{username}'>#{username}</a>"
  end
end

def count_interests
  count = 0
  @users.each do |username, userdata|
    count += userdata[:interests].count
  end
  count
end

# layout: bottom of every page that says smth like
# "3 users with a total of 9 interests"
# use a view helper method count_interests to determine this info

# add a new user to verify it all updates accordingly

=begin
1. create a linked list of usernames (used for all pages)

=end