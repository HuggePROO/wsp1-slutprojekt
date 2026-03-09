require 'sqlite3'
require_relative '../config'
require 'bcrypt'

class Seeder

  def self.seed!
    puts "Using db file: #{DB_PATH}"
    puts "🧹 Dropping old tables..."
    drop_tables
    puts "🧱 Creating tables..."
    create_tables
    puts "🍎 Populating tables..."
    populate_tables
    puts "✅ Done seeding the database!"
  end

  def self.drop_tables
    db.execute('DROP TABLE IF EXISTS saves')
    db.execute('DROP TABLE IF EXISTS users')
    db.execute('DROP TABLE IF EXISTS movies')
  end

  def self.create_tables
    db.execute('CREATE TABLE movies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      poster TEXT NOT NULL,
      runtime TEXT NOT NULL,
      imdb TEXT NOT NULL
    )')

    db.execute('CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      password TEXT NOT NULL
    )')

    db.execute('CREATE TABLE saves (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      movie_id INTEGER,
      status TEXT NOT NULL,
      rating INTEGER,
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (movie_id) REFERENCES movies(id)
    )')
  end

  def self.populate_tables
  # Hash the password and convert to string explicitly
  password_hashed = BCrypt::Password.create("123").to_s
  puts "Storing hashed password (#{password_hashed}) to DB. Clear text password (123) never saved."

  # Insert the user
  db.execute('INSERT INTO users (username, password) VALUES (?, ?)', ["hugo", password_hashed])

  # Prepare movies to insert
  movies = [
    ["Star Wars Revenge of the Sith", "https://storage.googleapis.com/pod_public/1300/266305.jpg", "2h 20m", "8,8"],
    ["The Lord of the Rings: The Return of the King", "https://static.posters.cz/image/1300/133052.jpg", "3h 21m", "9,0"],
    ["Inception", "https://m.media-amazon.com/images/I/91b3Xtjt0IL._AC_UF1000,1000_QL80_.jpg", "2h 28m", "8,8"],
    ["The Matrix", "https://m.media-amazon.com/images/I/51EG732BV3L._AC_.jpg", "2h 16m", "8,7"],
    ["Interstellar", "https://m.media-amazon.com/images/I/61ASebTsLpL._AC_UF894,1000_QL80_.jpg", "2h 49m", "8,6"],
    ["Avatar", "https://i.pinimg.com/736x/8b/2f/a6/8b2fa6fb94810cd0d335b479896f7fc8.jpg", "2h 42m", "7,9"],
    ["Guardians of the Galaxy", "https://m.media-amazon.com/images/I/81YZ8slCyuL.jpg", "2h 1m", "8,0"],
    ["Mad Max: Fury Road", "https://m.media-amazon.com/images/I/71rs1WWtoBL._AC_UF1000,1000_QL80_.jpg", "2h 0m", "8,1"],
    ["Dune: Part One", "https://i0.wp.com/schicksalgemeinschaft.wordpress.com/wp-content/uploads/2021/09/dune-part-one-poster.jpg?fit=810%2C1200&ssl=1", "2h 35m", "8,0"],
    ["Pirates of the Caribbean: The Curse of the Black Pearl", "https://m.media-amazon.com/images/I/71zji3aER6L.jpg", "2h 23m", "8,1"]
  ]

  # Insert movies safely
  movies.each do |name, poster, runtime, imdb|
    db.execute('INSERT INTO movies (name, poster, runtime, imdb) VALUES (?, ?, ?, ?)', [name, poster, runtime, imdb])
  end

  puts "Movies and user successfully populated!"
end

  private

  def self.db
    @db ||= begin
      db = SQLite3::Database.new(DB_PATH)
      db.results_as_hash = true
      db
    end
  end

end

Seeder.seed!