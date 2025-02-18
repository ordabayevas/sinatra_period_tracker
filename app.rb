require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"
require "yaml"
require "bcrypt"
require 'date'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  year = Date.today.year
  month = Date.today.month
  session[:date] = {year: year, month: month}
  session[:cycles] ||= {}
end

def filling_calendar(month, first_weekday, last_day)
  35.times do |num|
    month[num] = ' '
  end

  start_weekday = first_weekday % 7 # 6
  days_in_month = last_day.day # 28

  days_in_month.times do |idx|
    month[start_weekday] = idx + 1
    start_weekday += 1
  end
end

def load_user_credentials
  credentials_path = File.expand_path("../users.yml", __FILE__)

  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    if credentials[username].key?("password")
      bcrypt_password = BCrypt::Password.new(credentials[username]["password"])
      bcrypt_password == password
    else
      false
    end
  else
    false
  end
end

get "/users/signin" do
  erb :sign, layout: false
end

post "/users/signin" do
  @username = params[:username]

  if valid_credentials?(@username, params[:password])
    session[:user] = @username
    session[:message] = "Welcome!"
    session[:cycles] = load_user_credentials[@username]["cycles"]
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :sign, layout: false
  end
end

post "/users/signout" do
  session.clear
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/" do
  @year = session[:date][:year]
  @month = session[:date][:month]

  @month_name = Date::MONTHNAMES[@month]

  first_day = Date.new(@year, @month, 1)
  last_day = Date.new(@year, @month, -1)
  first_wday = first_day.wday
  @display_month = []

  if @month == 1
    @prev_year = @year - 1
    @prev_month = 12
    @next_year = @year
    @next_month = @month + 1
  elsif @month == 12
    @prev_year = @year
    @prev_month = @month - 1
    @next_year = @year + 1
    @next_month = 1
  else
    @prev_year = @year
    @prev_month = @month - 1
    @next_year = @year
    @next_month = @month + 1
  end

  filling_calendar(@display_month, first_wday, last_day)

  erb :index
end

get "/:year/:month" do
  @year = params[:year].to_i
  @month = params[:month].to_i

  @month_name = Date::MONTHNAMES[@month]

  first_day = Date.new(@year, @month, 1)
  last_day = Date.new(@year, @month, -1)
  first_wday = first_day.wday

  if @month == 1
    @prev_year = @year - 1
    @prev_month = 12
    @next_year = @year
    @next_month = @month + 1
  elsif @month == 12
    @prev_year = @year
    @prev_month = @month - 1
    @next_year = @year + 1
    @next_month = 1
  else
    @prev_year = @year
    @prev_month = @month - 1
    @next_year = @year
    @next_month = @month + 1
  end

  @display_month = []

  filling_calendar(@display_month, first_wday, last_day)

  erb :index
end

post "/submit" do
  if params[:period].nil? || params[:period].empty?
    session[:message] = "No dates selected. Please select at least one."
    redirect "/"
  end

  selected_days = params[:period] || []

  session[:cycles] ||= {}

  year, month, day = selected_days[0].split('-')
  year_month = "#{year}-#{month}"
  
  if session[:cycles].key?(year_month)
    session[:cycles][year_month] = {}
  end

  selected_days.each do |date|
    session[:cycles][year_month] ||= {} 
    session[:cycles][year_month][date] = nil
    d = load_user_credentials #Load
    #p load_user_credentials # {"user1" => {"password" => "$2a$12$WOXaTUBYlfGXVDQDSLP.deV/oSaU2ujLrBqjiHAIn68VAqDxv7ckC"},
    #p session[:user] # user2
    p session[:cycles] #{2025-02 => {}}
    d[session[:user]]["cycles"] = session[:cycles] #Modify
    credentials_path = File.expand_path("../users.yml", __FILE__)
    File.open(credentials_path, 'w') {|f| f.write d.to_yaml } #Store
    puts d
  end

  puts session[:cycles] # {"2025-2" => {"2025-2-11" => nil, "2025-2-12" => nil, "2025-2-13" => nil}}

  session[:message] = "Period logged successfully"
  redirect "/"
end
