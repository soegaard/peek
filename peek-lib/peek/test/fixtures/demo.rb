#!/usr/bin/env ruby

class Greeter
  def greet(name:, loud: false)
    message = "hello #{name}"
    loud ? message.upcase : message
  end
end
