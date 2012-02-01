Encoding.default_internal = Encoding.default_external = 'ISO-8859-1' if RUBY_VERSION >= '1.9'
require 'capybara'
require 'capybara-webkit'
require 'capybara/dsl'
require 'capybara/rspec'
require 'headless'

Capybara.javascript_driver = :webkit
SLEEP_TIME = 0.2

RSpec.configure do |c|
  c.before do
    Capybara.default_selector = :css
    Capybara.server_port = ENV['QUINTO_PORT'].to_i
  end

  c.around do |e|
    Headless.ly(&e)
  end

  c.after do
    Capybara.reset_sessions!
  end
end

describe 'Quinto Site', :type=>:request, :js=>true do
  def home
    visit('http://127.0.0.1:3001/')
  end

  def login(email, pass)
    home
    click_link "Login"
    fill_in('email', :with=>email)
    fill_in('password', :with=>pass)
    click_button 'Login'
  end

  def login_foo
    login('foo@bar.com', 'foobar')
  end

  def login_bar
    login('bar@foo.com', 'barfoo')
  end

  def join_game(user)
    send(:"login_#{user}")
    click_link 'Join Game'
    wait
    click_button 'Join Game'
  end

  def wait
    sleep SLEEP_TIME
  end

  def click_button(*)
    super
    wait 
  end

  def click(locator)
    page.find(locator).click
  end

  it "should work as expected" do
    # Rules
    home
    page.html.should_not =~ /How to Play Quinto/
    click_link 'Rules'
    page.html.should =~ /How to Play Quinto/

    # Registering User #1
    home
    click_link "Register"
    fill_in('name', :with=>'Foo')
    fill_in('email', :with=>'foo@bar.com')
    fill_in('password', :with=>'foobar')
    click_button 'Register'
    h = page.html
    h.should =~ /Start New Game/
    h.should =~ /Join Game/
    h.should =~ /Thanks for logging in, Foo/

    # Registering User #2
    home
    click_link "Register"
    fill_in('name', :with=>'Bar')
    fill_in('email', :with=>'bar@foo.com')
    fill_in('password', :with=>'barfoo')
    click_button 'Register'
    h = page.html
    h.should =~ /Start New Game/
    h.should =~ /Join Game/
    h.should =~ /Thanks for logging in, Bar/

    # Logging in and starting new game
    login_foo
    click_link 'Start New Game'
    fill_in('emails', :with=>'bar@foo.com:[3,4,4,8,10,2,2,3,4,10,7,9,5,8,6,8,8,7,2,4,6,1,7,2,1,7,9,9,7,6,4,3,5,5,10,8,4,8,8,9,6,1,5,1,9,3,10,7,8,8,4,7,6,7,4,8,1,4,7,5,10,7,3,9,10,7,3,6,2,7,10,9,4,6,5,6,3,9,8,9,8,9,7,6,2,9,1,7,9,6]')
    click_button 'Start New Game'
    page.html.should =~ /Your Turn!/

    # Logging in and joining game
    join_game(:bar)
    page.html.should =~ /Foo's Turn/

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

    page.html.should =~ /Winners: Foo/
  end
end
