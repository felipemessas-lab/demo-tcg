extends Node

const DECK_SIZE := 20

var my_deck: Array[int] = []
var my_hero_id: int = 4  # HERO_CARD_ID default

var my_name: String = "Player"
var last_ip: String = "127.0.0.1"

var auto_net_mode: String = ""   # "host" | "join"
var auto_join_ip: String = "127.0.0.1"

func set_default_deck_if_empty() -> void:
	if my_deck.size() != DECK_SIZE:
		my_deck.clear()
		for i in range(DECK_SIZE):
			my_deck.append(randi_range(1, 3)) # placeholder
