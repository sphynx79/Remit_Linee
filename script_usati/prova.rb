require 'elixirize'


def add a, b
  a + b
end
 
subtract = ->a, b{ a - b }
 
p add(4, 5).ᐅ subtract, 15
