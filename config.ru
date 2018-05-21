require_relative 'lib/quinto/app'
run Quinto::App.freeze.app

begin
  require 'refrigerator'
rescue LoadError
else
  # Don't freeze BasicObject, as tilt template compilation
  # defines and removes methods in BasicObject.
  Refrigerator.freeze_core(:except=>[(Object.superclass || Object).name])
end
