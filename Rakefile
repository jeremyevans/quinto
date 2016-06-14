desc 'Run ruby unit tests'
task 'unit-spec' do
  sh "#{FileUtils::RUBY} spec/unit_test.rb"
end

desc 'Run server integration tests'
task 'web-spec' do
  ENV['QUINTO_TEST'] = '1'
  ENV['PORT'] ||= '3001'
  ENV['DATABASE_URL'] ||= "postgres:///quinto_test?user=quinto"

  sh "psql -U quinto -f clean.sql \"quinto_test\""
  Process.spawn("#{ENV['UNICORN']||'unicorn'} -p #{ENV['PORT']} -D -c spec/unicorn.conf")
  begin
    sleep 1
    sh "#{FileUtils::RUBY} spec/integration_spec.rb"
  ensure 
    Process.kill(:SIGTERM, File.read('spec/unicorn.pid').to_i)
  end
end

desc 'Run all specs'
task 'default'=>%w'unit-spec web-spec'
