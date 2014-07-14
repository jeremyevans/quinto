package quinto_test

import q "."
import "testing"

func Test_ParseMove(t *testing.T) {
	gs := q.GameState{}
	shoulds := make(map[string]q.Move)
	shoulds["1a0"] = q.Move{q.TilePlace{1, 0, 0}}
	shoulds["1a1"] = q.Move{q.TilePlace{1, 0, 1}}
	shoulds["3b2"] = q.Move{q.TilePlace{3, 1, 2}}
	shoulds["10m15"] = q.Move{q.TilePlace{10, 12, 15}}
	shoulds["10m15 3m5 2m6 1a1 1a2"] = q.Move{q.TilePlace{10, 12, 15}, q.TilePlace{3, 12, 5}, q.TilePlace{2, 12, 6}, q.TilePlace{1, 0, 1}, q.TilePlace{1, 0, 2}}
	for k, should := range shoulds {
		move, err := gs.ParseMove(k)
		if err != nil {
			t.Error("ParseMove failed for ", k, ", got error", err)
			return
		}
		for i, mv := range should {
			if move[i] != mv {
			  t.Error("ParseMove failed for ", k, ", got", move)
			  return
			}
		}
	}
}
func Test_TilePosition(t *testing.T) {
	shoulds := make(map[string]q.TilePlace)
	shoulds["1a0"] = q.TilePlace{1, 0, 0}
	shoulds["1a1"] = q.TilePlace{1, 0, 1}
	shoulds["3b2"] = q.TilePlace{3, 1, 2}
	shoulds["10m15"] = q.TilePlace{10, 12, 15}
	for should, tp := range shoulds {
		if tp.TilePosition() != should {
			  t.Error("TilePosition failed for ", tp, ", got", tp.TilePosition())
			  return
		}
	}
}
