require 'minitest/spec'
require 'minitest/autorun'

$: << 'lib'
require 'quinto/game'

include Quinto

describe TilePlace do
  it "#tile_position should use correct DAD format" do
    TilePlace.new(1,0,0).tile_position.must_equal '1a0'
    TilePlace.new(1,0,1).tile_position.must_equal '1a1'
    TilePlace.new(3,1,2).tile_position.must_equal '3b2'
    TilePlace.new(10,12,15).tile_position.must_equal '10m15'
  end
end

describe Player do
  it 'should have a working constructor' do
    p = Player.new(1, 'bar@baz.com')
    p.id.must_equal 1
    p.email.must_equal 'bar@baz.com'
  end
end

describe Game do
  it 'should require at least 2 players' do
    proc{Game.new(1, [])}.must_raise Quinto::Error
    proc{Game.new(1, [Player.new('bar2@baz.com', 'blah2')])}.must_raise Quinto::Error
  end
end

describe GameState do
  before do
    @g = Game.new(1, [Player.new('bar@baz.com', 'blah'), Player.new('bar2@baz.com', 'blah2')])
    @s = @g.state
  end

  it 'should have an initial state' do
    @s.tiles.length.must_equal 80
    @s.racks.length.must_equal 2
    @s.racks.each do |r|
      r.length.must_equal 5
    end
  end

  it 'should allow passing' do
    @s.to_move.must_equal 0
    @g.pass
    s = @g.state
    s.to_move.must_equal 1
    s.scores.must_equal [0, 0]
  end

  it 'should allow moving' do
    @s.to_move.must_equal 0
    @s.racks[0][1] = 5
    @g.move("5i8")
    s = @g.state
    s.to_move.must_equal 1
    s.scores.must_equal [5, 0]
  end

  it "#parse_move should split move into tile places" do
    @s.send(:parse_move, "1a0").must_equal [TilePlace.new(1,0,0)]
    @s.send(:parse_move, "1a1").must_equal [TilePlace.new(1,0,1)]
    @s.send(:parse_move, "3b2").must_equal [TilePlace.new(3,1,2)]
    @s.send(:parse_move, "10m15").must_equal [TilePlace.new(10,12,15)]
    @s.send(:parse_move, "10m15 3m5 2m6 1a1 1a2").must_equal [TilePlace.new(10,12,15), TilePlace.new(3,12,5), TilePlace.new(2,12,6), TilePlace.new(1,0,1), TilePlace.new(1,0,2)]
  end
end

describe GameState do
  before do
    @s = Game.new(1, [Player.new(1, 'bar@baz.com'), Player.new(2, 'bar2@baz.com')]).state
    @s.racks = [[5, 6, 4, 3, 7], [5, 8, 2, 9, 1]]
  end

  it 'should have a reasonable initial state' do
    @s.tiles.length.must_equal 80
    @s.racks.length.must_equal 2
    @s.racks.each do |r|
      r.length.must_equal 5
    end
    @s.game.players[0].email.must_equal 'bar@baz.com'
    @s.board.must_equal({})
    @s.scores.must_equal [0, 0]
    @s.last_move.must_equal nil
    #@s.last_runs.must_equal nil
    @s.pass_count.must_equal 0
    @s.move_count.must_equal 0
    @s.game_over.must_equal false
  end

  it 'should have a reasonable state after passing' do
    s = @s.pass
    s.tiles.length.must_equal 80
    s.racks.length.must_equal 2
    @s.racks.each do |r|
      r.length.must_equal 5
    end
    s.game.players[0].email.must_equal 'bar@baz.com'
    s.board.must_equal({})
    s.scores.must_equal [0, 0]
    s.last_move.must_equal nil
    #s.last_runs.must_equal nil
    s.pass_count.must_equal 1
    s.move_count.must_equal 1
    s.game_over.must_equal false
  end

  it 'should have a reasonable state after moving' do
    s = @s.move('5i8')
    s.tiles.length.must_equal 79
    s.racks.length.must_equal 2
    @s.racks.each do |r|
      r.length.must_equal 5
    end
    s.game.players[0].email.must_equal 'bar@baz.com'
    s.board.must_equal("i8"=> 5)
    s.scores.must_equal [5, 0]
    s.last_move.must_equal '5i8'
    #s.last_runs.must_equal("i8"=> 5)
    s.pass_count.must_equal 0
    s.move_count.must_equal 1
    s.game_over.must_equal false
  end

  it 'should be over if all players pass' do
    @s.pass.pass.game_over.must_equal true
  end

  it 'should be over if all tiles are played and a rack is empty' do
    @s.tiles = []
    s = @s.move('6i8 5i7 4i6 3i5 7i4')
    s.game_over.must_equal true
    s.scores.must_equal [25, -25]
  end

  it 'should report winners correctly' do
    @s.pass.pass.winners.must_equal ['bar@baz.com', 'bar2@baz.com']
    @s.racks[0] = [5]
    @s.tiles = []
    @s.move('5i8').winners.must_equal ['bar@baz.com']
  end

  it 'should report if the board is empty' do
    @s.empty?.must_equal true
    @s.pass.empty?.must_equal true
    @s.move('5i8').empty?.must_equal false
  end

  it 'should throw error if first move not in center' do
    proc{@s.move('5i7')}.must_raise Quinto::Error
  end

  it 'should throw error if tile played not adjacent to existing tile' do
    proc{@s.move('5i7 6i9 4i10')}.must_raise Quinto::Error
    s = @s.move('5i8 6i9 4i10')
    proc{s.move('5i5')}.must_raise Quinto::Error
  end

  it 'should throw error if sum of any run does not equal multiple of 5' do
    proc{@s.move('5i8 6i9')}.must_raise Quinto::Error
    s = @s.move('5i8 6i9 4i10')
    proc{s.move('5j10')}.must_raise Quinto::Error
  end

  it 'should throw error if more than 5 tiles in a row' do
    s = @s.move('5i8 6i9 4i10 7i11 3i12')
    proc{s.move('5i13')}.must_raise Quinto::Error
  end

  it 'should throw error if tile played not in rack' do
    proc{@s.move('10i8')}.must_raise Quinto::Error
  end

  it 'should throw error if tile played outside of board' do
    proc{@s.move('5i20')}.must_raise Quinto::Error
    s = @s.move('5i8').dup
    s.board = {i16: 5}
    proc{s.move('5i17')}.must_raise Quinto::Error
  end

  it 'should throw error if tiles not in single row or column' do
    proc{@s.move('5i8 6i9 4j9')}.must_raise Quinto::Error
    proc{@s.move('5i8 6j8 4j9')}.must_raise Quinto::Error
  end

  it 'should throw error if tile played over existing tile' do
    s = @s.move('5i8')
    proc{s.move('5i8')}.must_raise Quinto::Error
  end

  it 'should calculate runs correctly' do
    s = @s.move('5i8 6i9 7i10 4i11 3i12')
    s.scores.must_equal [25, 0]
    s.move('5j8 9j9 8j10 2j7 1j6').scores.must_equal [25, 65]
  end

  it 'should handle a few games correctly' do
    s = @s
    s.tiles = [7, 9, 5, 8, 6, 8, 8, 7, 2, 4, 6, 1, 7, 2, 1, 7, 9, 9, 7, 6, 4, 3, 5, 5, 10, 8, 4, 8, 8, 9, 6, 1, 5, 1, 9, 3, 10, 7, 8, 8, 4, 7, 6, 7, 4, 8, 1, 4, 7, 5, 10, 7, 3, 9, 10, 7, 3, 6, 2, 7, 10, 9, 4, 6, 5, 6, 3, 9, 8, 9, 8, 9, 7, 6, 2, 9, 1, 7, 9, 6]
    s.racks = [[3, 4, 4, 8, 10], [2, 2, 3, 4, 10]]
    s = s.move("3h8 4i8 8j8")
    s.scores.must_equal [15, 0]
    s.game_over.must_equal false
    s = s.move("2k10 3k9 10k8")
    s.scores.must_equal [15, 40]
    s.game_over.must_equal false
    s = s.move("4l6 7l9 9l7 10l8")
    s.scores.must_equal [90, 40]
    s.game_over.must_equal false
    s = s.move("2i10 8h10 8j10")
    s.scores.must_equal [90, 60]
    s.game_over.must_equal false
    s = s.move("5l10")
    s.scores.must_equal [150, 60]
    s.game_over.must_equal false
    s = s.move("4h9 6g9")
    s.scores.must_equal [150, 85]
    s.game_over.must_equal false
    s = s.move("7n9 8m9")
    s.scores.must_equal [175, 85]
    s.game_over.must_equal false
    s = s.move("1m4 1m7 6m6 7m5")
    s.scores.must_equal [175, 120]
    s.game_over.must_equal false
    s = s.move("2e9 4i9 9f9")
    s.scores.must_equal [210, 120]
    s.game_over.must_equal false
    s = s.move("3n5 4n4 6n3 7n2")
    s.scores.must_equal [210, 155]
    s.game_over.must_equal false
    s = s.move("5k6 10k7")
    s.scores.must_equal [275, 155]
    s.game_over.must_equal false
    s = s.move("4a10 7b10 8c10 8d10 8e10")
    s.scores.must_equal [275, 200]
    s.game_over.must_equal false
    s = s.move("2d11 5e11 9f11 9g11")
    s.scores.must_equal [325, 200]
    s.game_over.must_equal false
    s = s.move("5h11")
    s.scores.must_equal [325, 250]
    s.game_over.must_equal false
    s = s.move("7o7 8o8 10o9")
    s.scores.must_equal [385, 250]
    s.game_over.must_equal false
    s = s.move("3n8 9p8")
    s.scores.must_equal [385, 280]
    s.game_over.must_equal false
    s = s.move("7o1 8o2")
    s.scores.must_equal [415, 280]
    s.game_over.must_equal false
    s = s.move("4p6 4p5 8p7")
    s.scores.must_equal [415, 320]
    s.game_over.must_equal false
    s = s.move("1q3 6q6 6q5 7q4")
    s.scores.must_equal [455, 320]
    s.game_over.must_equal false
    s = s.move("1q1 7p1 10n1")
    s.scores.must_equal [455, 375]
    s.game_over.must_equal false
    s = s.move("4j12 7k12 9i12 10h12")
    s.scores.must_equal [515, 375]
    s.game_over.must_equal false
    s = s.move("3l13 5l12 7l14")
    s.scores.must_equal [515, 425]
    s.game_over.must_equal false
    s = s.move("3k13 9m13")
    s.scores.must_equal [540, 425]
    s.game_over.must_equal false
    s = s.move("1o14 5k14 6n14 6m14")
    s.scores.must_equal [540, 480]
    s.game_over.must_equal false
    s = s.move("3q10 7q9 10q8")
    s.scores.must_equal [590, 480]
    s.game_over.must_equal false
    s = s.move("4q15 8p15 9o15 9n15")
    s.scores.must_equal [590, 535]
    s.game_over.must_equal false
    s = s.move("6a12 6a11 9a9")
    s.scores.must_equal [615, 535]
    s.game_over.must_equal false
    s = s.move("1b9 8b8 9b11")
    s.scores.must_equal [615, 585]
    s.game_over.must_equal false
    s = s.move("2c6 6c7 7c8")
    s.scores.must_equal [645, 585]
    s.game_over.must_equal false
    s = s.move("2e7 7d7")
    s.scores.must_equal [636, 600]
    s.game_over.must_equal true

    s = @s
    s.tiles = [4, 6, 8, 7, 2, 4, 7, 5, 2, 8, 6, 7, 4, 10, 9, 9, 3, 9, 8, 1, 10, 7, 4, 6, 7, 1, 3, 7, 3, 10, 1, 3, 8, 7, 6, 5, 4, 5, 2, 8, 8, 3, 8, 9, 6, 6, 5, 8, 9, 4, 8, 2, 9, 1, 6, 7, 9, 5, 7, 6, 6, 10, 7, 8, 7, 4, 8, 3, 7, 10, 9, 9, 6, 7, 2, 2, 9, 1, 1, 4]
    s.racks = [[4, 4, 7, 9, 10], [3, 5, 8, 9, 10]]
    s = s.move("4h8 7i8 9j8")
    s.scores.must_equal [20, 0]
    s.game_over.must_equal false
    s = s.move("3k10 8k9 9k11 10k8")
    s.scores.must_equal [20, 60]
    s.game_over.must_equal false
    s = s.move("4g10 6g9 10g8")
    s.scores.must_equal [80, 60]
    s.game_over.must_equal false
    s = s.move("4h10 7i10 7j10")
    s.scores.must_equal [80, 85]
    s.game_over.must_equal false
    s = s.move("2n9 4j9 8l9 8m9")
    s.scores.must_equal [130, 85]
    s.game_over.must_equal false
    s = s.move("2h9 7f9")
    s.scores.must_equal [130, 110]
    s.game_over.must_equal false
    s = s.move("9i6 9i7")
    s.scores.must_equal [155, 110]
    s.game_over.must_equal false
    s = s.move("6h7 9h11")
    s.scores.must_equal [155, 150]
    s.game_over.must_equal false
    s = s.move("10g7 10j7")
    s.scores.must_equal [250, 150]
    s.game_over.must_equal false
    s = s.move("5k7")
    s.scores.must_equal [250, 225]
    s.game_over.must_equal false
    s = s.move("3i11 5g11 6e11 7f11")
    s.scores.must_equal [325, 225]
    s.game_over.must_equal false
    s = s.move("1p10 4o10 7m10 8n10")
    s.scores.must_equal [325, 270]
    s.game_over.must_equal false
    s = s.move("3g5 7h5 10i5")
    s.scores.must_equal [380, 270]
    s.game_over.must_equal false
    s = s.move("1e4 4f4 7g4 8h4")
    s.scores.must_equal [380, 315]
    s.game_over.must_equal false
    s = s.move("5i4")
    s.scores.must_equal [445, 315]
    s.game_over.must_equal false
    s = s.move("3e8 5e9 8e12 8e10")
    s.scores.must_equal [445, 365]
    s.game_over.must_equal false
    s = s.move("1f5 4e5")
    s.scores.must_equal [480, 365]
    s.game_over.must_equal false
    s = s.move("2d12 6d15 8d13 9d14")
    s.scores.must_equal [480, 400]
    s.game_over.must_equal false
    s = s.move("3g16 3f16 5d16 6e16 8c16")
    s.scores.must_equal [535, 400]
    s.game_over.must_equal false
    s = s.move("2c15 4e15 8b15")
    s.scores.must_equal [535, 440]
    s.game_over.must_equal false
    s = s.move("7d8 9d7 9d6")
    s.scores.must_equal [570, 440]
    s.game_over.must_equal false
    s = s.move("5e6 6c6 6a6 9b6")
    s.scores.must_equal [570, 485]
    s.game_over.must_equal false
    s = s.move("1a16 6a13 6a12 7a14 10a15")
    s.scores.must_equal [630, 485]
    s.game_over.must_equal false
    s = s.move("7g15 7h15 8i15 8j15")
    s.scores.must_equal [630, 525]
    s.game_over.must_equal false
    s = s.move("7k13 9k14 9k16 10k15")
    s.scores.must_equal [705, 525]
    s.game_over.must_equal false
    s = s.move("2l14 2i14 7j14")
    s.scores.must_equal [705, 570]
    s.game_over.must_equal false
    s = s.move("1n13 3l13 9m13")
    s.scores.must_equal [730, 570]
    s.game_over.must_equal false
    s = s.move("4p11 6o11")
    s.scores.must_equal [725, 595]
    s.game_over.must_equal true

    s = @s
    s.tiles = [9, 7, 2, 9, 3, 7, 8, 3, 4, 10, 6, 8, 9, 4, 5, 4, 6, 10, 2, 3, 8, 8, 6, 4, 1, 10, 1, 7, 5, 8, 6, 6, 2, 10, 3, 1, 5, 10, 9, 10, 5, 9, 4, 4, 4, 9, 2, 3, 8, 7, 4, 7, 6, 1, 4, 9, 8, 8, 4, 6, 3, 7, 10, 7, 1, 7, 6, 9, 2, 7, 7, 9, 9, 3, 8, 9, 6, 8, 1, 7]
    s.racks = [[2, 5, 5, 8, 9], [6, 7, 7, 7, 8]]
    s = s.move("2h8 8i8")
    s.scores.must_equal [10, 0]
    s.game_over.must_equal false
    s = s.move("6g9 7k9 7j9 7i9 8h9")
    s.scores.must_equal [10, 60]
    s.game_over.must_equal false
    s = s.move("5i10 5h10 7e10 9g10 9f10")
    s.scores.must_equal [95, 60]
    s.game_over.must_equal false
    s = s.move("3k8 8j8 9l8")
    s.scores.must_equal [95, 115]
    s.game_over.must_equal false
    s = s.move("3l6 4l4 6l5 8l7")
    s.scores.must_equal [125, 115]
    s.game_over.must_equal false
    s = s.move("5k7 7m7")
    s.scores.must_equal [125, 150]
    s.game_over.must_equal false
    s = s.move("10i7 10j7")
    s.scores.must_equal [220, 150]
    s.game_over.must_equal false
    s = s.move("3c9 8e9 9d9")
    s.scores.must_equal [220, 185]
    s.game_over.must_equal false
    s = s.move("2c8 4a8 6d8 8b8")
    s.scores.must_equal [260, 185]
    s.game_over.must_equal false
    s = s.move("1k11 4j11 10i11")
    s.scores.must_equal [260, 240]
    s.game_over.must_equal false
    s = s.move("5e8 7e7 8e6")
    s.scores.must_equal [320, 240]
    s.game_over.must_equal false
    s = s.move("2m6 4m5 6m4 6m3")
    s.scores.must_equal [320, 290]
    s.game_over.must_equal false
    s = s.move("10h11")
    s.scores.must_equal [370, 290]
    s.game_over.must_equal false
    s = s.move("10j6 10k6")
    s.scores.must_equal [370, 375]
    s.game_over.must_equal false
    s = s.move("5g11")
    s.scores.must_equal [420, 375]
    s.game_over.must_equal false
    s = s.move("5k5")
    s.scores.must_equal [420, 420]
    s.game_over.must_equal false
    s = s.move("1n12 1m12 3l12 4k12 6j12")
    s.scores.must_equal [450, 420]
    s.game_over.must_equal false
    s = s.move("2l13 9n13 9m13")
    s.scores.must_equal [450, 465]
    s.game_over.must_equal false
    s = s.move("2d6 3d7")
    s.scores.must_equal [490, 465]
    s.game_over.must_equal false
    s = s.move("4n3 6n2")
    s.scores.must_equal [490, 485]
    s.game_over.must_equal false
    s = s.move("4o0 7o1 9o2")
    s.scores.must_equal [525, 485]
    s.game_over.must_equal false
    s = s.move("7g12 8g13")
    s.scores.must_equal [525, 520]
    s.game_over.must_equal false
    s = s.move("6d13 8f13 8e13")
    s.scores.must_equal [555, 520]
    s.game_over.must_equal false
    s = s.move("4c12 7e12 9d12")
    s.scores.must_equal [555, 570]
    s.game_over.must_equal false
    s = s.move("4c11 7c14 10c13")
    s.scores.must_equal [620, 570]
    s.game_over.must_equal false
    s = s.move("3d14 7d15")
    s.scores.must_equal [620, 605]
    s.game_over.must_equal false
    s = s.move("1f15 7e15")
    s.scores.must_equal [635, 605]
    s.game_over.must_equal false
    s = s.move("4m0 9n0 9p0 9q0")
    s.scores.must_equal [635, 640]
    s.game_over.must_equal false
    s = s.move("1q3 7q2 8q1")
    s.scores.must_equal [660, 640]
    s.game_over.must_equal false
    s = s.move("1p6 6p5 6p4 8p2 9p3")
    s.scores.must_equal [648, 710]
    s.game_over.must_equal true
  end
end
