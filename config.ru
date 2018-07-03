require_relative 'lib/quinto/app'
run Quinto::App.freeze.app

begin
  require 'refrigerator'
rescue LoadError
else
  Refrigerator.freeze_core
end
