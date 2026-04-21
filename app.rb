require 'debug'
require 'sinatra'
require 'securerandom'
require 'bcrypt'

FAILED_ATTEMPTS = {}
MAX_ATTEMPTS = 5
COOLDOWN_SECONDS = 60


class App < Sinatra::Base
  
  def db
    return @db if @db

    @db = SQLite3::Database.new("db/sqlite.db")
    @db.results_as_hash = true
    @db.execute("PRAGMA foreign_keys = ON")

    return @db
  end

  configure do
    enable :sessions
    set :session_secret, SecureRandom.hex(64)
  end

  before do

    p "sdf"

    if session[:user_id]
      @current_user = db.execute("SELECT * FROM users WHERE id = ?", session[:user_id]).first
      ap @current_user
    end
  end

  

  # Routen /
  get '/' do
    redirect(:"/movies")
  end

  def require_login
    redirect '/login' unless session[:user_id]
  end

  get '/movies' do
    @movies = db.execute('SELECT * FROM movies')
    p @movies
    p @current_user
    erb(:"movies/index")
  end

  get '/users/new' do
    erb(:"movies/users/new")
  end

  post '/users' do
    username = params[:username]
    password = params[:password]
    password_hash = BCrypt::Password.create(password)
    db.execute("INSERT INTO users (username, password) VALUES (?, ?)", [username, password_hash])
    redirect '/login'
  end

  get '/users' do
    @users = db.execute("SELECT * FROM users")
    erb(:"movies/users/index")
  end

  get '/users/:id/edit' do |id|
    require_login
    @user = db.execute("SELECT * FROM users WHERE id = ?", id).first
    redirect '/acces_denied' unless session[:user_id] == @user["id"]
    erb(:"movies/users/edit")
  end

  post '/users/:id/update' do |id|
    require_login
    @user = db.execute("SELECT * FROM users WHERE id = ?", id).first
    redirect '/acces_denied' unless session[:user_id] == @user["id"]

    username = params[:username]
    new_password = params[:password]

    if new_password && !new_password.empty?
      password_hash = BCrypt::Password.create(new_password)
      db.execute("UPDATE users SET username = ?, password = ? WHERE id = ?", [username, password_hash, id])
    else
      db.execute("UPDATE users SET username = ? WHERE id = ?", [username, id])
    end

    redirect "/users"
  end

  post '/users/:id/delete' do |id|
    require_login
    @user = db.execute("SELECT * FROM users WHERE id = ?", id).first
    redirect '/acces_denied' unless session[:user_id] == @user["id"]
    db.execute("DELETE FROM users WHERE id = ?", id)
    session.clear
    redirect '/'
  end

  get '/movies/users/view' do
    require_login
    user_id = session[:user_id]
    
    # Watched movies
    @watched = db.execute("
      SELECT movies.*
      FROM movies
      JOIN user_movies ON movies.id = user_movies.movie_id
      WHERE user_movies.user_id = ?
      AND user_movies.status = 'watched'
    ", user_id)

    # Watchlist movies
    @watchlist = db.execute("
      SELECT movies.*
      FROM movies
      JOIN user_movies ON movies.id = user_movies.movie_id
      WHERE user_movies.user_id = ?
      AND user_movies.status = 'to-watch'
    ", user_id)

    erb(:"/movies/users/show")
  end

  get '/movies/new' do
    require_login
    erb(:"movies/new")
  end

  post '/movies' do
  db.execute(
    "INSERT INTO movies (name, poster, runtime, imdb) VALUES (?, ?, ?, ?)",
    [params[:name], params[:poster], params[:runtime], params[:imdb]]
  )

    redirect '/'
  end

  get '/movies/:id' do | id |
    @movie = db.execute('SELECT * FROM movies WHERE id=?', id).first
    @user_movie = db.execute("SELECT * FROM user_movies WHERE user_id = ? AND movie_id = ?", [session[:user_id], id]).first
    erb(:"movies/show")
  end

  post '/movies/:id/delete' do | id |
    db.execute("DELETE FROM movies WHERE id =?", id)
    redirect("/")
  end
 
  get '/movies/:id/edit' do | id |
    require_login
    @movie = db.execute('SELECT * FROM movies WHERE id=?',id).first
    erb(:"movies/edit")
  end

  post "/movies/:id/update" do | id |
    
    db.execute("UPDATE movies SET name=?, poster=?, runtime=?, imdb=? WHERE id=?", params.values)
    redirect("/")
  end

  get '/acces_denied' do
    erb(:"movies/acces_denied")
  end

  get '/login' do
    erb(:"login")
  end

  def log_login(username, success, ip)
    File.open("log/login.log", "a") do |f|
      status = success ? "SUCCESS" : "FAILED"
      f.puts "[#{Time.now}] #{status} | user: #{username} | ip: #{ip}"
    end
  end

  def locked_out?(ip)
    data = FAILED_ATTEMPTS[ip]
    return false unless data
    return false if data[:count] < MAX_ATTEMPTS

    seconds_since = Time.now - data[:last_attempt]
    seconds_since < COOLDOWN_SECONDS
  end

  def register_failed_attempt(ip)
    FAILED_ATTEMPTS[ip] ||= { count: 0, last_attempt: nil }
    FAILED_ATTEMPTS[ip][:count] += 1
    FAILED_ATTEMPTS[ip][:last_attempt] = Time.now
  end

  def reset_attempts(ip)
    FAILED_ATTEMPTS.delete(ip)
  end

  post '/login' do
    ip = request.ip

    if locked_out?(ip)
      log_login(params[:username], false, ip)
      halt 429, "Too many attemplts, try again after #{COOLDOWN_SECONDS} seconds."
    end

    request_username = params[:username]
    request_plain_password = params[:password]

    user = db.execute("SELECT * FROM users WHERE username = ?", request_username).first

    unless user
      register_failed_attempt(ip)
      log_login(request_username, false, ip)
      redirect '/acces_denied'
    end
    # Create a BCrypt object from the hashed password from db
    bcrypt_db_password = BCrypt::Password.new(user["password"])
    # Check if the plain password matches the hashed password from db
    if bcrypt_db_password == request_plain_password
      reset_attempts(ip)
      log_login(request_username, true, ip)
      session[:user_id] = user["id"].to_i
      redirect '/'
    else
      register_failed_attempt(ip)
      log_login(request_username, false, ip)
      redirect '/acces_denied'
    end
  end

  post '/logout' do
    ap "Logging out"
    session.clear
    redirect '/'
  end



  post '/user_movies' do
    user_id = session[:user_id]
    movie_id = params[:movie_id]
    status = params[:status]
    rating = params[:rating]

    db.execute("INSERT INTO user_movies (user_id, movie_id, status, rating) VALUES (?, ?, ?, ?)", [user_id, movie_id, status, rating])

    redirect "/movies/#{movie_id}"
  end

  post '/user_movies/:movie_id/delete' do |movie_id|
  db.execute("DELETE FROM user_movies WHERE user_id = ? AND movie_id = ?", [session[:user_id], movie_id])
  redirect "/movies/#{movie_id}"
  end

  post '/user_movies/:movie_id/update' do |movie_id|
  rating = params[:rating]
  db.execute("UPDATE user_movies SET status = 'watched', rating = ? WHERE user_id = ? AND movie_id = ?", [rating, session[:user_id], movie_id])
  redirect "/movies/#{movie_id}"
  end

end
