require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

before do
  @contents = File.readlines "data/toc.txt"
end

get "/" do
  @title = "The Adventures of Sherlock Holmes"

  erb :home
end

get "/chapters/:num" do  
  ch_num = params[:num].to_i
  ch_name = @contents[ch_num - 1]

  redirect "/" unless (1..@contents.size).cover?(ch_num) 

  @title = "Chapter #{ch_num}: #{ch_name}"
  @chapter_text = File.read "data/chp#{ch_num}.txt"
  @chapter_text = in_paragraphs(@chapter_text)

  erb :chapter
end

get "/show/:name" do
  "<p>Name is: #{params[:name]}</p>"
end

get "/search" do
  @search_results = search(params[:query])
  erb :search
end

not_found do
  redirect "/"
end

helpers do
  def in_paragraphs(text)
    text.split("\n\n").map.with_index do |paragraph, idx|
      "<p id=#{idx}>#{paragraph}</p>"
    end.join
  end

  def highlight(text, query)
    text.gsub(query, "<strong>#{query}</strong>")
  end
end

=begin
Searching!

on range from 1 to contents size, SELECT:
  text = File.read current ch.
  true if text.include query or title(contents num - 1).include query
selection arr of ~~titles~~ chapter numbers!!

this gives Selection array
=end

def each_chapter
  @contents.each_with_index do |name, idx|
    number = idx + 1
    text = File.read("data/chp#{number}.txt")
    yield number, name, text
  end
end

# def each_paragraph(text)
#   text.split("\n\n")
# end

def search(query)
  results = []
  return results if query.nil?

  each_chapter do |number, name, text|
    paragraphs = text.split("\n\n")

    paragraphs.each_with_index do |paragraph, idx|
      if paragraph.include?(query)
        results << {
          number: number,
          name: name,
          text: text,
          paragraph: paragraph,
          id: idx        
        }
      end
    end
  end

  results
end

# def search(query)
#   return [] if query.nil?

#   results = (1..@contents.size).select do |ch_num|
#     title = @contents[ch_num - 1]
#     text = File.read("data/chp#{ch_num}.txt")

#     title.include?(query) || text.include?(query)
#   end

#   results.map do |ch_num|
#     { number: ch_num, title: @contents[ch_num - 1] }
#   end
# end
