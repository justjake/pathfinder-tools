require "data_mapper"

module Pathfinder
  # Store dice rolls
  class Roll
      include DataMapper::Resource

      property :id,           Serial
      property :total,        Integer,    required: true
      property :num_rolled,   Integer,    default: 1
      property :sides,        Integer,    default: 20
      property :created_at,   DateTime

      # roll a dice, returning the resulting integer,
      # and store the output value as a dice roll
      # @param {String} d the dice roll, a la "1d20"
      def self.roll(d)
        # unpack as numbers
        num, sides = d.split('d').map {|d| Integer(d) };

        # @todo finish this, gonna make shit work first

      end
  end
end