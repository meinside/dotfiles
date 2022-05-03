# frozen_string_literal: true

# My .irbrc file
#
# meinside@duck.com
#
# last update: 2022.05.03.

# $ gem install solargraph

# turn on auto completion
require 'irb/completion'

# turn on auto indent
IRB.conf[:AUTO_INDENT] = true

# definitions of irb helper functions
def clear
  system 'clear'
end

# monkey-patch for `Object`
class Object
  def own_methods(omit_superclass_methods: true)
    if omit_superclass_methods
      (methods - self.class.superclass.instance_methods).sort
    else
      (methods - Object.instance_methods).sort
    end
  end

  def ri(obj = self)
    puts `ri '#{if obj.is_a?(String)
                  obj
                else
                  (obj.instance_of?(Class) ? obj : obj.class)
                end}'`
  end
end

# for loading gems installed from git with bundler
require 'bundler/setup'
