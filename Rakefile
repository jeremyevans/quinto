desc 'Run ruby unit tests'
task 'unit-spec' do
  sh "#{FileUtils::RUBY} spec/unit_test.rb"
end

desc 'Run server integration tests'
task 'web-spec' do
  require 'securerandom'
  ENV['QUINTO_TEST'] = '1'
  ENV['PORT'] ||= '3001'
  ENV['QUINTO_DATABASE_URL'] ||= "postgres:///quinto_test?user=quinto"
  ENV['QUINTO_SESSION_SECRET'] ||= SecureRandom.base64(48)

  sh "psql -U quinto -f sql/clean.sql \"quinto_test\""
  Process.spawn("#{ENV['UNICORN']||'unicorn'} -E test -p #{ENV['PORT']} -D -c spec/unicorn.conf")
  begin
    sleep 1
    sh "#{FileUtils::RUBY} spec/integration_spec.rb"
  ensure 
    Process.kill(:SIGTERM, File.read('spec/unicorn.pid').to_i)
  end
end

default_specs = %w'unit-spec'
default_specs << 'web-spec' if RUBY_VERSION > '2.3'
desc 'Run all specs'
task :default=>default_specs
