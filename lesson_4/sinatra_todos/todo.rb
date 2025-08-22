require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubi"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todos = list[:todos]
    todos.any? && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def each_list_sorted(lists, &block)
    lists = lists.partition { |list| !list_complete?(list) }.flatten(1)
    
    lists.each(&block)
  end

  def each_todo_sorted(list, &block)
    # todos = list[:todos].map { |todo| [todo, todo[:id]] }
    todos = list[:todos]
    todos = todos.partition { |todo| !todo[:completed] }.flatten(1)
    
    todos.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

get "/help" do
  erb "self is: '#{self.methods}'."
end

get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

def error_for_list_name(name, old_name = "")
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif name == old_name
    # "List name must be different."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def new_list_id
  return 0 if session[:lists].empty?

  max = session[:lists].max_by { |list| list[:id] }
  max[:id] + 1
end

# Creating a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = new_list_id
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

def redirect_invalid_list(id)
  list = session[:lists].find { |list| list[:id] == id }

  if list.nil?
    session[:error] = "The specified list was not found."
    redirect "/lists"
  end
end

def find_list(list_id)
  session[:lists].find { |list| list[:id] == list_id }
end

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = find_list(@list_id)

  redirect_invalid_list(@list_id)
  erb :list, layout: :layout
end

get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = find_list(id)

  redirect_invalid_list(id)
  erb :edit_list, layout: :layout
end

post "/lists/:id" do
  id = params[:id].to_i
  @list = find_list(id)
  redirect_invalid_list(id)

  new_name = params[:new_name].strip
  error = error_for_list_name(new_name, @list[:name])

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

post "/lists/:id/delete" do
  id = params[:id].to_i
  redirect_invalid_list(id)
  list = find_list(id)

  deleted_list = session[:lists].delete(list)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end  
end

def error_for_todo_name(name, old_name = "")
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

def next_todo_id(todos)
  return 0 if todos.empty?

  max = todos.max_by { |todo| todo[:id] }
  max[:id] + 1
end

post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = find_list(@list_id)
  redirect_invalid_list(@list_id)

  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])

    @list[:todos] << { id: id, name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

def find_todo(list, todo_id)
  list[:todos].find { |todo| todo[:id] == todo_id }
end

post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  list = find_list(list_id)

  todo_id = params[:todo_id].to_i
  todo = find_todo(list, todo_id)

  todo = list[:todos].delete(todo)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo was deleted."
    redirect "/lists/#{list_id}"
  end
end

post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  list = find_list(list_id)
  
  todo_id = params[:todo_id].to_i
  todo = find_todo(list, todo_id)

  is_completed = params[:completed] == "true"

  if todo
    todo[:completed] = is_completed
    session[:success] = "The todo has been updated."
  else
    session[:error] = "Nonexistent todo."
  end

  redirect "/lists/#{list_id}"
end

post "/lists/:list_id/complete_all" do
  list_id = params[:list_id].to_i
  redirect_invalid_list(list_id)

  list = find_list(list_id)

  list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "Todos marked completed."
  redirect "/lists/#{list_id}"
end




=begin
for a given view, we have a Block of code, passed into a Method
  (will yield to the block)
the block must use the actual correct list + list ID
- sorting block maps the list to nested arr of [list, idx]
- sorts the mapped list (or partitions, or ?)
  - for each mapped+sorted element, yield to block
=end