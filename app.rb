require 'debug'
require 'sinatra'
require 'securerandom'
require 'bcrypt'

class App < Sinatra::Base
  
  def db
    return @db if @db

    @db = SQLite3::Database.new("db/sqlite.db")
    @db.results_as_hash = true

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

  get '/movies' do
    @movies = db.execute('SELECT * FROM movies')
    p @movies
    p @current_user
    erb(:"movies/index")
  end


  get '/movies/new' do
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
    @movie = db.execute('SELECT * FROM movies WHERE id=?',id).first
    erb(:"movies/show")

    # är lite fuckad
    #  @user_movie = db.execute(
    #"SELECT * FROM user_movies WHERE user_id = ? AND movie_id = ?",
    #[session[:user_id], id]
).first
  end

  post '/movies/:id/delete' do | id |
    db.execute("DELETE FROM movies WHERE id =?", id)
    redirect("/")
  end
 
  get '/movies/:id/edit' do | id |
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

  post '/login' do
    request_username = params[:username]
    request_plain_password = params[:password]

    user = db.execute("SELECT *
            FROM users
            WHERE username = ?",
            request_username).first

    unless user
      ap "/login : Invalid username."
      status 401
      redirect '/acces_denied'
    end

    db_id = user["id"].to_i
    db_password_hashed = user["password"].to_s

    # Create a BCrypt object from the hashed password from db
    bcrypt_db_password = BCrypt::Password.new(db_password_hashed)
    # Check if the plain password matches the hashed password from db
    if bcrypt_db_password == request_plain_password
      ap "/login : Logged in -> redirecting to user front page"
      session[:user_id] = db_id
      redirect '/'
    else
      ap "/login : Invalid password."
      status 401
      redirect '/acces_denied'
    end
  end

  post '/logout' do
    ap "Logging out"
    session.clear
    redirect '/'
  end

  get '/users/new' do
    erb(:"movies/users/new")
  end

  post '/users' do
    username = params[:username]
    password = params[:password]
    password_hash = BCrypt::Password.create(password)
    stored_password = BCrypt::Password.new(user["password"])
    db.execute("INSERT INTO users (username, password) VALUES (?, ?)", [username, password_hash])
    redirect '/login'
    unless stored_password == request_plain_password
      redirect '/acces_denied'
    end
  end



  post '/user_movies' do
    user_id = session[:user_id]
    movie_id = params[:movie_id]
    status = params[:status]
    rating = params[:rating]

    db.execute("INSERT INTO user_movies (user_id, movie_id, status, rating) VALUES (?, ?, ?, ?)", [user_id, movie_id, status, rating])

    redirect "/movies/#{movie_id}"
  end

  get '/movies/users/view' do
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

    erb :"/movies/users/show"
  end

end


# kolla line 62