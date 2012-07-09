#!/usr/bin/env ruby
# Simple database to track DnD items

require 'rubygems'
require 'bundler'
require 'data_mapper'
require 'pry'
require 'terminal-table'
require 'colorize'


# CONFIGURE HERE
DB_PATH = File.absolute_path( File.join(File.dirname(__FILE__), 'items.sqlite') )

# DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'sqlite://' + DB_PATH)

# Tools for playing a Pathfinder D&D game
module Pathfinder
    # Manages item history storage
    class Item
        include DataMapper::Resource

        property    :id,            Serial
        property    :created_at,    DateTime
        property    :updated_at,    DateTime

        property    :name,          String,     :required => true
    property    :quantity_initial,  Integer,    :required => true, :default => 1
    property    :quantity_consumed, Integer,    :required => true, :default => 0
        property    :weight,        Float,      :required => true, :default => 0

        property    :price,         Float,      :default => 0
        property    :was_bought,    Boolean,    :required => true, :default => false
        property    :is_had,        Boolean,    :required => true, :default => true

        property    :notes,         Text
        property    :is_magic,      Boolean,    :default => false

        # whole-inventory poperties

        # @return [Integer] total gold you have spent over your career
        def self.spent(opts = {})
            all({:was_bought => true}.merge(opts)).reduce(0) { |sum, item| sum + item.price * item.quantity_initial }
        end

        # @return {Integer} weight of all the items in your inventory
        def self.weight(opts = {})
            all({:is_had => true}.merge(opts)).map {|i| i.weight * i.quantity }.reduce(0) { |sum, weight| sum + weight}
        end

        # Item searches

        # all items that were purchased, ever
        # @return {Array<Item>} all the items that you've ver purchased
        def self.purchased(opts = {})
            all({:was_bought => true}.merge(opts))
        end

        # return a table row with headers
        def self.table_headings
            ['ID', 'Qauntity', 'Item', 'Value/Total', 'Weight/Total', 'Status']
        end

        # Prints a table for the given collection
        def self.print_table(collection = Item.all)
            table = Terminal::Table.new({
                :headings => self.table_headings,
                :rows => collection.map{ |i| i.ui_columns }
            })
            puts table
        end

        # all items in the inventory
        def self.in_inventory(opts = {})
            all({:is_had => true}.merge(opts))
        end


        # find an item record easily
        def self.find(name, opts = {})
            all({:name.like => name, :order => [:updated_at.desc]}.merge(opts))
        end

        # Total number of gold pieces you have ever earned
        # If you sell an item in-game, 'drop' it and then add the sell
        # value to your gold.
        #
        # selling an item directly will remove it from the DB, which happens
        # to credit you with that item's inital price (if it was originally purchased)
        def self.total_gold
            g = first(:name => 'TotalGPEarned')
            g.quantity
        end

        # Set total gold you've earned
        def self.total_gold=(val)
            g = first(:name => 'TotalGPEarned')
            delta = g.quantity_initial - val
            g.quantity_consumed = delta
            g.save
            g.quantity
        end

        # Spend some gold peices for some non-item reason, adding to your total career spending
        def self.spend(number)
            s = first(:name => 'MiscGPSpending')
            s.quantity_initial += number
            s.save
            "you have spent #{s.quantity} extra in your career"
        end

        # Sets up the GP system
        def self.setup_gp(gold = 0)
            any_gp = all(:name => 'TotalGPEarned')
            if any_gp.empty?
                create({
                    :name =>   'TotalGPEarned',
                    :is_had => false,
                    :price => 0,
                    :weight => 0,
                    :quantity_initial => gold,
                    :notes => 'Total number of GP you have ever had',
                })
                create({
                    :name =>   'MiscGPSpending',
                    :is_had => false,
                    :price  => 1,
                    :quantity_initial => 0,
                    :was_bought => true,
                    :notes => 'Number of GP lost to non-buying actions',
                })
                puts "Set up GP tracking"
            else
                puts "Error: GP already set up"
            end
        end


        # Actions
        
        # Buy an item
        # Creates a new Item object and adds it to the inventory
        # as a purchased item.
        # Specify :name, :quantity, and :price
        def self.buy(opts)
            opts[:quantity_initial] = opts.delete(:quantity)
            create( {:was_bought => true}.merge(opts) )
        end


        # Instance methods

        # return an array of formatted item informationj
        def ui_columns
            text = name
            text += "\n" + notes if notes

            res = [id.to_s.blue, quantity.to_s.light_blue, text]
            if quantity > 1
                # we need to print unit weight and total weight
                value = "$#{price}\n$#{price*quantity}"
                burden = "#{weight}lbs\n#{weight*quantity}lbs"
            else
                value = "$#{price}"
                burden = "#{weight}lbs"
            end
            res << value
            res << burden
            
            status = []
            status.push('Purchased'.red) if was_bought
            status.push('Magical'.on_blue) if is_magic
            status.push('Was Dropped'.white.on_red) if ! is_had
            res << status.join("\n")
            res
        end

        # print string representation of item
        def to_s
            t = Terminal::Table.new headings: self.class.table_headings, rows: [ui_columns]
            t.to_s
        end

        # number of items remaining in a stack
        def quantity
            quantity_initial - quantity_consumed
        end

        # Set the total item quanity as though you scooped more of the item
        # off the ground
        def quantity=(q)
            delta = quantity - q
            self.quantity_consumed += delta
            save
        end

        # drop an item, discarding it from your inventory
        # if you originally bought the item, it will still count against your
        # total aquired gold
        #
        # use drop to consume items
        # @param [Integer, nil] quant how many items to consume/drop
        def drop(quant = nil)
            if quant.nil?
                self.is_had = false
                save
                "dropped #{self.quantity} #{self.name}"
            else
                self.quantity_consumed += quant
                if quantity < 0
                   raise "Cannot have negative items!"
                end
                save
                "dropped #{quant} #{name}"
            end
        end
        # Add more items to a stack you currently have
        # @param [Integer] quant quantity of items to add to the stack
        def add(quant)
            quantity_consumed -= quant
            save
            "added #{quant} #{name}"
        end

        # Analogous to "undoing" a Item::buy action
        # sell an item, removing its price from your purchases list
        # @param [Integer, nil] quant how many items to sell. If no value is given, the whole
        #    stack will be sold
        def sell(quant = nil)
            if quant.nil?
                iname, quant = name, quantity
                destroy
                "sold #{quant} #{iname}"
            else
                self.quantity_initial -= quant
                save
                "sold #{quant} #{i.name}"
            end
        end


    end

    # Helper methods for easy item manipulation from the Pry console
    module UI
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
end

# Finalize our models...
DataMapper.finalize
# And run any database upgrades needed
DataMapper.auto_upgrade!

# Container for UI instances
class CLI
    # reference to the Item database
    Items = Pathfinder::Item
    include Pathfinder::UI

    # Unknown variables try to resolve to item instances.
    # If that fails, they become strings
    def method_missing(*args, &block)
        # try to hand back an item
        try_find = Pathfinder::Item.all(:name.like => args[0])[0]
        return try_find if try_find

        # otherwise, hand back a spaced string
        args.join(' ')
    end

    def initialize
########
# The UI for this tool is Pry, a ruby console
# To find the commands and objects you can manipulate, type "ls"
# Common commands: inventory, buy, sell, drop
# For more advanced inventory derping, manipulate the Items object directly
# see http://datamapper.org/docs/ for help with DataMapper
        binding.pry
    end
end

# create the CLI
CLI.new
