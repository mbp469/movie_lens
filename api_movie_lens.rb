require 'sinatra'
require 'yaml'
require_relative 'models/movie'
require_relative 'models/user'
require_relative 'models/rating'
require 'json'
require "sinatra/cross_origin"

database_config = YAML::load(File.open('config/database.yml'))

before do
  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
  content_type :json
end

after do
  ActiveRecord::Base.connection.close
end

get '/foo' do
  headers 'Access-Control-Allow-Origin' => 'https://arcane-woodland-29724.herokuapp.com'
  'hello world'
end

options '/*' do
  response["Access-Control-Allow-Headers"] = "origin, x-requested-with, content-type"
end

register Sinatra::CrossOrigin

configure do
  enable :cross_origin
end

get '/api/movies/title' do
  if !params['search'].nil?
    movie = Movie.where("title like (?)", "%#{params['search']}%")
    if movie.empty?
      halt(404)
    end
    status 200
    movie.to_json
  end
end

get '/api/movies/title_avg_rating' do
  movie_info = Movie.select('title, imdb_url, id, avg(rating), count(rating)').joins("INNER JOIN ratings ON movies.id = ratings.movie_id").where('title like (?)', "%#{params['search']}%").group('title, imdb_url, id').to_json
end

get '/api/users/:id' do
  user = User.find_by(id: params['id'])
  ratings = Rating.select(:movie_id, :rating, :title).joins("INNER JOIN users ON ratings.user_id = users.id").where(user_id: params[:id]).joins("INNER JOIN movies ON ratings.movie_id = movies.id").all
  payload = {'user' => user, 'ratings' => ratings}
  if user.nil?
    halt(404)
  end
  status 200
  payload.to_json
end

get '/api/movies/all/:id' do
  movie = Movie.select('title, imdb_url, id, avg(rating), count(rating), unknown_genre, action, adventure, animation, children, comedy, crime, documentary, drama, fantasy, film_noir, horror, musical, mystery, romance, sci_fi, thriller, war, western').joins("INNER JOIN ratings ON movies.id = ratings.movie_id").where(id: params['id']).group('title, imdb_url, id').first

  ratings = Rating.select(:user_id, :rating).joins("INNER JOIN users ON ratings.user_id = users.id").where(movie_id: params[:id]).joins("INNER JOIN movies ON ratings.movie_id = movies.id").all

  movie_hash = movie.as_json
  movie_hash['ratings'] = ratings.as_json
  movie_hash.to_json
end

get '/api/movies_count' do
  Movie.count.to_json
end

get '/api/ratings_count' do
  Rating.count.to_json
end

get '/api/users_count' do
  User.count.to_json
end

get '/api/movies/:id' do
  movie = Movie.find_by_id(params['id'])
  if movie.nil?
    halt(404)
  end
  status 200
  movie.to_json
end

get '/api/ratings/average/:movie_id' do
  average = Rating.where(movie_id: params['movie_id']).average("rating")
  status 200
  average.to_json
end

get '/api/ratings/all_ratings/:movie_id' do
  ratings = Rating.select(:movie_id, :user_id, :title, :rating, :imdb_url, :release_date).joins("INNER JOIN movies ON ratings.movie_id = movies.id").where(movie_id: params['movie_id']).joins("INNER JOIN users ON ratings.user_id = users.id").all.to_json
end

post '/api/new_user' do
  user = User.new(id: User.maximum(:id).next, age: params['age'], gender: params['gender'], occupation: params['occupation'], zip_code: params['zip_code'])
  if user.valid?
    if user.save
      status 201
      return user.to_json
    end
    status 400
  end
  halt(400)
end

put '/api/update_user' do # need to validate by user id and movie id/title
  u = User.find_by(id: params[:id])
  if u.nil?
    halt(400)
  end
  status 200
  u.update(
    age: params['age'],
    gender: params['gender'],
    occupation: params['occupation'],
    zip_code: params['zip_code']
  ).to_json
end

post '/api/new_rating' do
    r = Rating.create(user_id: params['user_id'], movie_id: params['movie_id'], rating: params['rating'])
    r.to_json
    status 201
end

put '/api/update_rating' do
  r = Rating.where(user_id: params['user_id'], movie_id: params['movie_id'])
  if r.nil?
    halt(404)
  else
    status 200
    r.update_all(
      :user_id => params['user_id'],
      :movie_id => params['movie_id'],
      :rating => params['rating'],
      :timestamp => params['timestamp']
    ).to_json
  end
end
