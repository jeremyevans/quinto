package quinto

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	_ "github.com/bmizerany/pq"
	"github.com/jameskeane/bcrypt"
	"log"
	math_rand "math/rand"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Player struct {
	id    int
	email string
	token string
}

type Game struct {
	id      int
	players []*Player
}

type GameState struct {
	game       *Game
	move_count int
	to_move    int
	tiles      []int
	racks      [][]int
	scores     []int
	pass_count int
	game_over  bool
	board      map[string]int
	last_move  string
}

type TilePlace struct {
	Tile int
	Col int
	Row int
}
type Move []TilePlace

var TEST_MODE bool

var DEFAULT_TILE_BAG [90]int
const RACK_SIZE int = 5
const MAX_RUN int = 5
const SUM_EQUAL int = 5
const BOARD_COLS int = 17
const BOARD_ROWS int = 17
const START_COL int = 8
const START_ROW int = 8

// Game Logic code

func random_tile_bag() []int {
	tiles := make([]int, 90)
	for i, x := range math_rand.Perm(90) {
		tiles[i] = DEFAULT_TILE_BAG[x]
	}
	return tiles
}

func setup_game_logic() {
	DEFAULT_TILE_BAG = [90]int{1, 1, 1, 1, 1, 1,
		2, 2, 2, 2, 2, 2,
		3, 3, 3, 3, 3, 3, 3,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		5, 5, 5, 5, 5, 5,
		6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
		7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
		8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
		9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
		10, 10, 10, 10, 10, 10, 10}
}

func (g *GameState) clone() (*GameState, error) {
	if g.game_over {
		return g, errors.New("cannot clone a GameState for a game that has finished")
	}
	gs := *g
	return &gs, nil
}

func (gs *GameState) moved() *GameState {
	gs.move_count++
	gs.to_move = gs.move_count % len(gs.racks)

	gs.game_over = gs.is_game_over()
	if gs.game_over {
		gs.subtract_unplayed_tiles()
	}

	return gs
}

func (g *GameState) pass() (*GameState, error) {
	gs, err := g.clone()
	if err != nil {
		return gs, err
	}
	gs.pass_count++
	gs.last_move = ""
	return gs.moved(), nil
}

func (g *GameState) move(move_str string) (*GameState, error) {
	gs, err := g.clone()
	if err != nil {
		return gs, err
	}
	gs.pass_count = 0
	gs.last_move = move_str

	move, err := gs.ParseMove(move_str)
	if err != nil {
		return gs, err
	}

	if len(move) < 1 || len(move) > RACK_SIZE {
		return gs, new_error("Must play between 1 and ", RACK_SIZE, " tiles")
	}
	for _, tp := range move {
		err = gs.use_rack_tile(tp.Tile)
		if err != nil {
			return gs, err
		}
	}

	err = gs.check_move(move)
	if err != nil {
		return gs, err
	}

	err = gs.check_board()
	if err != nil {
		return gs, err
	}

	gs.update_score(move)
	gs.fill_racks()
	return gs.moved(), nil
}

func (gs *GameState) use_rack_tile(tile int) error {
	rack :=	gs.racks[gs.to_move]
	for i, rack_tile := range rack {
		if rack_tile == tile {
			gs.racks[gs.to_move] = append(rack[:i], rack[i+1:]...)
			return nil
		}
	}
	return new_error("Tile ", tile, " not in rack")
}

func (t *TilePlace) TilePosition() string {
	return strconv.Itoa(t.Tile) + t.Position()
}

func (t *TilePlace) Position() string {
	return StrPos(t.Col, t.Row)
}

func (gs *GameState) winners() []string {
	max := 0
	for _, score := range gs.scores {
		if score > max {
			max = score
		}
	}
	winners := make([]string, 0, len(gs.scores))
	for i, score := range gs.scores {
		if score == max {
			winners = append(winners, gs.game.players[i].email)
		}
	}
	return winners
}

func (gs *GameState) check_move(move Move) error {
	for _, tp := range move {
		if tp.Col >= BOARD_COLS || tp.Row >= BOARD_ROWS || tp.Col < 0 || tp.Row < 0 {
			return new_error("attempt to place tile outside of board: pos: ", StrPos(tp.Col, tp.Row))
		}
	}

	if len(gs.board) == 0 {
		move = gs.reorder_tiles(Move{move[0]}, move[1:])
	} else {
		move = gs.reorder_tiles(Move{}, move)
	}

	empty := len(gs.board) == 0
	var row, col int
	// Check all tiles are in same column or row
	for i, tp := range move {
		pos := tp.Position()
		switch i {
		case 0:
			row = tp.Row
			col = tp.Col
		case 1:
			if row == tp.Row {
				col = -1
			} else if col == tp.Col {
				row = -1
			} else {
				return new_error("attempt to place tile not in same row or column: row: ", row, " col: ", StrCol(col), " pos: ", pos)
			}
		default:
			if col >= 0 {
				if col != tp.Col {
					return new_error("attempt to place tile not in same column: col: ", StrCol(col), " pos: ", pos)
				}
			} else if row != tp.Row {
				return new_error("attempt to place tile not in same row: row: ", row, " pos: ", pos)
			}
		}
		if (!empty || (i > 0)) && !gs.adjacent(tp) {
			return new_error("attempt to place tile not adjacent to existing tile: pos: ", pos)
		}

		_, found := gs.board[pos]
		if found {
			return new_error("attempt to place tile over existing tile: pos: ", pos)
		}
		gs.board[pos] = tp.Tile

	}

	if empty {
		if gs.board[StrPos(START_COL, START_ROW)] == 0 {
			return new_error("opening move must have tile placed in starting square ", StrPos(START_COL, START_ROW))
		}
		if len(move) == 1 && (move[0].Tile % SUM_EQUAL != 0) {
			return new_error("single tile opening move must be a multiple of ", SUM_EQUAL)
		}
	}

	return nil
}

func (tp *TilePlace) adjacent(move Move) bool {
	for _, atp := range move {
		if tp.Row == atp.Row {
			if tp.Col == atp.Col-1 || tp.Col == atp.Col+1 {
				return true
			}
		} else if tp.Col == atp.Col && (tp.Row == atp.Row-1 || tp.Row == atp.Row+1) {
			return true
		}
	}
	return false
}

func (gs *GameState) reorder_tiles(adj_move, move Move) Move {
	if len(move) == 0 {
		return adj_move
	}
	not_adjacent := make(Move, 0)
	change := false

	for _, tp := range move {
		if gs.adjacent(tp) {
			// Tile already adjacent to tile on board
			adj_move = append(Move{tp}, adj_move...)
			change = true
		} else if tp.adjacent(adj_move) {
			// Tile already adjacent to tile being played in this move
			adj_move = append(adj_move, tp)
			change = true
		} else {
			// Tile not adjacent to any tile yet played in move
			not_adjacent = append(not_adjacent, tp)
		}
	}

	if change {
		return gs.reorder_tiles(adj_move, not_adjacent)
	}
	return append(adj_move, not_adjacent...)
}

func (gs *GameState) adjacent(tp TilePlace) bool {
	return gs.y_adjacent(tp) || gs.x_adjacent(tp)
}

func (gs *GameState) y_adjacent(tp TilePlace) bool {
	return gs.HaveTile(tp.Col+1, tp.Row) || gs.HaveTile(tp.Col-1, tp.Row)
}

func (gs *GameState) x_adjacent(tp TilePlace) bool {
	return gs.HaveTile(tp.Col, tp.Row+1) || gs.HaveTile(tp.Col, tp.Row-1)
}

func (gs *GameState) check_board() error {
	for row := 0; row < BOARD_ROWS; row++ {
		for col := 0; col < BOARD_COLS; col++ {
			run_total := gs.board[StrPos(col, row)]
			if run_total > 0 {
				length := 1
				for i := 1; i <= MAX_RUN; i++ {
					tile := gs.board[StrPos(col+i, row)]
					if tile == 0 {
						break
					}
					run_total += tile
					length++
				}
				if length > MAX_RUN {
					return new_error("more than ", MAX_RUN, " consecutive tiles in row ", row ," columns ", StrCol(col), "-", StrCol(col+length-1))
				}
				if length > 1 && run_total % SUM_EQUAL != 0 {
					return new_error("consecutive tiles do not sum to multiple of ", SUM_EQUAL, " in row ", row, " columns ", StrCol(col), "-", StrCol(col+length-1), " sum ", run_total)
				}
				col += length
			}
		}
	}

	for col := 0; col < BOARD_COLS; col++ {
		for row := 0; row < BOARD_ROWS; row++ {
			run_total := gs.board[StrPos(col, row)]
			if run_total > 0 {
				length := 1
				for i := 1; i <= MAX_RUN; i++ {
					tile := gs.board[StrPos(col, row+i)]
					if tile == 0 {
						break
					}
					run_total += tile
					length++
				}
				if length > MAX_RUN {
					return new_error("more than ", MAX_RUN, " consecutive tiles in column ", StrCol(col), " rows ", row, "-", row+length-1)
				}
				if length > 1 && run_total % SUM_EQUAL != 0 {
					return new_error("consecutive tiles do not sum to multiple of ", SUM_EQUAL, " in column ", StrCol(col), " rows ", row, "-", row+length-1, " sum ", run_total)
				}
				row += length
			}
		}
	}
	return nil
}

func (gs *GameState) TileScore(x, y int) int {
	return gs.board[StrPos(x, y)]
}

func (gs *GameState) HaveTile(x, y int) bool {
	return gs.TileScore(x, y) > 0
}

func (gs *GameState) update_score(move Move) {
	sum := 0
	if len(gs.board) == len(move) {
		// Board was empty before move
		for _, tp := range move {
			sum += tp.Tile
		}
	} else {
		xruns := make(map[int]bool)
		yruns := make(map[int]bool)
		var score int
		for _, tp := range move {
			if !xruns[tp.Row] && gs.y_adjacent(tp) {
				x := tp.Col
				for score = gs.TileScore(x, tp.Row); score > 0; {
					sum += score
					x--
					score = gs.TileScore(x, tp.Row)
				}
				if gs.HaveTile(tp.Col+1, tp.Row) {
					x = tp.Col+1
					for score = gs.TileScore(x, tp.Row); score > 0; {
						sum += score
						x++
						score = gs.TileScore(x, tp.Row)
					}
				}
				xruns[tp.Row] = true
			}
			if !yruns[tp.Col] && gs.x_adjacent(tp) {
				y := tp.Row
				for score = gs.TileScore(tp.Col, y); score > 0; {
					sum += score
					y--
					score = gs.TileScore(tp.Col, y)
				}
				if gs.HaveTile(tp.Col, tp.Row+1) {
					y = tp.Row+1
					for score = gs.TileScore(tp.Col, y); score > 0; {
						sum += score
						y++
						score = gs.TileScore(tp.Col, y)
					}
				}
				yruns[tp.Col] = true
			}
		}
	}
	gs.scores[gs.to_move] += sum
}

func (gs *GameState) ParseMove(move_str string) (Move, error) {
	move_strarr := strings.Split(move_str, " ")
	move := make(Move, len(move_strarr))
	for i, s := range move_strarr {
		skip := 1
		_, err := strconv.Atoi(s[1:2])
		if err == nil {
			skip = 2
		}
		tile, err := strconv.Atoi(s[:skip])
		if err != nil {
			return move, err
		}
		col := int([]byte(s[skip:skip+1])[0]) - 97
		row, err := strconv.Atoi(s[skip+1:])
		if err != nil {
			return move, err
		}

		move[i] = TilePlace{tile, col, row}
	}
	return move, nil
}

func (gs *GameState) subtract_unplayed_tiles() {
	for i, rack := range gs.racks {
		sum := 0
		for _, v := range rack {
			sum += v
		}
		gs.scores[i] -= sum
	}
}

func (gs *GameState) is_game_over() bool {
	if gs.pass_count == len(gs.racks) {
           return true
	} else {
		for _, rack := range gs.racks {
			if len(rack) == 0 {
				return true
			}
		}
	}
	return false
}

func (gs *GameState) fill_racks() {
	for i, rack := range gs.racks {
		num_tiles := RACK_SIZE - len(rack)
		if num_tiles > 0 {
			gs.racks[i] = append(rack, gs.take_tiles(num_tiles)...)
			sort.Ints(gs.racks[i])
		}
	}
}

func (gs *GameState) take_tiles(num int) []int {
	if num > len(gs.tiles) {
		num = len(gs.tiles)
	}
	tiles := gs.tiles[:num]
	gs.tiles = gs.tiles[num:]
	return tiles
}

func (game *Game) player_emails() []string {
	players := make([]string, len(game.players))
	for i, p := range game.players {
		players[i] = p.email
	}
	return players
}

func (game *Game) player_position(player *Player) int {
	for i, p := range game.players {
		if p.id == player.id {
			return i
		}
	}
	panic(errors.New("Game#player_position called with player not in game"))
}

// Utility code

func new_error(a ...interface{}) error {
	return errors.New(fmt.Sprint(a...))
}

func panic_error(tag string, err error) {
	if err != nil {
		fmt.Println("Error: ", tag, err)
		panic(err)
	}
}

func rand_string(length int) string {
	ba := make([]byte, length)
	rand.Read(ba)
	s := base64.URLEncoding.EncodeToString(ba)
	return s
}

func json_marshal(v interface{}) string {
	json_str, _ := json.Marshal(v)
	return string(json_str)
}

func StrPos(x, y int) string {
	return StrCol(x) + strconv.Itoa(y)
}
func StrCol(x int) string {
	return string([]byte{byte(97+x)})
}

// DB code

type ActiveGameInfo map[int][]string

var DB *sql.DB

var PlayerInsert *sql.Stmt
var GameInsert *sql.Stmt
var GamePlayerInsert *sql.Stmt
var GameStateInsert *sql.Stmt

var PlayerFromIdToken *sql.Stmt
var PlayerFromLogin *sql.Stmt
var PlayerFromEmail *sql.Stmt
var PlayerActiveGames *sql.Stmt

var GameFromIdPlayer *sql.Stmt
var CurrentGameState *sql.Stmt
var GameStillAtMove *sql.Stmt

func transaction(f func(tx *sql.Tx) (error)) error {
	tx, err := DB.Begin()
	if err != nil {
		return err
	}
	err = f(tx)
	if err != nil {
		tx.Rollback()
	} else {
		tx.Commit()
	}
	return err
}

func player_insert(email, password string) (*Player, error) {
	h, _ := bcrypt.Hash(password)
	token := rand_string(16)
	row := PlayerInsert.QueryRow(email, h, token)
	var id int
	err := row.Scan(&id)
	return &Player{id, email, token}, err
}

func player_from_id_token(id int, token string) (*Player, error) {
	row := PlayerFromIdToken.QueryRow(id, token)
	var email string
	err := row.Scan(&email)
	if err != nil {
		err = errors.New("Invalid player id or token")
	}
	return &Player{id, email, token}, err
}

func player_from_login(email, password string) (*Player, error) {
	row := PlayerFromLogin.QueryRow(email)
	var id int
	var hash string
	var token string
	err := row.Scan(&id, &hash, &token)
	if err != nil || !bcrypt.Match(password, hash) {
		err = errors.New("User not found or password doesn't match")
	}
	return &Player{id, email, token}, err
}

func player_from_email(email string) (*Player, error) {
	row := PlayerFromEmail.QueryRow(email)
	var id int
	err := row.Scan(&id)
	if err != nil {
		err = errors.New("User not found")
	}
	return &Player{id, email, ""}, err
}

func new_game_with_tiles(players []*Player, tiles []int) (*GameState, error) {
	game := &Game{0, players}
	num_players := len(players)
	if num_players < 2 {
		return nil, errors.New("must have at least 2 players")
	}

	gs := &GameState{}
	gs.game = game
	gs.move_count = 0
	gs.to_move = 0
	gs.tiles = tiles
	gs.racks = make([][]int, num_players)
	for i := 0; i < num_players; i++ {
		gs.racks[i] = make([]int, 0, RACK_SIZE)
	}
	gs.scores = make([]int, num_players)
	gs.pass_count = 0
	gs.board = make(map[string]int)
	gs.last_move = ""
	gs.fill_racks()

	err := transaction(func(tx *sql.Tx) (error) {
		row := tx.Stmt(GameInsert).QueryRow()
		err := row.Scan(&game.id)
		if err != nil {
			return err
		}

		for i, p := range players {
			_, err := tx.Stmt(GamePlayerInsert).Exec(game.id, p.id, i)
			if err != nil {
				return err
			}
		}

		return gs.persist(tx.Stmt(GameStateInsert))
	})
	return gs, err
}

func new_game(players []*Player) (*GameState, error) {
	return new_game_with_tiles(players, random_tile_bag())
}

func game_from_id_player(id, player_id int) (*Game, error) {
	game := &Game{id, make([]*Player, 0)}
	rows, err := GameFromIdPlayer.Query(id, player_id)
	if err != nil {
		return nil, err
	}

	for rows.Next() {
		var id int
		var email string
		err = rows.Scan(&id, &email)
		if err != nil {
			return nil, err
		}
		game.players = append(game.players, &Player{id, email, ""})
	}

	err = rows.Err()
	if err != nil {
		return nil, err
	}
	return game, err
}

func (player *Player) active_games() (*ActiveGameInfo, error) {
	games := make(ActiveGameInfo)
	rows, err := PlayerActiveGames.Query(player.id)
	if err != nil {
		return nil, err
	}

	for rows.Next() {
		var id int
		var email string
		err = rows.Scan(&id, &email)
		if err != nil {
			return nil, err
		}
		if emails, ok := games[id]; ok {
			games[id] = append(emails, email)
		} else {
			games[id] = make([]string, 1)
			games[id][0] = email
		}
	}

	err = rows.Err()
	if err != nil {
		return nil, err
	}

	return &games, err
}

func (game *Game) state() (*GameState, error) {
	row := CurrentGameState.QueryRow(game.id)
	gs := &GameState{}
	gs.game = game
	var tiles, board, racks, scores string
	err := row.Scan(&gs.move_count, &gs.to_move, &tiles, &board, &gs.last_move, &gs.pass_count, &gs.game_over, &racks, &scores)
	if err != nil {
		return gs, err
	}
	err = json.Unmarshal([]byte(tiles), &gs.tiles)
	if err != nil {
		return gs, err
	}
	err = json.Unmarshal([]byte(board), &gs.board)
	if err != nil {
		return gs, err
	}
	err = json.Unmarshal([]byte(racks), &gs.racks)
	if err != nil {
		return gs, err
	}
	err = json.Unmarshal([]byte(scores), &gs.scores)
	if err != nil {
		return gs, err
	}

	return gs, err
}

func (gs *GameState) persist(stmt *sql.Stmt) error {
	_, err := stmt.Exec(gs.game.id, gs.move_count, gs.to_move, json_marshal(gs.tiles), json_marshal(gs.board), gs.last_move, gs.pass_count, gs.game_over, json_marshal(gs.racks), json_marshal(gs.scores))
	return err
}

func game_still_at_move(game_id, move_count int) (bool, error) {
	row := GameStillAtMove.QueryRow(game_id, move_count)
	var still bool
	err := row.Scan(&still)
	return still, err
}

func prepare(s string) *sql.Stmt {
	stmt, err := DB.Prepare(s)
	panic_error("DB.Prepare: " + s, err)
	return stmt
}

func setup_db() {
	var err error
	if TEST_MODE {
		DB, err = sql.Open("postgres", "user=postgres dbname=quinto_test sslmode=disable")
	} else {
		DB, err = sql.Open("postgres", "user=postgres dbname=quinto_go sslmode=disable")
	}
	panic_error("sql.Open", err)
	PlayerInsert = prepare("INSERT INTO players (email, hash, token) VALUES ($1, $2, $3) RETURNING id")
	GameInsert = prepare("INSERT INTO games DEFAULT VALUES RETURNING id")
	GamePlayerInsert = prepare("INSERT INTO game_players (game_id, player_id, position) VALUES ($1, $2, $3)")
	GameStateInsert = prepare("INSERT INTO game_states (game_id, move_count, to_move, tiles, board, last_move, pass_count, game_over, racks, scores) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)")

	PlayerFromIdToken = prepare("SELECT email FROM players WHERE id = $1 AND token = $2")
	PlayerFromLogin = prepare("SELECT id, hash, token FROM players WHERE email = $1")
	PlayerFromEmail = prepare("SELECT id FROM players WHERE email = $1")
	PlayerActiveGames = prepare("SELECT g.game_id AS id, players.email FROM players JOIN ( SELECT * FROM game_players WHERE game_id IN (SELECT game_id FROM game_players WHERE player_id = $1) AND game_id NOT IN (SELECT game_id FROM game_states WHERE game_over = TRUE) AND player_id != $1) AS g ON (players.id = g.player_id) ORDER BY g.game_id DESC, g.position")

	GameFromIdPlayer = prepare("SELECT players.id, players.email FROM players JOIN game_players ON (players.id = game_players.player_id) WHERE game_players.game_id = $1 AND game_players.game_id IN (SELECT game_id FROM game_players WHERE player_id = $2) ORDER by game_players.position")
	CurrentGameState = prepare("SELECT move_count, to_move, tiles, board, last_move, pass_count, game_over, racks, scores FROM game_states WHERE game_id = $1 AND move_count = (SELECT max(move_count) FROM game_states WHERE game_id = $1)")
	GameStillAtMove = prepare("SELECT max(move_count) = $2 FROM game_states WHERE game_id = $1")
}

// Web code

type js_map map[string]interface{}

func IntFormValue(r *http.Request, param string) int {
	value, _ := strconv.Atoi(r.FormValue(param))
	return value
}

func write_json(w http.ResponseWriter, json_map []js_map) {
	json_string, err := json.Marshal(json_map)
	if err == nil {
		w.Write(json_string)
	} else {
		http.Error(w, "Error generating json", 500)
	}
}

func new_jsmap(action string) js_map {
	json_map := make(js_map)
	if action != "" {
		json_map["action"] = action
	}
	return json_map
}

func set_player_json(w http.ResponseWriter, player *Player) {
	js := make([]js_map, 1)
	json_map := new_jsmap("setPlayer")
	js_player := new_jsmap("")
	js_player["id"] = player.id
	js_player["token"] = player.token
	js_player["email"] = player.email
	json_map["player"] = js_player
	js[0] = json_map
	write_json(w, js)
}

func update_actions_json(gs *GameState, player *Player) []js_map {
	js := make([]js_map, 1)
	pos := gs.game.player_position(player)
	ua := new_jsmap("updateInfo")
	ua_state := new_jsmap("")
	ua_state["board"] = gs.board
	ua_state["rack"] = gs.racks[pos]
	ua_state["scores"] = gs.scores
	ua_state["toMove"] = gs.to_move
	ua_state["passCount"] = gs.pass_count
	ua_state["moveCount"] = gs.move_count
	ua["state"] = ua_state
	js[0] = ua

	if gs.game_over {
		game_over_js := new_jsmap("gameOver")
		game_over_js["winners"] = gs.winners()
		js = append(js, game_over_js)
	} else if pos != gs.to_move && !TEST_MODE {
		js = append(js, poll_json(gs.move_count))
	}

	return js
}

func poll_json(move_count int) js_map {
	poll := new_jsmap("poll")
	poll["poll"] = "/game/check/" + strconv.Itoa(move_count)
	return poll
}

func new_game_json(w http.ResponseWriter, gs *GameState, player *Player) {
	ng := new_jsmap("newGame")
	ng["players"] = gs.game.player_emails()
	ng["position"] = gs.game.player_position(player)
	ng["gameId"] = gs.game.id

	js := make([]js_map, 1)
	js[0] = ng
	js = append(js, update_actions_json(gs, player)...)

	write_json(w, js)
}

func game_list_json(w http.ResponseWriter, player *Player) {
	games, err := player.active_games()
	if err != nil {
		http.Error(w, err.Error(), 500)
	}

	js := make([]js_map, 1)
	json_map := new_jsmap("listGames")
	js_games := make([]js_map, len(*games))
	game_ids := make([]int, 0)
	for id := range *games {
		game_ids = append(game_ids, -id)
	}
	sort.Ints(game_ids)
	for i, id := range game_ids {
		js_games[i] = new_jsmap("")
		js_games[i]["id"] = -id
		js_games[i]["players"] = (*games)[-id]
	}
	json_map["games"] = js_games
	js[0] = json_map
	write_json(w, js)
}

func player_from_request(r *http.Request) (*Player, error) {
	return player_from_id_token(IntFormValue(r, "playerId"), r.FormValue("playerToken"))
}

func player_and_game_state_from_request(r *http.Request) (*Player, *GameState, error) {
	player, err := player_from_request(r)
	var gs *GameState
	if err == nil {
		game, err := game_from_id_player(IntFormValue(r, "gameId"), player.id)
		if err == nil {
			gs, err = game.state()
		}
	}

	return player, gs, err
}

func move_or_pass(w http.ResponseWriter, r *http.Request, f func (*GameState) (*GameState, error)) {
	player, gs, err := player_and_game_state_from_request(r)
	if err != nil {
		http.Error(w, err.Error(), 403)
		return
	}

	if gs.game_over {
		http.Error(w, "Game already ended", 403)
		return
	}

	if player.id != gs.game.players[gs.to_move].id {
		http.Error(w, "Not your turn to move", 403)
		return
	}

	gs, err = f(gs)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	gs.persist(GameStateInsert)
	write_json(w, update_actions_json(gs, player))
}

func Log(handler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.RemoteAddr, r.Method, r.URL)
		handler.ServeHTTP(w, r)
	})
}

func setup_handlers() {
	http.HandleFunc("/player/login", func(w http.ResponseWriter, r *http.Request) {
		player, err := player_from_login(r.FormValue("email"), r.FormValue("password"))
		if err == nil {
			set_player_json(w, player)
		} else {
			http.Error(w, err.Error(), 403)
		}
	})

	http.HandleFunc("/player/register", func(w http.ResponseWriter, r *http.Request) {
		player, err := player_insert(r.FormValue("email"), r.FormValue("password"))
		if err == nil {
			set_player_json(w, player)
		} else {
			http.Error(w, "Cannot create player", 403)
		}
	})

	http.HandleFunc("/game/new", func(w http.ResponseWriter, r *http.Request) {
		starter, err := player_from_request(r)
		if err != nil {
			http.Error(w, err.Error(), 403)
			return
		}

		var email_str string
		var tiles []int
		if TEST_MODE {
			ems := strings.SplitN(r.FormValue("emails"), ":", 2)
			email_str = ems[0]
			err = json.Unmarshal([]byte(ems[1]), &tiles)
			if err != nil {
				http.Error(w, err.Error(), 403)
				return
			}
		} else {
			email_str = r.FormValue("emails")
		}

		emails := strings.Split(email_str, ",")
		total_players := len(emails) + 1
		players := make([]*Player, total_players)
		players[0] = starter
		for i := 1; i < total_players; i++ {
			players[i], err = player_from_email(emails[i-1])
			if err != nil {
				http.Error(w, err.Error(), 500)
			}
		}

		player_ids := make(map[int]bool)
		for _, p := range players {
			if player_ids[p.id] == true {
				http.Error(w, "cannot have same player in two separate positions", 500)
				return
			}
			player_ids[p.id] = true
		}

		var gs *GameState
		if TEST_MODE && len(tiles) > 0 {
			gs, err = new_game_with_tiles(players, tiles)
		} else {
			gs, err = new_game(players)
		}

		if err == nil {
			new_game_json(w, gs, starter)
		} else {
			http.Error(w, err.Error(), 500)
		}
	})

	http.HandleFunc("/game/list", func(w http.ResponseWriter, r *http.Request) {
		player, err := player_from_request(r)
		if err != nil {
			http.Error(w, err.Error(), 403)
			return
		}

		game_list_json(w, player)
	})

	http.HandleFunc("/game/join", func(w http.ResponseWriter, r *http.Request) {
		player, gs, err := player_and_game_state_from_request(r)
		if err != nil {
			http.Error(w, err.Error(), 403)
			return
		}
		new_game_json(w, gs, player)
	})

	http.HandleFunc("/game/check/", func(w http.ResponseWriter, r *http.Request) {
		game_id := IntFormValue(r, "gameId")
		arr := strings.Split(r.URL.Path, "/")
		move_count, err := strconv.Atoi(arr[len(arr)-1])
		if err != nil {
			http.Error(w, err.Error(), 403)
			return
		}

		still, err := game_still_at_move(game_id, move_count);
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		if still {
			write_json(w, []js_map{poll_json(move_count)})
		} else {
			player, gs, err := player_and_game_state_from_request(r)
			if err != nil {
				http.Error(w, err.Error(), 403)
				return
			}
			write_json(w, update_actions_json(gs, player))
		}
	})

	http.HandleFunc("/game/pass", func(w http.ResponseWriter, r *http.Request) {
		move_or_pass(w, r, func(gs *GameState) (*GameState, error){
			return gs.pass()
		})
	})

	http.HandleFunc("/game/move", func(w http.ResponseWriter, r *http.Request) {
		move_or_pass(w, r, func(gs *GameState) (*GameState, error){
			return gs.move(r.FormValue("move"))
		})
	})

	http.Handle("/", http.FileServer(http.Dir("public")))
}

func Setup() {
	TEST_MODE = (os.Getenv("QUINTO_TEST") == "1")
	math_rand.Seed(time.Now().UTC().UnixNano())
	setup_game_logic()
	setup_db()
	setup_handlers()
}

func HttpServe() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	fmt.Println("Starting server on port", port)
	port = ":" + port
	http.ListenAndServe(port, Log(http.DefaultServeMux))
}
