# Core library bootstrapping
dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'pathfinder/version'

# Tools for playing a Pathfinder D&D game
module Pathfinder
end

require 'pathfinder/item'
require 'pathfinder/roll'