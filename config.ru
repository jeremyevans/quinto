require_relative 'lib/quinto/app'
run Quinto::App.freeze.app

unless ENV['RACK_ENV'] == 'development'
  begin
    require 'refrigerator'
  rescue LoadError
  else
    Refrigerator.freeze_core(:except=>['BasicObject'])
  end
end
