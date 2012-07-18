#!/usr/bin/env ruby
# Simple database to track DnD items

require 'rubygems'
require 'bundler'
require 'data_mapper'
require 'terminal-table'
require 'colorize'

# Tools for playing a Pathfinder D&D game
module Pathfinder
    # Manages item history storage
    # @TODO refactor so this isn't bloated
    # @TODO remove all the modified to_s stuff and put it in a mixin under {Pathfinder::UI}
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
end
