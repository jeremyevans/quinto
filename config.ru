require_relative 'lib/quinto/app'
run Quinto::App.freeze.app

require 'tilt/sass' unless File.exist?(File.expand_path('../compiled_assets.json', __FILE__))
Tilt.finalize!

unless ENV['RACK_ENV'] == 'development'
  begin
    require 'refrigerator'
  rescue LoadError
  else
    Refrigerator.freeze_core
  end
end
