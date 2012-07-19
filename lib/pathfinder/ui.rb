require 'pry'
require 'pathfinder/tabletop'

module Pathfinder
  module UI
    # mixin to add dice-rolling to ruby's basic Integer class (derp)
    module DiceRolling
      # roll a dice for `self` many times
      # @param [Integer] sides    number of faces of the dice
      # @return [Integer] the total for all rolls
      def d(sides)
        res = 0
        self.times do
          res += [*1..sides].sample
        end
        res
      end
    end

    # Helper methods for easy item manipulation from the Pry console
    module Commands
      ## first: add bare words
      ## oh wait this breaks everything
      #def method_missing(*args)
      #puts arg.class.name
      #args.join(" ")
      #end

      def show(value)
        begin
          puts value.to_s
        rescue
          puts value
        end
      end

      # Show all the items currently in your inventory
      def inventory
        Pathfinder::Item.print_table(Pathfinder::Item.in_inventory)
      end

      # show all the items you've ever bought at a store
      def purchased
        Pathfinder::Item.print_table(Pathfinder::Item.purchased)
      end

      # show all items ever
      def all
        Pathfinder::Item.print_table
      end

      # find an item in your inventory
      # @param [String] name
      # @return [DataMapper::Collection, Pathfinder::Item] a collection of results, or just your item
      def find(name)
        res = Pathfinder::Item.all(:name.like => name)
        if res.length == 0
          puts "Not found.".red
          return res
        end
        table = Terminal::Table.new({
                                        :headings => Pathfinder::Item.table_headings,
                                        :rows => res.map{ |i| i.ui_columns }
                                    })
        puts table
        if res.length == 1
          return res[0]
        end
        return res
      end

      # drop an item, discarding it from your inventory
      # if you originally bought the item, it will still count against your
      # total aquired gold
      #
      # use drop to consume items
      # @param [Integer]      id    stack of items to drop
      # @param [Integer, nil] quant how many items to consume/drop
      def drop(id, quant = nil)
        i = Pathfinder::Item.first(:id => id)
        i.drop(quant)
      end

      # Add more items to a stack you currently have
      # @param [Integer] id    id of the stack
      # @param [Integer] quant quantity of items to add to the stack
      def add(id, quant)
        Pathfinder::Item.first(:id => id).add(quant)
      end

      # sell an item, removing its price from your purchases list
      # @param [Integer] id which item id to sell
      # @param [Integer, nil] quant how many items to sell. If no value is given, the whole
      #    stack will be sold
      def sell(id, quant = nil)
        Pathfinder::Item.first(:id => id).sell(quant)
      end


      # Buy some items
      # @param [Integer] quantity   the number of items you are buying
      # @param [String]  item_name  the name of the item you are buying
      # @param [Hash]    opts       any extra information about the items you are buying\
      #   must contain   :price  [Integer]
      #   should contain :weight [Integer]
      def buy (quantity, item_name, opts = {})
        if ! opts.include? :price
          raise ArgumentError.new('items you buy must have a price (price: NUM)')
        end
        args = {:name => item_name, :quantity => quantity, :is_had => true}.merge(opts)
        item = Pathfinder::Item.buy(args)
        puts item
        item
      end

      # Add a new item to your inventory without paying for it
      # "I found it on the ground, honest!"
      # @param [Integer] quantity   the number of items you are "aquiring"
      # @param [String]  item_name  the name of the item you are getting
      # @param [Hash]    opts       any extra information about the items you are getting
      def gain (quantity, item_name, opts = {})
        if item_name.is_a? Pathfinder::Item
          item_name.add(quantity)
          return
        end

        args = {
            :name => item_name,
            :quantity_initial => quantity,
            :is_had => true,
            :was_bought => false
        }.merge(opts)
        item = Pathfinder::Item.create(args)
        puts item
        item
      end

      # How much gold you have right now.
      # (Total career gold) - (value of all purchased items + other spending)
      # @return [Integer] current gold balance
      def gold
        Pathfinder::Item.total_gold - Pathfinder::Item.spent
      end

      # Add some gold
      def earn(gold)
        g = Pathfinder::Item.first(:name => 'TotalGPEarned')
        g.add(gold)
      end

      # spend gold on non-item purchases
      # @see Pathfinder::Item#spend
      def spend(gold)
        Pathfinder::Item.spend(gold)
      end


      # @return [Integer] 1
      def one
        1
      end
    end

    # Presents a Pry-based CLI interface when an instance is created
    class CLI
      # reference to the Item database
      Items =  Pathfinder::Item
      Rolls =  Pathfinder::Roll
      Combat = Pathfinder::Tabletop::Combat

      # need those sweet, sweet UI commands
      include Pathfinder::UI::Commands

      # Unknown variables try to resolve to item instances.
      # If that fails, they become strings
      def method_missing(*args, &block)
        # try to hand back an item
        try_find = Pathfinder::Item.all(:name.like => args[0])[0]
        return try_find if try_find

        # otherwise, it really is missing (derp)
        raise NoMethodError.new("Could not find that method or an item with that name", args[0].to_s)
      end

      # start the CLI REPL
      def initialize
        c = Combat.new
        c.add("mook1", 5)
        c.add("mook2", 10)
        c.add("shalizara", 15)

        print "\e[H\e[2J"
        puts "Pathfinder Toolkit REPL".green
        puts "======================="
        puts <<-help

To find the commands and objects you can manipulate, type #{"ls".green}
For the documentation for a command, object, module, or class, use #{"show-doc".green} #{"OBJECT".red}
This REPL uses `Pry`. For a full list of built-in commands, please see http://pryrepl.org/
        help
        binding.pry(quiet: true)
      end
    end
  end
end