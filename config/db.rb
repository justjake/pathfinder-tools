# Database configuration. Do any derping you need for your system here.
require 'data_mapper'

# CONFIGURE HERE
DB_PATH = File.absolute_path( File.join(File.dirname(__FILE__), 'database.sqlite') )

# DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'sqlite://' + DB_PATH)