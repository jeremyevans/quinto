# frozen_string_literal: true
require 'capybara'
require 'capybara/dsl'
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [1200, 800], xvfb: true)
end
Capybara.current_driver = :cuprite
Capybara.default_selector = :css
Capybara.server_port = ENV['PORT'].to_i
Capybara.exact = true

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/hooks/default'
require 'minitest/global_expectations/autorun'

describe 'Quinto Site' do
  include Capybara::DSL

  after do
#p page.driver.browser.error_messages
    Capybara.reset_sessions!
  end

  def login(email, pass)
    page.html.include?('Logout') ? click_button('Logout') : click_link('Login')
    fill_in('Login', :with=>email)
    fill_in('Password', :with=>pass)
    click_button 'Login'
    page.html.must_include 'You have been logged in'
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
    page.html.must_include 'How to Play Quinto'

    # Registering User #1
    click_link "Create Account"
    fill_in('Login', :with=>'foo@bar.com')
    fill_in('Confirm Login', :with=>'foo@bar.com')
    fill_in('Password', :with=>'foobar')
    fill_in('Confirm Password', :with=>'foobar')
    click_button 'Create Account'
    h = page.html
    h.must_include 'Start New Game'
    h.wont_include 'Join Game'
    h.must_include 'Your account has been created'

    # Registering User #2
    click_button 'Logout' 
    click_link "Create Account"
    fill_in('Login', :with=>'bar@foo.com')
    fill_in('Confirm Login', :with=>'bar@foo.com')
    fill_in('Password', :with=>'barfoo')
    fill_in('Confirm Password', :with=>'barfoo')
    click_button 'Create Account'
    h = page.html
    h.must_include 'Start New Game'
    h.wont_include 'Join Game'
    h.must_include 'Your account has been created'

    # Test starting game with same email fails
    fill_in('emails', :with=>'bar@foo.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.must_include 'cannot have same player in two separate positions'

    # Test starting game right after registering
    visit('http://127.0.0.1:3001/')
    login_bar
    fill_in('emails', :with=>'foo@bar.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.must_include 'Pass'

    # Test passing
    click_button 'Pass'
    page.html.wont_include 'Pass'

    # Test leaving and reentering game
    click_link 'Quinto'
    page.html =~ /(\d+) - foo@bar.com/
    game_id = $1.to_i
    click_button 'Join Game'
    page.html.wont_include 'Pass'

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
    page.html.must_match(/consecutive tiles do not sum to multiple of 5/i)

    # Test error message removed when current move valid
    click("#rack3")
    click("#i5")
    page.find('#i5').text.must_equal '8'
    page.html.wont_match(/consecutive tiles do not sum to multiple of 5/i)
    page.html.must_include 'Move Score: 25'
    page.html.must_match(/i5-8:.+25/)
    
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
    page.html.must_include 'Pass'

    # Logging in and joining game
    join_game(:bar)
    page.html.wont_include 'Pass'

    # Make moves
    join_game(:foo)
    click('#h8')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#i8')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#j8')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#k10')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#k9')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#k8')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#l6')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#l9')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#l7')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click('#l8')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#i10')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#h10')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#j10')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#l10')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#h9')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#g9')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#n9')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#m9')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#m4')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#m7')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#m6')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#m5')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#e9')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#i9')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#f9')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#n5')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#n4')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#n3')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#n2')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#k6')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click('#k7')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#a10')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#b10')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#c10')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#d10')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#e10')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#d11')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#e11')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click('#f11')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click('#g11')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#h11')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#o7')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#o8')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#o9')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#n8')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#p8')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#o1')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#o2')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#p6')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#p5')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#p7')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#q3')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#q6')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#q5')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#q4')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#q1')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#p1')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#n1')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#j12')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#k12')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#i12')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click('#h12')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#l13')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#l12')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click('#l14')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#k13')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#m13')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#o14')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#k14')
    click("##{page.evaluate_script("rack_tile_id(5)")}")
    click('#n14')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#m14')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#q10')
    click("##{page.evaluate_script("rack_tile_id(3)")}")
    click('#q9')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click('#q8')
    click("##{page.evaluate_script("rack_tile_id(10)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#q15')
    click("##{page.evaluate_script("rack_tile_id(4)")}")
    click('#p15')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#o15')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click('#n15')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:foo)
    click('#a12')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#a11')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#a9')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#b9')
    click("##{page.evaluate_script("rack_tile_id(1)")}")
    click('#b8')
    click("##{page.evaluate_script("rack_tile_id(8)")}")
    click('#b11')
    click("##{page.evaluate_script("rack_tile_id(9)")}")
    click_button('Commit Move')
  
    join_game(:foo)
    click('#c6')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#c7')
    click("##{page.evaluate_script("rack_tile_id(6)")}")
    click('#c8')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    join_game(:bar)
    click('#e7')
    click("##{page.evaluate_script("rack_tile_id(2)")}")
    click('#d7')
    click("##{page.evaluate_script("rack_tile_id(7)")}")
    click_button('Commit Move')

    page.html.must_include 'Winners: foo@bar.com'

    click_link 'Quinto'
    page.html.must_match(/#{game_id} - foo@bar.com/)
    page.html.must_match(/#{game_id+1} - foo@bar.com/)
    page.html.wont_match(/#{game_id+2} - foo@bar.com/)
  end
end
