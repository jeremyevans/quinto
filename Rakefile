require 'rake'
require "rake/clean"

CLEAN.include ["compiled_assets.json", "public/app.*.css", "public/app.*.css.gz", "public/app.*.js", "public/app.*.js.gz", "spec/unicorn.pid", "spec/unicorn.log"]

test_flags = "-w" if RUBY_VERSION >= '3'

desc 'Run ruby unit tests'
task 'unit-spec' do
  sh "#{FileUtils::RUBY} #{test_flags} spec/unit_test.rb"
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    ENV["ASSETS_PRECOMPILE"] = '1'
    require './lib/quinto/app'
    Quinto::App.compile_assets
  end
end

desc 'Run server integration tests'
task 'web-spec' do
  require 'securerandom'
  ENV['QUINTO_TEST'] = '1'
  ENV['PORT'] ||= '3001'
  ENV['QUINTO_DATABASE_URL'] ||= "postgres:///quinto_test?user=quinto"
  ENV['QUINTO_SESSION_SECRET'] ||= SecureRandom.base64(48)

  sh "psql -U quinto -f sql/clean.sql \"quinto_test\""
  pid = Process.spawn('puma', '-e', 'test', '-p', ENV['PORT'], [:out, :err]=>'spec/puma.log')
  begin
    sleep 1
    sh "#{FileUtils::RUBY} #{test_flags} spec/integration_spec.rb"
  ensure 
    Process.kill(:SIGTERM, pid)
  end
end

default_specs = %w'unit-spec'
default_specs << 'web-spec' if RUBY_VERSION > '2.7' && !ENV['NO_AJAX']
desc 'Run all specs'
task :default=>default_specs
