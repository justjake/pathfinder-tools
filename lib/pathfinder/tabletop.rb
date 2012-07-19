module Pathfinder
# Handles runtime-level play events
  module Tabletop
    # Combat. tracks initiative and who's currently derping
    class Combat
      # A combat-time actor
      class Actor < Struct.new(:name, :initiative)
        # returns a nice string telling you the actor name and initiative
        def to_s
          "Actor #{self.name} (#{self.initiative})"
        end
      end

      # all the actors in this fight
      # Array<Actor>
      attr_accessor :actors

      # Create a new combat event. You can pass a block to add actors iteratively on the command line
      # and then start the combat immediatly
      # @param [Array<Actor>] actors all the people in this combat.
      def initialize(actors = [], &block)
        self.actors =   actors
        if block_given?
          # if the block expects a paramater yield it this combat object
          # Otherwise it should be instance_eval'd
          if block.arity > 0
            yield self
          else
            instance_eval &block
          end
          start
        end
      end

      # add an actor to this combat
      # @param [String]  name actor name, eg "Shalizara"
      # @param [Integer] init initiative value of the actor, eg 4
      def add(name, init)
        self.actors << Actor.new(name, init)
      end

      # start combat. Sorts all the actors by thier initiative and then loops through thier
      # turns until you type finish
      def start
        self.actors.sort_by! {|actor| actor.initiative}.reverse!
        i = 0
        puts "Combat has begun!"
        puts 'To advance turn, type "next_turn" or "exit". To end combat, type "finish".'

        # the following uses the ruby catch/throw structure, which is pretty much just GOTO.
        # when a symbol is "throw"n, execution continues at the end of the catch block with
        # the same symbol
        # here, that features is used to escape from a nested 'pry' REPL instance.
        catch :end_combat do
          loop do
            i = 0 if i == actors.length
            current = self.actors[i]
            puts "[#{i + 1} of #{actors.length}] It is #{current.name}'s turn"
            catch :next_actor do
              binding.pry
            end
            i += 1
          end
        end
        puts "combat is over"
        nil
      end

      # end combat
      def finish
        throw :end_combat
      end

      # jump to the next turn
      def next_turn
        throw :next_actor
      end
    end
  end
end
