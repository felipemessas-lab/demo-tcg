extends Node2D

# ===============================
# NODES (tudo em minúsculo)
# ===============================
@onready var slots: Node2D = $slots
@onready var cards_root: Node2D = $cards
@onready var log_fight: TextEdit = $log_anchor/log_panel/log_fight

@onready var btn_end_turn: Button = $canvaslayer/btnendturn
@onready var btn_buy: Button = $canvaslayer/btnbuy

@onready var life_p1_label: Label = $canvaslayer/life_p1/value
@onready var life_p2_label: Label = $canvaslayer/life_p2/value

@onready var deck_count_p1_label: Label = $canvaslayer/deck_count_p1
@onready var deck_count_p2_label: Label = $canvaslayer/deck_count_p2

@onready var btn_host: Button = get_node_or_null("canvaslayer/btnhost")
@onready var btn_join: Button = get_node_or_null("canvaslayer/btnjoin")
@onready var ip_edit: LineEdit = get_node_or_null("canvaslayer/ipedit")
@onready var net_status: Label = get_node_or_null("canvaslayer/netstatus")

# ===============================
# PRELOADS / CONST
# ===============================
const CardDB = preload("res://scripts/card_db.gd")
var cardscene: PackedScene = preload("res://card.tscn")



const CARD_SCALE: float = 0.15
const FIELD_SLOTS: int = 4
const HAND_MAX: int = 5
const DECK_SIZE: int = 10

# ===============================
# GAME STATE
# ===============================
var local_player: String = "p1"   # perspectiva (p1 host / p2 client)
var current_turn: String = "p1"

var p1_hp: int = 20
var p2_hp: int = 20

var selected_attacker: Node = null

# ZONAS (lógicas)
var deck_p1: Array[int] = []
var deck_p2: Array[int] = []
var hand_p1: Array[int] = []   # guarda card_id
var hand_p2: Array[int] = []

# REGISTRO DE CARTAS DE CAMPO (uid -> node)
var next_card_uid: int = 1
var cards_by_uid: Dictionary = {} # int -> Node

# ===============================
# READY
# ===============================
func _ready() -> void:
	randomize()
	_set_local_player_from_network()

	create_slots_if_missing()

	if log_fight:
		log_fight.text = ""
	log_output("=== DEBUG INICIADO ===")
	log_output("👁️ jogador local: %s" % local_player)

	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	btn_buy.pressed.connect(_on_buy_pressed)

	if btn_host:
		btn_host.pressed.connect(_start_host)
	if btn_join:
		btn_join.pressed.connect(func():
			var ip: String = "127.0.0.1"
			if ip_edit and ip_edit.text.strip_edges() != "":
				ip = ip_edit.text.strip_edges()
			_join_game(ip)
		)

	_update_ui()

	# OFFLINE (sem peer): inicia match local
	if multiplayer.multiplayer_peer == null:
		_init_match_state()
		_spawn_initial_field()
		_refresh_player_cards(current_turn)
		_render_hand_local()
		_render_decks()


# ===============================
# LOCAL PLAYER
# ===============================
func _set_local_player_from_network() -> void:
	if multiplayer.multiplayer_peer == null:
		local_player = "p1"
		return
	if multiplayer.is_server():
		local_player = "p1"
	else:
		local_player = "p2"


# ===============================
# INIT MATCH
# ===============================
func _init_match_state() -> void:
	p1_hp = 20
	p2_hp = 20
	current_turn = "p1"
	selected_attacker = null

	deck_p1.clear()
	deck_p2.clear()
	hand_p1.clear()
	hand_p2.clear()

	_build_random_deck(deck_p1)
	_build_random_deck(deck_p2)

	log_output("🃏 deck p1: %d" % deck_p1.size())
	log_output("🃏 deck p2: %d" % deck_p2.size())

func _build_random_deck(deck: Array[int]) -> void:
	for i in range(DECK_SIZE):
		deck.append(randi_range(1, 2))


# ===============================
# UI / LOG
# ===============================
func _set_net_status(t: String) -> void:
	if net_status:
		net_status.text = t

func _update_ui() -> void:
	if life_p1_label: life_p1_label.text = str(p1_hp)
	if life_p2_label: life_p2_label.text = str(p2_hp)

	if deck_count_p1_label: deck_count_p1_label.text = str(deck_p1.size())
	if deck_count_p2_label: deck_count_p2_label.text = str(deck_p2.size())

	if btn_end_turn: btn_end_turn.text = "passar turno (" + current_turn + ")"

func log_output(t: String) -> void:
	if log_fight:
		log_fight.text += t + "\n\n"
		log_fight.scroll_vertical = log_fight.get_line_count()
	print(t)


# ===============================
# SLOTS (100% via código)
# ===============================
func create_slots_if_missing() -> void:
	# Campo (top/bottom) - 4 slots
	var field_pos: Dictionary = {
		"top_slot_1": Vector2(-300, -150),
		"top_slot_2": Vector2(-100, -150),
		"top_slot_3": Vector2(100, -150),
		"top_slot_4": Vector2(300, -150),

		"bottom_slot_1": Vector2(-300, 150),
		"bottom_slot_2": Vector2(-100, 150),
		"bottom_slot_3": Vector2(100, 150),
		"bottom_slot_4": Vector2(300, 150),
	}

	# Mão (top/bottom) - 5 slots
	var hand_pos: Dictionary = {
		"hand_top_1": Vector2(-320, -360),
		"hand_top_2": Vector2(-160, -360),
		"hand_top_3": Vector2(0, -360),
		"hand_top_4": Vector2(160, -360),
		"hand_top_5": Vector2(320, -360),

		"hand_bottom_1": Vector2(-320, 360),
		"hand_bottom_2": Vector2(-160, 360),
		"hand_bottom_3": Vector2(0, 360),
		"hand_bottom_4": Vector2(160, 360),
		"hand_bottom_5": Vector2(320, 360),
	}

	# Deck (top/bottom) - 1 slot cada
	var deck_pos: Dictionary = {
		"deck_top": Vector2(-680, -150),
		"deck_bottom": Vector2(-680, 150),
	}

	for k in field_pos.keys():
		if not slots.has_node(k):
			var m: Marker2D = Marker2D.new()
			m.name = str(k)
			m.position = field_pos[k]
			slots.add_child(m)

	for k2 in hand_pos.keys():
		if not slots.has_node(k2):
			var mh: Marker2D = Marker2D.new()
			mh.name = str(k2)
			mh.position = hand_pos[k2]
			slots.add_child(mh)

	for k3 in deck_pos.keys():
		if not slots.has_node(k3):
			var md: Marker2D = Marker2D.new()
			md.name = str(k3)
			md.position = deck_pos[k3]
			slots.add_child(md)

func _get_field_slot_pos(owner: String, index: int) -> Vector2:
	var mine: bool = (owner == local_player)
	var prefix: String = "bottom" if mine else "top"
	var name: String = "%s_slot_%d" % [prefix, index]
	var m: Marker2D = slots.get_node(name)
	return m.position

func _get_hand_slot_pos(owner: String, index: int) -> Vector2:
	var mine: bool = (owner == local_player)
	var prefix: String = "hand_bottom" if mine else "hand_top"
	var name: String = "%s_%d" % [prefix, index]
	var m: Marker2D = slots.get_node(name)
	return m.position

func _get_deck_slot_pos_visual_for_owner(owner: String) -> Vector2:
	# deck do "owner" aparece embaixo se for meu, em cima se for oponente
	var mine: bool = (owner == local_player)
	var name: String = "deck_bottom" if mine else "deck_top"
	var m: Marker2D = slots.get_node(name)
	return m.position


# ===============================
# FIELD HELPERS
# ===============================
func unregister_card(card: Node) -> void:
	if card == null:
		return
	if "card_uid" in card:
		var uid: int = int(card.card_uid)
		if cards_by_uid.has(uid):
			cards_by_uid.erase(uid)

func get_card_by_uid(uid: int) -> Node:
	if cards_by_uid.has(uid):
		var c: Node = cards_by_uid[uid]
		if is_instance_valid(c):
			return c
		cards_by_uid.erase(uid)
	return null

func _clear_selection() -> void:
	if selected_attacker != null and is_instance_valid(selected_attacker):
		selected_attacker.set_selected(false)
	selected_attacker = null

func _clear_all_field_cards_local() -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if c.has_meta("zone") and str(c.get_meta("zone")) != "field":
			continue
		unregister_card(c)
		var parent: Node = c.get_parent()
		if parent != null:
			parent.remove_child(c)
		c.queue_free()

func _spawn_initial_field() -> void:
	_clear_all_field_cards_local()
	cards_by_uid.clear()
	next_card_uid = 1

	_spawn_field_cards_for_owner("p1", FIELD_SLOTS)
	_spawn_field_cards_for_owner("p2", FIELD_SLOTS)

func _spawn_field_cards_for_owner(owner: String, count: int) -> void:
	for i in range(count):
		var index: int = i + 1
		var pos: Vector2 = _get_field_slot_pos(owner, index)

		var c: Node = cardscene.instantiate()
		cards_root.add_child(c)

		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.position = pos
		c.cache_base_transform()

		var card_id: int = randi_range(1, 2)
		var data: Dictionary = CardDB.get_card_data(card_id)
		data["card_id"] = card_id
		if data.has("art_path"):
			data["art_texture"] = load(str(data["art_path"]))

		c.setup(data)
		c.card_owner = owner
		c.card_slot = "%s_slot_%d" % [owner, index]
		c.set_exhausted(false)
		c.set_selected(false)

		c.card_uid = next_card_uid
		next_card_uid += 1
		cards_by_uid[int(c.card_uid)] = c

		c.set_meta("zone", "field")
		c.clicked.connect(_on_card_clicked)

func _refresh_player_cards(owner: String) -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if not (c.has_meta("zone") and str(c.get_meta("zone")) == "field"):
			continue
		if "card_owner" in c and str(c.card_owner) == owner:
			c.set_exhausted(false)

func _first_free_field_index(owner: String) -> int:
	var used: Dictionary = {}
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if not (c.has_meta("zone") and str(c.get_meta("zone")) == "field"):
			continue
		if "card_owner" not in c or "card_slot" not in c:
			continue
		if str(c.card_owner) != owner:
			continue

		var slot_name: String = str(c.card_slot) # "p1_slot_3"
		var parts: PackedStringArray = slot_name.split("_")
		if parts.size() == 3:
			var idx: int = int(parts[2])
			used[idx] = true

	for i in range(1, FIELD_SLOTS + 1):
		if not used.has(i):
			return i
	return -1


# ===============================
# HAND RENDER (somente mão do jogador local)
# ===============================
func _clear_hand_visual_local() -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if c.has_meta("zone") and str(c.get_meta("zone")) == "hand":
			unregister_card(c)
			var parent: Node = c.get_parent()
			if parent != null:
				parent.remove_child(c)
			c.queue_free()

func _render_hand_local() -> void:
	_clear_hand_visual_local()

	var hand: Array[int] = hand_p1 if local_player == "p1" else hand_p2
	var count: int = min(hand.size(), HAND_MAX)

	for i in range(count):
		var index: int = i + 1
		var card_id: int = int(hand[i])
		var pos: Vector2 = _get_hand_slot_pos(local_player, index)

		var c: Node = cardscene.instantiate()
		cards_root.add_child(c)

		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.position = pos
		c.cache_base_transform()

		var data: Dictionary = CardDB.get_card_data(card_id)
		data["card_id"] = card_id
		if data.has("art_path"):
			data["art_texture"] = load(str(data["art_path"]))
		c.setup(data)

		c.card_owner = local_player
		c.card_slot = "hand_%d" % index
		c.set_exhausted(false)
		c.set_selected(false)

		# cartas da mão são visuais (uid local)
		c.card_uid = next_card_uid
		next_card_uid += 1
		cards_by_uid[int(c.card_uid)] = c

		c.set_meta("zone", "hand")
		c.set_meta("hand_index", index)

		c.clicked.connect(_on_hand_card_clicked)

func _on_hand_card_clicked(card: Node) -> void:
	if current_turn != local_player:
		log_output("⛔ não é seu turno")
		return

	var idx: int = int(card.get_meta("hand_index", -1))
	if idx < 1:
		return

	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_play_from_hand", idx)
		return

	_play_from_hand(local_player, idx)
	_broadcast_snapshot()
	_render_hand_local()

func _play_from_hand(owner: String, hand_index_1based: int) -> void:
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2

	var arr_index: int = hand_index_1based - 1
	if arr_index < 0 or arr_index >= hand.size():
		return

	var free_idx: int = _first_free_field_index(owner)
	if free_idx == -1:
		log_output("⛔ campo cheio (%s)" % owner)
		return

	var card_id: int = int(hand[arr_index])
	hand.remove_at(arr_index)

	var pos: Vector2 = _get_field_slot_pos(owner, free_idx)

	var c: Node = cardscene.instantiate()
	cards_root.add_child(c)

	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = pos
	c.cache_base_transform()

	var data: Dictionary = CardDB.get_card_data(card_id)
	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = load(str(data["art_path"]))
	c.setup(data)

	c.card_owner = owner
	c.card_slot = "%s_slot_%d" % [owner, free_idx]
	c.set_exhausted(false)
	c.set_selected(false)

	c.card_uid = next_card_uid
	next_card_uid += 1
	cards_by_uid[int(c.card_uid)] = c

	c.set_meta("zone", "field")
	c.clicked.connect(_on_card_clicked)

	log_output("🃏 %s jogou da mão pro campo (slot %d)" % [owner, free_idx])


# ===============================
# DECK RENDER (sempre fechado)
# ===============================
func _clear_deck_visuals() -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if c.has_meta("zone") and str(c.get_meta("zone")) == "deck":
			var parent: Node = c.get_parent()
			if parent != null:
				parent.remove_child(c)
			c.queue_free()

func _render_decks() -> void:
	_clear_deck_visuals()

	# Renderiza DECK P1 e P2 como pilha fechada (sem revelar)
	_render_single_deck_stack("p1")
	_render_single_deck_stack("p2")

func _render_single_deck_stack(owner: String) -> void:
	var deck: Array[int] = deck_p1 if owner == "p1" else deck_p2
	if deck.size() <= 0:
		return

	var pos: Vector2 = _get_deck_slot_pos_visual_for_owner(owner)

	var c: Node = cardscene.instantiate()
	cards_root.add_child(c)

	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = pos
	c.cache_base_transform()

	# "carta verso" (não revela nada)
	var back_data: Dictionary = {
		"card_id": -1,
		"name": "deck",
		"cost": 0,
		"type": "",
		"rules": "",
		"atk": 0,
		"def": 0,
		
	}
	back_data["art_texture"] = preload("res://assets/cards/card_back.png")
	c.setup(back_data)

	c.card_owner = owner
	c.card_slot = "deck"
	c.set_exhausted(false)
	c.set_selected(false)

	c.set_meta("zone", "deck")
	c.set_meta("deck_owner", owner)

	# Só o deck do jogador local (o que fica embaixo) pode comprar
	if owner == local_player:
		c.clicked.connect(func(_card):
			_on_buy_pressed()
		)


# ===============================
# BUY / TURN
# ===============================
func _on_buy_pressed() -> void:
	if current_turn != local_player:
		log_output("⛔ não é seu turno")
		return

	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_buy")
		return

	_draw_card(current_turn)
	_update_ui()
	_render_hand_local()
	_render_decks()
	_broadcast_snapshot()

func _draw_card(owner: String) -> void:
	var deck: Array[int] = deck_p1 if owner == "p1" else deck_p2
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2

	if deck.is_empty():
		log_output("❌ deck vazio (%s)" % owner)
		return

	if hand.size() >= HAND_MAX:
		log_output("⛔ mão cheia (%s)" % owner)
		return

	var card_id: int = int(deck.pop_back())
	hand.append(card_id)

	log_output("📥 %s comprou (mão=%d deck=%d)" % [owner, hand.size(), deck.size()])

func _on_end_turn_pressed() -> void:
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_end_turn")
		return

	log_output("⏭️ %s passou o turno" % current_turn)
	_clear_selection()

	current_turn = "p2" if current_turn == "p1" else "p1"
	_refresh_player_cards(current_turn)

	_update_ui()
	_broadcast_snapshot()


# ===============================
# ATTACK (campo)
# ===============================
func _on_card_clicked(card: Node) -> void:
	if not (card.has_meta("zone") and str(card.get_meta("zone")) == "field"):
		return

	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_click_field", int(card.card_uid))
		return

	if selected_attacker == card:
		_clear_selection()
		return

	if selected_attacker == null:
		if str(card.card_owner) != current_turn:
			return
		if bool(card.exhausted):
			return
		selected_attacker = card
		card.set_selected(true)
		return

	if str(card.card_owner) == current_turn:
		if bool(card.exhausted):
			return
		_clear_selection()
		selected_attacker = card
		card.set_selected(true)
		return

	_resolve_attack(selected_attacker, card)
	if is_instance_valid(selected_attacker):
		selected_attacker.set_exhausted(true)
	_clear_selection()

func _resolve_attack(attacker: Node, defender: Node) -> void:
	var diff: int = int(attacker.atk) - int(defender.def)
	log_output("⚔️ %s (%d) → %s (%d) | diff=%d"
		% [attacker.card_name, int(attacker.atk), defender.card_name, int(defender.def), diff])

	if diff > 0:
		unregister_card(defender)

		# remove imediatamente (pra snapshot não “atrasar”)
		var parent: Node = defender.get_parent()
		if parent != null:
			parent.remove_child(defender)
		defender.queue_free()

		if str(defender.card_owner) == "p1":
			p1_hp = max(p1_hp - diff, 0)
		else:
			p2_hp = max(p2_hp - diff, 0)

	_update_ui()
	_broadcast_snapshot()


# ===============================
# NETWORK: HOST/JOIN + RPC
# ===============================
func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(8910, 2)
	if err != OK:
		_set_net_status("host falhou: %s (%s)" % [str(err), error_string(err)])
		log_output("❌ host falhou: %s (%s)" % [str(err), error_string(err)])
		return

	multiplayer.multiplayer_peer = peer
	local_player = "p1"
	_set_net_status("host ok (8910)")
	log_output("🟢 host criado (p1)")

	_init_match_state()
	_spawn_initial_field()
	_refresh_player_cards(current_turn)
	_update_ui()
	_render_hand_local()
	_render_decks()

	_broadcast_snapshot()

func _join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, 8910)
	if err != OK:
		_set_net_status("join falhou: %s (%s)" % [str(err), error_string(err)])
		log_output("❌ join falhou: %s (%s)" % [str(err), error_string(err)])
		return

	multiplayer.multiplayer_peer = peer
	local_player = "p2"
	_set_net_status("conectando...")
	log_output("🟡 join em %s" % ip)

# ---------- client -> host ----------
@rpc("any_peer", "reliable")
func request_click_field(uid: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sender_owner: String = "p1" if sender == 1 else "p2"
	if sender_owner != current_turn:
		return
	var card: Node = get_card_by_uid(uid)
	if card == null:
		return
	_on_card_clicked(card)
	_broadcast_snapshot()

@rpc("any_peer", "reliable")
func request_end_turn() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sender_owner: String = "p1" if sender == 1 else "p2"
	if sender_owner != current_turn:
		return
	_on_end_turn_pressed()

@rpc("any_peer", "reliable")
func request_buy() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sender_owner: String = "p1" if sender == 1 else "p2"
	if sender_owner != current_turn:
		return
	_draw_card(current_turn)
	_update_ui()
	_broadcast_snapshot()

@rpc("any_peer", "reliable")
func request_play_from_hand(hand_index_1based: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sender_owner: String = "p1" if sender == 1 else "p2"
	if sender_owner != current_turn:
		return
	_play_from_hand(sender_owner, int(hand_index_1based))
	_update_ui()
	_broadcast_snapshot()

# ---------- host -> clients ----------
func _broadcast_snapshot() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return

	var snap: Dictionary = _build_snapshot()
	for id in multiplayer.get_peers():
		rpc_id(id, "apply_snapshot", snap)

func _build_snapshot() -> Dictionary:
	var field_cards: Array = []
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if not (c.has_meta("zone") and str(c.get_meta("zone")) == "field"):
			continue

		field_cards.append({
			"uid": int(c.card_uid),
			"owner": str(c.card_owner),
			"slot": str(c.card_slot),
			"ex": bool(c.exhausted),
			"card_id": int(c.card_id)
		})

	return {
		"turn": current_turn,
		"p1_hp": p1_hp,
		"p2_hp": p2_hp,
		"deck_p1": deck_p1,
		"deck_p2": deck_p2,
		"hand_p1": hand_p1,
		"hand_p2": hand_p2,
		"field": field_cards
	}

@rpc("authority", "reliable")
func apply_snapshot(snap: Dictionary) -> void:
	current_turn = str(snap.get("turn", "p1"))
	p1_hp = int(snap.get("p1_hp", 20))
	p2_hp = int(snap.get("p2_hp", 20))

	deck_p1 = snap.get("deck_p1", []) as Array[int]
	deck_p2 = snap.get("deck_p2", []) as Array[int]
	hand_p1 = snap.get("hand_p1", []) as Array[int]
	hand_p2 = snap.get("hand_p2", []) as Array[int]

	_update_ui()

	# rebuild campo
	_clear_selection()
	_clear_all_field_cards_local()
	cards_by_uid.clear()

	var field: Array = snap.get("field", []) as Array
	for cd in field:
		var owner: String = str(cd.get("owner", "p1"))
		var slot_name: String = str(cd.get("slot", "p1_slot_1"))
		var ex: bool = bool(cd.get("ex", false))
		var card_id: int = int(cd.get("card_id", -1))
		var uid: int = int(cd.get("uid", -1))

		# slot lógico -> index
		var parts: PackedStringArray = slot_name.split("_")
		var idx: int = 1
		if parts.size() == 3:
			idx = int(parts[2])

		var pos: Vector2 = _get_field_slot_pos(owner, idx)

		var c: Node = cardscene.instantiate()
		cards_root.add_child(c)

		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.position = pos
		c.cache_base_transform()

		var data: Dictionary = CardDB.get_card_data(card_id)
		data["card_id"] = card_id
		if data.has("art_path"):
			data["art_texture"] = load(str(data["art_path"]))
		c.setup(data)

		c.card_owner = owner
		c.card_slot = slot_name
		c.card_uid = uid
		c.set_exhausted(ex)
		c.set_selected(false)

		c.set_meta("zone", "field")
		cards_by_uid[uid] = c
		c.clicked.connect(_on_card_clicked)

	# renderiza a mão local + decks fechados
	_render_hand_local()
	_render_decks()
