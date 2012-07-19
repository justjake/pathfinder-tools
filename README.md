# Pathfinder Tools

Use the supreme power of Ruby to help improve your D&D experience

## Requirements

*   Usually you should have [RVM](https://rvm.io//) if you're using Ruby
*   Then `rvm use default; gem install bundle`
*   Then `bundle install` to get all the dependencies

## Item Management

An item storage database. I like to track my total career gold income
and spending over the life of a character. Items.rb makes this easy.
It's a SQLite-backed store of all the items I've ever purchased or
otherwise obtained.


### Usage

The Items.rb UI is a ruby console. You can directly manipulate the Items
database, or use the helper methods in {Pathfinder::UI}. Please 
use the docs for detailed description of commands

The first time you run Items.rb you should do two setup commands:

    % DataMapper.auto_migrate!
    % Items.setup_gp

Then you're ready to get started with gold and item tracking

    % earn 240                  # get some starting gold
    % buy 1, "katana", price: 50, weight: 8, notes: "yeee, katanas!"
    % buy 1, "studded leather armor", price: 25, weight: 25
    % buy 25, "caltrops", price: 2, weight: 0.5

Ok, now lets see what we have in the inventory. There's a few ways to do
this...

    % inventory                                     # easy-peasy
    % Items.print_table Items.inventory             # built-in collection
    % Items.print_table(Items.all(:is_had => true)  # using DataMapper selection

If you want to undo a buy action, you'll need to sell the item. Again,
there's several ways to select items from the database. Items.rb will
try to select items instead of giving a MethodMissing error, so you can
actually just do this:

    % caltrops.sell

Although these are usually safer:

    % find('caltrops').sell
    % caltrops = Items.all(:name => 'caltrops')
    % caltrops[0].sell

If you instead consume, use, or otherwise destroy an item you purchased,
you "drop" some of the item. Let's say we used 15 caltrops...

    % find('caltrops').drop 15

Finally, gold management.

    % gold                              # gold balance. Income - spending
    % earn 15                           # earn 15 gold
    % spend 15                          # spend 15 gold on bullshit and fairies
    % Items.spent                       # value of all purchases ever made, minus those that were "sold"
    % Items.total_gold                  # value of all income ever

If you sell an item you bought in-game, *DON'T* use
{Pathfinder::Item#sell}. You should instead drop the item, and then use
{Pathfinder::UI::Commands#earn} to credit yourself with the proceeds of your sale.
This is because "selling" an item destroys its record, or, in the case
of selling partial stacks, changes the value you initially bought.

Changing this is a TODO, and may happen when I actually use this in a
D&D game.

## DM Tools

`pathfinder-tools` offers a combat order tracker for DMs, contained in
{Pathfinder::Tabletop::Combat}. Use Combat objects to keep a handle on 
who's turn it is.

### Usage

Here's a basic, iterative usage:

    % fight = Combat.new
    # Add combatants
    % fight.add('mook1', 13)
    % fight.add('mook2', 9)
    % fight.add('mook3', 11)
    % fight.add('justjake', 27)
    % fight.add('nwold', 3)
    # start combat
    % fight.start

And here's one using a more natural syntax

    % fight = Combat.new do
        add 'mook1', 13
        add 'mook2', 9
        add 'mook3', 11
        add 'justjake', 27
        add 'nwold', 3
    end
    % combat is started automatically

Once in the combat loop, you will no longer be able to access the
standard Pathfinder tools functions. Instead, you can type `exit` or
`next_turn` to advance the loop, and `finish` to exit the combat.

You can still roll dice directly from the Integer class by typing
NUMBER.d NUM2 to roll NUMBER dice with NUM2 sides.

### Planned Features

*   Not leaving behind all the Pathfinder tools functions and
    environment
