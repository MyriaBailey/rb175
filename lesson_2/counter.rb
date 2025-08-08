require "socket"

def parse_request(request_line)
  http_method, path_and_params, version = request_line.split
  path, params = path_and_params.split("?")

  # if params
  params = (params || "").split("&")

  params = params.map { |pair| pair.split("=") }
  params = params.to_h
  # end

  [http_method, path, params]
end

server = TCPServer.new("localhost", 3003)

loop do
  client = server.accept

  request_line = client.gets
  puts request_line

  next unless request_line
  http_method, path, params = parse_request(request_line)

  client.puts "HTTP/1.0 200 OK"
  client.puts "Content-Type: text/html"
  client.puts

  client.puts "<html>"
  client.puts "<body>"

  client.puts "<pre>"
  client.puts request_line
  client.puts "Method: #{http_method}"
  client.puts "Path: #{path}"
  client.puts "Querry: #{params}"
  client.puts "</pre>"

  client.puts "<h2>Counter</h2>"

  number = params ? params["number"].to_i : 0
  client.puts "<p>The current number is #{number}.</p>"

  client.puts "<a href='?number=#{number + 1}'>Add one</a>"
  client.puts "<a href='?number=#{number - 1}'>Subtract one</a>"

  client.puts "</body>"
  client.puts "</html>"
  
  client.close
end