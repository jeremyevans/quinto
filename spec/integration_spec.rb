Encoding.default_internal = Encoding.default_external = 'ISO-8859-1' if RUBY_VERSION >= '1.9'
require_relative 'warnings_helper'
require 'capybara'
require 'capybara/dsl'

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/hooks/default'
require 'minitest/global_expectations/autorun'

case ENV['CAPYBARA_DRIVER']
when 'chrome'
  puts "testing using chrome"
  require 'selenium-webdriver'
  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new app, browser: :chrome, options: Selenium::WebDriver::Chrome::Options.new(args: %w[headless disable-gpu])
  end

  Capybara.current_driver = :chrome
when 'firefox'
  puts "testing using firefox"
  require 'selenium-webdriver'
  Capybara.register_driver :firefox do |app|
    browser_options = Selenium::WebDriver::Firefox::Options.new
    browser_options.args << '--headless'
    Capybara::Selenium::Driver.new(app, browser: :firefox, marionette: true, options: browser_options)
  end
  Capybara.current_driver = :firefox
else
  puts "testing using capybara-webkit"
  require 'capybara-webkit'
  require 'headless'
  use_headless = true
  Capybara.current_driver = :webkit
  Capybara::Webkit.configure do |config|
    config.block_unknown_urls
  end
end
Capybara.default_selector = :css
Capybara.server_port = ENV['PORT'].to_i

describe 'Quinto Site' do
  include Capybara::DSL

  if use_headless
    around do |&block|
      Headless.ly{super(&block)}
    end
  end

  after do
    Capybara.reset_sessions!
  end

  def login(email, pass)
    page.html.include?('Logout') ? click_button('Logout') : click_link('Login')
    fill_in('Login', :with=>email)
    fill_in('Password', :with=>pass)
    click_button 'Login'
    page.html.must_match /You have been logged in/
  end

  def login_foo
    login('foo@bar.com', 'foobar')
  end

  def login_bar
    login('bar@foo.com', 'barfoo')
  end

  def join_game(user)
    send(:"login_#{user}")
    click_button 'Join Game'
  end

  def wait
    print '.'
    begin
      while page.evaluate_script("$('#spinner h2').css('display') == 'inline-block'") do
        sleep 0.1
      end
    rescue
      # $ may not be defined on the page, and some drivers raise an error for that
      nil
    end
    sleep 0.3
  end

  def click_button(*)
    super
    wait
  end

  def click(locator)
    page.find(locator).click
  end

  it "should work as expected" do
    visit("http://127.0.0.1:#{ENV['PORT']}/")
    page.html.must_match /How to Play Quinto/

    # Registering User #1
    click_link "Create Account"
    fill_in('Login', :with=>'foo@bar.com')
    fill_in('Confirm Login', :with=>'foo@bar.com')
    fill_in('Password', :with=>'foobar')
    fill_in('Confirm Password', :with=>'foobar')
    click_button 'Create Account'
    h = page.html
    h.must_match /Start New Game/
    h.wont_match /Join Game/
    h.must_match /Your account has been created/

    # Registering User #2
    click_button 'Logout' 
    click_link "Create Account"
    fill_in('Login', :with=>'bar@foo.com')
    fill_in('Confirm Login', :with=>'bar@foo.com')
    fill_in('Password', :with=>'barfoo')
    fill_in('Confirm Password', :with=>'barfoo')
    click_button 'Create Account'
    h = page.html
    h.must_match /Start New Game/
    h.wont_match /Join Game/
    h.must_match /Your account has been created/

    # Test starting game with same email fails
    fill_in('emails', :with=>'bar@foo.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.must_match /cannot have same player in two separate positions/

    # Test starting game right after registering
    visit('http://127.0.0.1:3001/')
    login_bar
    fill_in('emails', :with=>'foo@bar.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.must_match /Pass/

    # Test passing
    click_button 'Pass'
    page.html.wont_match /Pass/

    # Test leaving and reentering game
    click_link 'Quinto'
    page.html =~ /(\d+) - foo@bar.com/
    game_id = $1.to_i
    click_button 'Join Game'
    page.html.wont_match /Pass/

    # Test dragging and dropping tiles
    join_game(:foo)
    #page.find_by_id('rack4').drag_to(page.find_by_id('i8'))
    click("#i8")
    click("#rack4")
    page.find('#i8').text.must_equal '10'
    click_button 'Commit Move'

    # Test dragging and dropping same rack tile twice
    # removes previous place
    join_game(:bar)
    #page.find_by_id('rack4').drag_to(page.find_by_id('j8'))
    click("#j8")
    click("#rack4")
    page.find('#h8').text.must_equal ''
    page.find('#j8').text.must_equal '10'
    #page.find_by_id('rack4').drag_to(page.find_by_id('h8'))
    click("#h8")
    click("#rack4")
    page.find('#h8').text.must_equal '10'
    page.find('#j8').text.must_equal ''

    # Test dragging and dropping different rack tile to same
    # board tile removes previous place
    join_game(:bar)
    #page.find_by_id('rack4').drag_to(page.find_by_id('j8'))
    click("#j8")
    click("#rack4")
    page.find('#j8').text.must_equal '10'
    #page.find_by_id('rack3').drag_to(page.find_by_id('j8'))
    click("#j8")
    click("#rack3")
    page.find('#j8').text.must_equal '8'
    #page.find_by_id('rack4').drag_to(page.find_by_id('h8'))
    click("#h8")
    click("#rack4")
    page.find('#h8').text.must_equal '10'
    page.find('#j8').text.must_equal '8'

    # Test nothing happens if you drop rack tile over
    # previously played tile
    join_game(:bar)
    #page.find_by_id('rack3').drag_to(page.find_by_id('i8'))
    click("#rack3")
    click("#i8")
    page.find('#i8').text.must_equal '10'

    # Test clicking on board then rack
    join_game(:bar)
    click("#i7")
    click("#rack0")
    page.find('#i7').text.must_equal '3'
    
    # Test clicking on rack and then on board
    click("#rack1")
    click("#i6")
    page.find('#i6').text.must_equal '4'

    # Test error message when current move invalid
    page.html.must_match /consecutive tiles do not sum to multiple of 5/i

    # Test error message removed when current move valid
    click("#rack3")
    click("#i5")
    page.find('#i5').text.must_equal '8'
    page.html.wont_match /consecutive tiles do not sum to multiple of 5/i
    page.html.must_match /Move Score: 25/
    page.html.must_match /i5-8:.+25/
    
    # Test clicking on existing board tile and then rack tile removes
    # existing rack tile and uses new rack tile
    click("#i5")
    page.find('#i5').text.must_equal ''
    click("#rack2")
    page.find('#i5').text.must_equal '4'

    # Test clicking on existing board tile twice just removes board tile 
    click("#i5")
    click("#i5")
    page.find('#i5').text.must_equal ''
    click("#rack2")
    page.find('#i5').text.must_equal ''
    click("#i5")
    page.find('#i5').text.must_equal '4'

    # Test clicking on existing rack tile and then board tile moves rack
    # tile to new board place
    click("#rack2")
    page.find('#i5').text.must_equal ''
    click("#i4")
    page.find('#i4').text.must_equal '4'
    
    # Test clicking on existing rack tile twice just removes rack tile
    click("#rack2")
    click("#rack2")
    page.find('#i5').text.must_equal ''
    click("#i4")
    page.find('#i4').text.must_equal ''
    click("#rack2")
    page.find('#i4').text.must_equal '4'

    # Test clicking on one board tile then another just removes the tiles
    click("#i4")
    page.find('#i4').text.must_equal ''
    click("#i5")
    page.find('#i5').text.must_equal ''
    click("#i6")
    page.find('#i6').text.must_equal ''
    click("#i7")
    page.find('#i7').text.must_equal ''
    click("#rack0")
    page.find('#i7').text.must_equal '3'

    click("#rack1")
    click("#i6")
    page.find('#i6').text.must_equal '4'
    click("#rack2")
    click("#i5")
    page.find('#i5').text.must_equal '4'

    # Test clicking on one played rack tile then another just removes
    # the tiles
    click("#rack2")
    page.find('#i5').text.must_equal ''
    click("#rack1")
    page.find('#i6').text.must_equal ''
    click("#rack0")
    page.find('#i7').text.must_equal ''
    click("#i6")
    page.find('#i6').text.must_equal '3'

    ## Play a full game without errors

    # Logging in and starting new game
    login_foo
    fill_in('emails', :with=>'bar@foo.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.must_match /Pass/

    # Logging in and joining game
    join_game(:bar)
    page.html.wont_match /Pass/

    # Make moves
    join_game(:foo)
    click('#h8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#i8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#j8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#k10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#k9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#k8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#l6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#l9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#l7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click('#l8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#i10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#h10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#j10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#l10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#h9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#g9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#n9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#m9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#m4')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#m7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#m6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#m5')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#e9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#i9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#f9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#n5')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#n4')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#n3')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#n2')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#k6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click('#k7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#a10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#b10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#c10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#d10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#e10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#d11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#e11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click('#f11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click('#g11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#h11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#o7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#o8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#o9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#n8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#p8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#o1')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#o2')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#p6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#p5')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#p7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#q3')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#q6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#q5')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#q4')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#q1')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#p1')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#n1')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#j12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#k12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#i12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click('#h12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#l13')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#l12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click('#l14')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#k13')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#m13')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#o14')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#k14')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(5)').attr('id')")}")
    click('#n14')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#m14')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#q10')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(3)').attr('id')")}")
    click('#q9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click('#q8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(10)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#q15')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(4)').attr('id')")}")
    click('#p15')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#o15')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click('#n15')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#a12')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#a11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#a9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#b9')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(1)').attr('id')")}")
    click('#b8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(8)').attr('id')")}")
    click('#b11')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(9)').attr('id')")}")
    click_button('Commit Move')
  
    join_game(:foo)
    click('#c6')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#c7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(6)').attr('id')")}")
    click('#c8')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#e7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(2)').attr('id')")}")
    click('#d7')
    click("##{page.evaluate_script("$('.rack_tile:not(.move):contains(7)').attr('id')")}")
    click_button('Commit Move')

    page.html.must_match /Winners: foo@bar.com/

    click_link 'Quinto'
    page.html.must_match /#{game_id} - foo@bar.com/
    page.html.must_match /#{game_id+1} - foo@bar.com/
    page.html.wont_match /#{game_id+2} - foo@bar.com/
  end
end
