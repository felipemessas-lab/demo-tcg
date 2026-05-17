extends Node2D

# ============================================================
# MAIN.GD — BASE ORGANIZADA
# Objetivo desta versão:
# - manter o comportamento atual
# - reorganizar o arquivo em blocos lógicos
# - facilitar próximas regras/efeitos sem mudar a base
# ============================================================


# ============================================================
# NODES / SCENE REFERENCES
# ============================================================
@onready var slots: Node2D = $slots
@onready var cards_root: Node2D = $cards
@onready var log_fight: TextEdit = $log_anchor/log_panel/log_fight

@onready var btn_end_turn: Button = $canvaslayer/btnendturn
@onready var btn_buy: Button = get_node_or_null("canvaslayer/btnbuy")

@onready var btn_keep: Button = $canvaslayer/btn_keep
@onready var btn_mulligan: Button = $canvaslayer/btn_mulligan

@onready var life_p1_label: Label = $canvaslayer/life_p1/value
@onready var life_p2_label: Label = $canvaslayer/life_p2/value

@onready var ui_bottom: Control = $canvaslayer/ui_bottom
@onready var ui_top: Control = $canvaslayer/ui_top

@onready var bottom_deck_count: Label = $canvaslayer/ui_bottom/deck_panel/deck_count
@onready var top_deck_count: Label = $canvaslayer/ui_top/deck_panel/deck_count

@onready var mana_count_bottom: Label = get_node_or_null("canvaslayer/mana_count_bottom")
@onready var mana_count_top: Label = get_node_or_null("canvaslayer/mana_count_top")

@onready var btn_host: Button = get_node_or_null("canvaslayer/btnhost")
@onready var btn_join: Button = get_node_or_null("canvaslayer/btnjoin")
@onready var ip_edit: LineEdit = get_node_or_null("canvaslayer/ipedit")
@onready var net_status: Label = get_node_or_null("canvaslayer/netstatus")

@onready var hero_p1_anchor: Marker2D = get_node_or_null("markers/hero_p1")
@onready var grave_p1_anchor: Marker2D = get_node_or_null("markers/grave_p1")
@onready var deck_p1_anchor: Marker2D = get_node_or_null("markers/deck_p1")


# ============================================================
# DEBUG / CACHE / AUX
# ============================================================
var _born_pos: Vector2 = Vector2.ZERO
var _born_zone: String = "none"
var _p2_snap_logged := false

var _watch_uid: int = 1
var _watch_last_pos: Vector2 = Vector2(999999, 999999)

var _last_hand_sig := ""
var _tex_cache: Dictionary = {}

var _log_buffer: Array[String] = []
var _log_flush_scheduled := false

var _pending_snap: Dictionary = {}
var _snap_scheduled := false


# ============================================================
# PRELOADS / CONST
# ============================================================
const CardDB = preload("res://scripts/card_db.gd")
var cardscene: PackedScene = preload("res://card.tscn")

const CARD_SCALE: float = 0.15

const FIELD_CAPACITY: int = 4
const INITIAL_FIELD_SPAWN: int = 0

const DECK_SIZE: int = 20

const MANA_CAPACITY: int = 10
const LIMIT_MANA_PER_TURN: bool = true

const START_HAND_SIZE: int = 5
const MULLIGAN_HAND_SIZE: int = 4
const HAND_FIRST_PLAYER: int = 5
const HAND_SECOND_PLAYER: int = 5

const HERO_MAX_HP: int = 20
const HERO_Y_BOTTOM: float = 230.0
const HERO_Y_TOP: float = -230.0
const HERO_CARD_ID: int = 4

const GRAVE_Y_BOTTOM: float = 230.0
const GRAVE_Y_TOP: float = -230.0

const HAND_X_MIN: float = -320.0
const HAND_X_MAX: float = 320.0
const HAND_Y_BOTTOM: float = 330.0
const HAND_Y_TOP: float = -330.0
const HAND_CARD_WIDTH: float = 1024.0 * CARD_SCALE
const HAND_GAP_TOUCH: float = HAND_CARD_WIDTH * 0.70
const HAND_GAP_MIN: float = HAND_CARD_WIDTH * 0.22

const MANA_X_COL: float = -500.0
const MANA_Y_MIN: float = 50.0
const MANA_Y_MAX: float = 350.0
const MANA_Y_CENTER_BOTTOM: float = 40.0
const MANA_Y_CENTER_TOP: float = -40.0
const MANA_CARD_H: float = 1536.0 * CARD_SCALE
const MANA_GAP_TOUCH: float = MANA_CARD_H * 0.55
const MANA_GAP_MIN: float = MANA_CARD_H * 0.18
const MANA_TAPETE_PAD_Y: float = 40.0
const MANA_TAPETE_W: float = 220.0

const SLOT_HL_SIZE := Vector2(1024.0 * CARD_SCALE * 0.90, 1536.0 * CARD_SCALE * 0.80)
const SLOT_HL_COLOR_BASE := Color(0.85, 0.92, 1.0, 0.18)
const SLOT_HL_COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.32)

const MANA_ROW_HL_COLOR := Color(0.75, 1.0, 0.75, 0.18)
const MANA_ROW_HL_COLOR_HOVER := Color(1.0, 1.0, 1.0, 0.28)


# ============================================================
# MATCH STATE / CORE GAME STATE
# ============================================================
var match_started: bool = false
var game_phase: String = "main" # lobby | mulligan | main
var current_turn: String = "p1"
var local_player: String = "p1"
var turn_number := 1
var skip_first_turn_draw: bool = true

var mulligan_done := { "p1": false, "p2": false }
var mana_played_this_turn := { "p1": false, "p2": false }

var p1_hp: int = 20
var p2_hp: int = 20

var selected_attacker: Node = null


# ============================================================
# DECK / HAND / FIELD / MANA / HERO / GRAVE STATE
# ============================================================
var deck_p1: Array[int] = []
var deck_p2: Array[int] = []
var hand_p1: Array[int] = []
var hand_p2: Array[int] = []

var grave_p1: Array[int] = []
var grave_p2: Array[int] = []

var field_slots := { "p1": [], "p2": [] }
var mana_line := { "p1": [], "p2": [] }

var next_card_uid: int = 1
var cards_by_uid: Dictionary = {}

var hero_uid := { "p1": -1, "p2": -1 }
var hero_choice_p1: int = Global.my_hero_id
var hero_choice_p2: int = HERO_CARD_ID

var deck_visual_node := { "p1": null, "p2": null }
var grave_top_node := { "p1": null, "p2": null }

var HERO_X: float = 0.0
var GRAVE_X: float = 0.0


# ============================================================
# INPUT / HOVER / PENDING PLAY STATE
# ============================================================
var pending_hand_index: int = -1
var pending_hand_card_uid: int = -1

var _hovered_hand_card: Node = null
var _hovered_mana_card: Node = null

var hovered_slot_index: int = -1
var slot_highlights := {
	"p1": [],
	"p2": []
}

var mana_row_hl := { "p1": null, "p2": null }
var mana_row_hovered: bool = false


# ============================================================
# READY / PROCESS / INPUT
# ============================================================
func _ready() -> void:
	randomize()

	if multiplayer.multiplayer_peer == null and Global.auto_net_mode != "":
		if Global.auto_net_mode == "host":
			_start_host()
			return
		if Global.auto_net_mode == "join":
			_join_game(Global.auto_join_ip)
			return

	print("[NET] unique_id=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server(), " local_player=", local_player)
	print_stack()

	log_output("[NET] after _set_local_player_from_network local_player=%s is_server=%s peer=%s" % [
		local_player, str(multiplayer.is_server()), str(multiplayer.multiplayer_peer != null)
	])

	_setup_board_visual_helpers()
	_setup_buttons()
	_update_ui()

	if multiplayer.multiplayer_peer == null:
		_init_match_state()
		_spawn_initial_field()
		_refresh_player_cards(current_turn)
		_render_hands()
		_relayout_all_mana()
		_render_all_grave_tops()
		_render_all_decks()


func _process(dt: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hand_hover()
		_update_field_highlight_hover()
		_update_mana_row_hover()
		return

	if game_phase == "mulligan":
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_left_click_input()


func _setup_board_visual_helpers() -> void:
	create_slots_if_missing()
	_reset_field_slots()
	_reset_mana_line()
	_ensure_slot_highlights()
	_hide_all_slot_highlights()
	_ensure_mana_row_highlight()
	_hide_mana_row_highlight()

	if log_fight:
		log_fight.text = ""
	log_output("=== DEBUG INICIADO ===")
	log_output("👁️ jogador local: %s" % local_player)


func _setup_buttons() -> void:
	btn_end_turn.pressed.connect(_on_end_turn_pressed)

	if btn_host:
		btn_host.pressed.connect(_start_host)

	if btn_join:
		btn_join.pressed.connect(func():
			var ip: String = "127.0.0.1"
			if ip_edit and ip_edit.text.strip_edges() != "":
				ip = ip_edit.text.strip_edges()
			_join_game(ip)
		)

	if btn_keep:
		btn_keep.pressed.connect(func():
			if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
				rpc_id(1, "request_keep_hand")
			else:
				request_keep_hand()
		)

	if btn_mulligan:
		btn_mulligan.pressed.connect(func():
			if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
				rpc_id(1, "request_mulligan")
			else:
				request_mulligan()
		)


func _handle_left_click_input() -> void:
	var top: Node = _pick_top_hand_card_at_mouse()
	if top != null:
		_on_hand_card_clicked(top)
		get_viewport().set_input_as_handled()
		return

	if pending_hand_index != -1 and current_turn == local_player:
		var hand: Array[int] = hand_p1 if local_player == "p1" else hand_p2
		if pending_hand_index >= 0 and pending_hand_index < hand.size():
			var pending_card_id: int = int(hand[pending_hand_index])
			var data: Dictionary = CardDB.get_card_data(pending_card_id)
			var t: String = str(data.get("type", "")).to_lower().strip_edges()

			if t == "mana":
				if _is_mouse_inside_mana_row(local_player):
					if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
						rpc_id(1, "request_play_mana_from_hand", pending_hand_index)
					else:
						_play_mana_from_hand(local_player, pending_hand_index)
						_update_ui()
						_render_hands()
						_broadcast_snapshot()

					_clear_pending_hand_play()
					get_viewport().set_input_as_handled()
					return

			var slot_idx: int = _pick_free_field_slot_at_mouse(local_player)
			if slot_idx != -1:
				if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
					rpc_id(1, "request_play_from_hand_to_slot", pending_hand_index, slot_idx)
				else:
					_play_from_hand_to_slot(local_player, pending_hand_index, slot_idx)
					_update_ui()
					_render_hands()
					_broadcast_snapshot()

				_clear_pending_hand_play()
				get_viewport().set_input_as_handled()
				return

	if pending_hand_index != -1:
		_clear_pending_hand_play()
		get_viewport().set_input_as_handled()


# ============================================================
# LOCAL PLAYER / BASIC MATCH INIT
# ============================================================
func _set_local_player_from_network() -> void:
	if local_player == "p1" or local_player == "p2":
		return

	if multiplayer.multiplayer_peer == null:
		local_player = "p1"
	else:
		local_player = "p1" if multiplayer.is_server() else "p2"


func _init_match_state() -> void:
	p1_hp = 20
	p2_hp = 20
	current_turn = "p1"
	selected_attacker = null
	turn_number = 1

	deck_p1.clear()
	deck_p2.clear()
	hand_p1.clear()
	hand_p2.clear()

	grave_p1.clear()
	grave_p2.clear()
	_clear_grave_top_visual("p1")
	_clear_grave_top_visual("p2")

	_build_random_deck(deck_p1)
	_build_random_deck(deck_p2)

	mana_played_this_turn["p1"] = false
	mana_played_this_turn["p2"] = false

	p1_hp = HERO_MAX_HP
	p2_hp = HERO_MAX_HP

	log_output("🃏 deck p1: %d" % deck_p1.size())
	log_output("🃏 deck p2: %d" % deck_p2.size())


func _build_random_deck(deck: Array[int]) -> void:
	for i in range(DECK_SIZE):
		deck.append(randi_range(1, 3))


func _opening_hand_size(owner: String) -> int:
	var first: String = current_turn
	return HAND_FIRST_PLAYER if owner == first else HAND_SECOND_PLAYER


# ============================================================
# UI / LOG
# ============================================================
func _set_net_status(t: String) -> void:
	if net_status:
		net_status.text = t


func _update_ui() -> void:
	var my_hp: int = p1_hp if local_player == "p1" else p2_hp
	var opp_hp: int = p2_hp if local_player == "p1" else p1_hp
	if life_p1_label:
		life_p1_label.text = str(my_hp)
	if life_p2_label:
		life_p2_label.text = str(opp_hp)

	var my_deck: int = deck_p1.size() if local_player == "p1" else deck_p2.size()
	var opp_deck: int = deck_p2.size() if local_player == "p1" else deck_p1.size()
	if bottom_deck_count:
		bottom_deck_count.text = str(my_deck)
	if top_deck_count:
		top_deck_count.text = str(opp_deck)

	var mull_pending: bool = (game_phase == "mulligan") and (not (mulligan_done["p1"] and mulligan_done["p2"]))

	if btn_end_turn:
		if mull_pending:
			btn_end_turn.disabled = true
			btn_end_turn.text = "Aguardando mulligan do oponente..."
		elif current_turn == local_player:
			btn_end_turn.disabled = false
			btn_end_turn.text = "Passar turno (seu turno)"
		else:
			btn_end_turn.disabled = true
			btn_end_turn.text = "Turno do oponente"

	var my_owner: String = local_player
	var local_owner: String = local_player
	var opp_owner: String = "p2" if local_player == "p1" else "p1"

	var my_untapped: int = _count_untapped_mana(my_owner)
	var my_total: int = _count_total_mana(my_owner)
	var opp_untapped: int = _count_untapped_mana(opp_owner)
	var opp_total: int = _count_total_mana(opp_owner)

	if mana_count_bottom:
		mana_count_bottom.text = "%d/%d" % [my_untapped, my_total]
	if mana_count_top:
		mana_count_top.text = "%d/%d" % [opp_untapped, opp_total]

	var show_mull: bool = (game_phase == "mulligan") and (not bool(mulligan_done.get(local_owner, false)))

	if btn_keep:
		btn_keep.visible = show_mull
		btn_keep.disabled = !show_mull

	if btn_mulligan:
		btn_mulligan.visible = show_mull
		btn_mulligan.disabled = !show_mull


func log_output(t: String) -> void:
	_log_buffer.append(t)
	if !_log_flush_scheduled:
		_log_flush_scheduled = true
		call_deferred("_flush_log")


func _flush_log() -> void:
	_log_flush_scheduled = false
	if !log_fight:
		return
	log_fight.text += "\n\n".join(_log_buffer) + "\n\n"
	_log_buffer.clear()
	log_fight.scroll_vertical = log_fight.get_line_count()


# ============================================================
# POSITION HELPERS / LAYOUT HELPERS
# ============================================================
func _slot_prefix_for_owner(owner: String) -> String:
	return "bottom" if owner == local_player else "top"


func _field_marker_name(owner: String, index: int) -> String:
	return "%s_slot_%d" % [_slot_prefix_for_owner(owner), index]


func _get_field_slot_pos(owner: String, index: int) -> Vector2:
	var name: String = _field_marker_name(owner, index)
	return (slots.get_node(name) as Marker2D).position


func _hand_y_for(owner: String) -> float:
	return HAND_Y_BOTTOM if owner == local_player else HAND_Y_TOP


func _hand_pos(owner: String, index: int, total: int) -> Vector2:
	var y: float = _hand_y_for(owner)
	if total <= 1:
		return Vector2(0.0, y)

	var span: float = HAND_X_MAX - HAND_X_MIN
	var gap: float = HAND_GAP_TOUCH
	var needed: float = gap * float(total - 1)

	if needed > span:
		gap = span / float(total - 1)
		gap = max(gap, HAND_GAP_MIN)

	var start_x: float = -0.5 * gap * float(total - 1)
	var x: float = start_x + gap * float(index)
	return Vector2(x, y)


func _hero_pos(owner: String) -> Vector2:
	HERO_X = hero_p1_anchor.global_position.x
	var y := HERO_Y_BOTTOM if owner == local_player else HERO_Y_TOP
	return Vector2(HERO_X, y)


func _grave_pos(owner: String) -> Vector2:
	if grave_p1_anchor == null:
		return Vector2.ZERO

	var a: Vector2 = grave_p1_anchor.global_position
	if owner == local_player:
		return a
	return Vector2(a.x, -a.y)


func _deck_pos(owner: String) -> Vector2:
	if deck_p1_anchor == null:
		return Vector2.ZERO

	var a: Vector2 = deck_p1_anchor.global_position
	if owner == local_player:
		return a
	return Vector2(a.x, -a.y)


# ============================================================
# SLOTS / BOARD VISUAL HELPERS
# ============================================================
func create_slots_if_missing() -> void:
	var field_pos: Dictionary = {
		"top_slot_1": Vector2(-300, -130),
		"top_slot_2": Vector2(-100, -130),
		"top_slot_3": Vector2(100, -130),
		"top_slot_4": Vector2(300, -130),
		"bottom_slot_1": Vector2(-300, 130),
		"bottom_slot_2": Vector2(-100, 130),
		"bottom_slot_3": Vector2(100, 130),
		"bottom_slot_4": Vector2(300, 130),
	}

	for k in field_pos.keys():
		if not slots.has_node(k):
			var m: Marker2D = Marker2D.new()
			m.name = str(k)
			slots.add_child(m)
		(slots.get_node(k) as Marker2D).position = field_pos[k]


func _reset_field_slots() -> void:
	field_slots["p1"].clear()
	field_slots["p2"].clear()
	for i in range(FIELD_CAPACITY):
		field_slots["p1"].append(null)
		field_slots["p2"].append(null)


func _reset_mana_line() -> void:
	mana_line["p1"].clear()
	mana_line["p2"].clear()


func _slot_index_from_card_slot(slot_name: String) -> int:
	var parts: PackedStringArray = slot_name.split("_")
	if parts.size() == 3:
		return int(parts[2])
	return -1


func _occupy_field_slot(owner: String, index_1based: int, uid: int) -> void:
	if index_1based < 1 or index_1based > FIELD_CAPACITY:
		return
	field_slots[owner][index_1based - 1] = uid


func _free_field_slot(owner: String, index_1based: int) -> void:
	if index_1based < 1 or index_1based > FIELD_CAPACITY:
		return
	field_slots[owner][index_1based - 1] = null


# ============================================================
# SLOT HIGHLIGHTS / MANA TAPETE
# ============================================================
func _ensure_slot_highlights() -> void:
	if slot_highlights["p1"].size() == FIELD_CAPACITY and slot_highlights["p2"].size() == FIELD_CAPACITY:
		return

	for owner in ["p1", "p2"]:
		for n in slot_highlights[owner]:
			if is_instance_valid(n):
				n.queue_free()
		slot_highlights[owner].clear()

	var half := SLOT_HL_SIZE * 0.5
	var pts := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2( half.x, -half.y),
		Vector2( half.x,  half.y),
		Vector2(-half.x,  half.y),
	])

	for owner in ["p1", "p2"]:
		for i in range(1, FIELD_CAPACITY + 1):
			var poly := Polygon2D.new()
			poly.polygon = pts
			poly.color = SLOT_HL_COLOR_BASE
			poly.z_as_relative = false
			poly.z_index = 1
			poly.visible = false
			poly.position = _get_field_slot_pos(owner, i)
			slots.add_child(poly)
			slot_highlights[owner].append(poly)


func _hide_all_slot_highlights() -> void:
	for owner in ["p1", "p2"]:
		for poly in slot_highlights[owner]:
			if is_instance_valid(poly):
				poly.visible = false
				poly.color = SLOT_HL_COLOR_BASE


func _ensure_mana_row_highlight() -> void:
	for owner in ["p1", "p2"]:
		if is_instance_valid(mana_row_hl[owner]):
			continue
		var poly := Polygon2D.new()
		poly.z_as_relative = false
		poly.z_index = 1
		poly.visible = false
		poly.color = MANA_ROW_HL_COLOR
		slots.add_child(poly)
		mana_row_hl[owner] = poly


func _hide_mana_row_highlight() -> void:
	for owner in ["p1", "p2"]:
		var poly: Polygon2D = mana_row_hl[owner]
		if is_instance_valid(poly):
			poly.visible = false
			poly.color = MANA_ROW_HL_COLOR


func _mana_y_center_for(owner: String) -> float:
	return MANA_Y_CENTER_BOTTOM if owner == local_player else MANA_Y_CENTER_TOP


func _mana_rect(owner: String) -> Rect2:
	var cy: float = MANA_Y_CENTER_BOTTOM if owner == local_player else MANA_Y_CENTER_TOP

	var y_min: float
	var y_max: float

	if owner == local_player:
		y_min = cy + MANA_Y_MIN
		y_max = cy + MANA_Y_MAX
	else:
		y_min = cy - MANA_Y_MAX
		y_max = cy - MANA_Y_MIN

	if y_max < y_min:
		var tmp := y_min
		y_min = y_max
		y_max = tmp

	var top_y := y_min - MANA_TAPETE_PAD_Y
	var h := (y_max - y_min) + (MANA_TAPETE_PAD_Y * 2.0)
	var left_x := MANA_X_COL - (MANA_TAPETE_W * 0.5)
	return Rect2(Vector2(left_x, top_y), Vector2(MANA_TAPETE_W, h))


func _update_mana_row_highlight_geometry(owner: String) -> void:
	var poly: Polygon2D = mana_row_hl[owner]
	if !is_instance_valid(poly):
		return

	var r := _mana_rect(owner)
	poly.position = Vector2.ZERO
	poly.polygon = PackedVector2Array([
		r.position,
		Vector2(r.position.x + r.size.x, r.position.y),
		r.position + r.size,
		Vector2(r.position.x, r.position.y + r.size.y),
	])


func _show_free_slots_highlight_if_needed() -> void:
	_ensure_slot_highlights()
	_hide_all_slot_highlights()
	_ensure_mana_row_highlight()
	_hide_mana_row_highlight()

	if pending_hand_index == -1:
		return
	if current_turn != local_player:
		return

	var owner := local_player
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2
	if pending_hand_index < 0 or pending_hand_index >= hand.size():
		return

	var card_id := int(hand[pending_hand_index])
	var data := CardDB.get_card_data(card_id)
	var t := str(data.get("type", "")).to_lower().strip_edges()

	if t == "mana":
		_update_mana_row_highlight_geometry(owner)
		var poly: Polygon2D = mana_row_hl[owner]
		if is_instance_valid(poly):
			poly.visible = true
			poly.color = MANA_ROW_HL_COLOR
		return

	for i in range(1, FIELD_CAPACITY + 1):
		if field_slots[owner][i - 1] == null:
			var poly2: Polygon2D = slot_highlights[owner][i - 1]
			if is_instance_valid(poly2):
				poly2.position = _get_field_slot_pos(owner, i)
				poly2.visible = true


func _update_field_highlight_hover() -> void:
	hovered_slot_index = -1

	if pending_hand_index == -1:
		return
	if current_turn != local_player:
		return

	var owner := local_player
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2
	if pending_hand_index < 0 or pending_hand_index >= hand.size():
		return

	var cid: int = int(hand[pending_hand_index])
	var t := str(CardDB.get_card_data(cid).get("type", "")).to_lower().strip_edges()
	if t == "mana":
		return

	var mp := get_global_mouse_position()
	var half := SLOT_HL_SIZE * 0.5

	for i in range(1, FIELD_CAPACITY + 1):
		if field_slots[owner][i - 1] != null:
			continue

		var name := _field_marker_name(owner, i)
		var m: Marker2D = slots.get_node(name)
		var p := m.global_position

		if Rect2(p - half, SLOT_HL_SIZE).has_point(mp):
			hovered_slot_index = i
			break

	for i in range(1, FIELD_CAPACITY + 1):
		var poly: Polygon2D = slot_highlights[owner][i - 1]
		if !is_instance_valid(poly) or !poly.visible:
			continue
		poly.color = SLOT_HL_COLOR_HOVER if i == hovered_slot_index else SLOT_HL_COLOR_BASE


func _is_mouse_inside_mana_row(owner: String) -> bool:
	var poly: Polygon2D = mana_row_hl[owner]
	if !is_instance_valid(poly) or !poly.visible:
		return false
	var mp_global: Vector2 = get_global_mouse_position()
	return _mana_rect(owner).has_point(mp_global)


func _update_mana_row_hover() -> void:
	mana_row_hovered = false

	if pending_hand_index == -1:
		return
	if current_turn != local_player:
		return

	var owner := local_player
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2
	if pending_hand_index < 0 or pending_hand_index >= hand.size():
		return

	var cid: int = int(hand[pending_hand_index])
	var t := str(CardDB.get_card_data(cid).get("type", "")).to_lower().strip_edges()
	if t != "mana":
		return

	var poly: Polygon2D = mana_row_hl[owner]
	if !is_instance_valid(poly) or !poly.visible:
		return

	mana_row_hovered = _mana_rect(owner).has_point(get_global_mouse_position())
	poly.color = MANA_ROW_HL_COLOR_HOVER if mana_row_hovered else MANA_ROW_HL_COLOR


# ============================================================
# CARD REGISTRY / LOOKUP / CLEANUP
# ============================================================
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
	_reset_field_slots()
	_hide_all_slot_highlights()


func _clear_all_mana_cards_local() -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if c.has_meta("zone") and str(c.get_meta("zone")) != "mana":
			continue
		unregister_card(c)
		var parent: Node = c.get_parent()
		if parent != null:
			parent.remove_child(c)
		c.queue_free()
	_reset_mana_line()


# ============================================================
# HERO / GRAVE / DECK VISUALS
# ============================================================
func _spawn_hero_for_owner(owner: String) -> void:
	var c: Node = cardscene.instantiate()
	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = _hero_pos(owner)
	c.z_index = 5
	c.z_as_relative = false
	cards_root.add_child(c)

	var hero_id: int = hero_choice_p1 if owner == "p1" else hero_choice_p2
	var data: Dictionary = CardDB.get_card_data(hero_id).duplicate(true)
	data["card_id"] = hero_id
	if data.has("art_path"):
		data["art_texture"] = load(str(data["art_path"]))

	c.setup(data)
	c.card_owner = owner
	c.card_slot = "hero"
	c.set_exhausted(false)
	c.set_selected(false)

	c.card_uid = next_card_uid
	next_card_uid += 1
	cards_by_uid[int(c.card_uid)] = c

	c.set_meta("zone", "hero")
	c.clicked.connect(_on_card_clicked)
	hero_uid[owner] = int(c.card_uid)

	if c.has_method("cache_base_transform"):
		c.cache_base_transform()


func _grave_list(owner: String) -> Array[int]:
	return grave_p1 if owner == "p1" else grave_p2


func _set_grave_list(owner: String, arr: Array[int]) -> void:
	if owner == "p1":
		grave_p1 = arr
	else:
		grave_p2 = arr


func _clear_grave_top_visual(owner: String) -> void:
	var n: Node = grave_top_node.get(owner, null)
	if n != null and is_instance_valid(n):
		n.queue_free()
	grave_top_node[owner] = null


func _render_grave_top(owner: String) -> void:
	_clear_grave_top_visual(owner)

	var list := _grave_list(owner)
	if list.is_empty():
		return

	var top_card_id: int = int(list[list.size() - 1])
	var c: Node = cardscene.instantiate()
	var grave_scale := CARD_SCALE * 0.82
	c.scale = Vector2(grave_scale, grave_scale)
	c.position = _grave_pos(owner)
	c.z_index = 2
	c.z_as_relative = false
	cards_root.add_child(c)

	var data: Dictionary = CardDB.get_card_data(top_card_id)
	data["card_id"] = top_card_id
	if data.has("art_path"):
		data["art_texture"] = _get_tex(str(data["art_path"]))
	c.setup(data)

	c.card_owner = owner
	c.card_slot = "grave"
	c.set_meta("zone", "grave")

	if "hitbox" in c and c.hitbox:
		c.hitbox.monitoring = true
		c.hitbox.monitorable = true
		c.hitbox.input_pickable = true

	if "hover_enabled" in c:
		c.hover_enabled = true
	if "hover_lift_y" in c:
		c.hover_lift_y = 55.0
	if "hover_scale" in c:
		c.hover_scale = 1.75

	if c.has_method("cache_base_transform"):
		c.cache_base_transform()

	grave_top_node[owner] = c


func _render_all_grave_tops() -> void:
	_render_grave_top("p1")
	_render_grave_top("p2")


func _clear_deck_visual(owner: String) -> void:
	var n: Node = deck_visual_node.get(owner, null)
	if n != null and is_instance_valid(n):
		n.queue_free()
	deck_visual_node[owner] = null


func _render_deck_visual(owner: String) -> void:
	_clear_deck_visual(owner)

	var size: int = deck_p1.size() if owner == "p1" else deck_p2.size()
	if size <= 0:
		return

	var c: Node = cardscene.instantiate()
	var s := CARD_SCALE * 0.78
	c.scale = Vector2(s, s)
	c.position = _deck_pos(owner)
	c.z_index = 3
	c.z_as_relative = false
	cards_root.add_child(c)

	c.setup(_get_back_data())
	c.card_owner = owner
	c.card_slot = "deck"
	c.set_meta("zone", "deck")

	if "hitbox" in c and c.hitbox:
		c.hitbox.monitoring = false
		c.hitbox.monitorable = false
		c.hitbox.input_pickable = false

	if c.has_method("cache_base_transform"):
		c.cache_base_transform()

	deck_visual_node[owner] = c


func _render_all_decks() -> void:
	_render_deck_visual("p1")
	_render_deck_visual("p2")


func _send_card_to_graveyard(card: Node) -> void:
	if card == null or !is_instance_valid(card):
		return

	var owner: String = str(card.card_owner)
	var zone: String = str(card.get_meta("zone")) if card.has_meta("zone") else ""
	var cid: int = int(card.card_id)

	if zone == "field":
		var idx := _slot_index_from_card_slot(str(card.card_slot))
		if idx != -1:
			_free_field_slot(owner, idx)
	elif zone == "mana":
		var arr: Array = mana_line[owner]
		var uid := int(card.card_uid)
		var pos := arr.find(uid)
		if pos != -1:
			arr.remove_at(pos)

	var list := _grave_list(owner)
	list.append(cid)
	_set_grave_list(owner, list)

	unregister_card(card)
	var parent := card.get_parent()
	if parent != null:
		parent.remove_child(card)
	card.queue_free()

	_render_grave_top(owner)
	if zone == "mana":
		_relayout_mana(owner)


# ============================================================
# FIELD / HERO SPAWN
# ============================================================
func _spawn_initial_field() -> void:
	_clear_all_field_cards_local()
	_clear_all_mana_cards_local()
	cards_by_uid.clear()
	next_card_uid = 1

	_spawn_field_cards_for_owner("p1", INITIAL_FIELD_SPAWN)
	_spawn_field_cards_for_owner("p2", INITIAL_FIELD_SPAWN)
	_spawn_hero_for_owner("p1")
	_spawn_hero_for_owner("p2")


func _spawn_field_cards_for_owner(owner: String, count: int) -> void:
	for i in range(count):
		var index: int = i + 1
		if index > FIELD_CAPACITY:
			return

		var pos: Vector2 = _get_field_slot_pos(owner, index)
		var c: Node = cardscene.instantiate()
		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.position = pos
		c.z_index = 0
		c.z_as_relative = false
		cards_root.add_child(c)

		var card_id: int = randi_range(1, 3)
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

		_occupy_field_slot(owner, index, int(c.card_uid))
		c.set_meta("zone", "field")
		c.clicked.connect(_on_card_clicked)

		if c.has_method("cache_base_transform"):
			c.cache_base_transform()


func _refresh_player_cards(owner: String) -> void:
	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if not c.has_meta("zone"):
			continue
		var zone := str(c.get_meta("zone"))
		if zone != "field" and zone != "mana":
			continue
		if "card_owner" in c and str(c.card_owner) == owner:
			c.set_exhausted(false)


# ============================================================
# HAND RENDER / PICK / SELECTION
# ============================================================
func _get_back_data() -> Dictionary:
	return {
		"card_id": -1,
		"name": "",
		"cost": 0,
		"type": "",
		"rules": "",
		"atk": 0,
		"def": 0,
		"art_texture": null
	}


func _clear_hand_visuals() -> void:
	for c in cards_root.get_children():
		if !is_instance_valid(c):
			continue
		if c.has_meta("zone") and str(c.get_meta("zone")) == "hand":
			var parent: Node = c.get_parent()
			if parent != null:
				parent.remove_child(c)
			c.queue_free()


func _render_hands() -> void:
	_clear_hand_visuals()

	if _hovered_hand_card != null and is_instance_valid(_hovered_hand_card):
		_hovered_hand_card.set_hand_hover(false)
	_hovered_hand_card = null

	var my_owner: String = local_player
	var my_hand: Array[int] = hand_p1 if my_owner == "p1" else hand_p2
	var my_count: int = my_hand.size()

	for i in range(my_count):
		var card_id: int = int(my_hand[i])
		var pos: Vector2 = _hand_pos(my_owner, i, my_count)
		var c: Node = cardscene.instantiate()
		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.position = pos
		c.z_index = 100 + i
		c.z_as_relative = false
		cards_root.add_child(c)

		if c.has_method("cache_base_transform"):
			c.cache_base_transform()

		var data: Dictionary = CardDB.get_card_data(card_id)
		data["card_id"] = card_id
		if data.has("art_path"):
			data["art_texture"] = load(str(data["art_path"]))
		c.setup(data)

		c.card_owner = my_owner
		c.card_slot = "hand_%d" % i
		c.set_exhausted(false)
		c.set_selected(false)
		c.set_meta("zone", "hand")
		c.set_meta("hand_index", i)
		c.set_meta("face_down", false)

		if "hitbox" in c and c.hitbox:
			c.hitbox.input_pickable = false

	var opp_owner: String = "p2" if local_player == "p1" else "p1"
	var opp_hand: Array[int] = hand_p1 if opp_owner == "p1" else hand_p2
	var opp_count: int = opp_hand.size()

	for i in range(opp_count):
		var pos2: Vector2 = _hand_pos(opp_owner, i, opp_count)
		var b: Node = cardscene.instantiate()
		b.scale = Vector2(CARD_SCALE, CARD_SCALE)
		b.position = pos2
		b.z_index = 120 + i
		b.z_as_relative = false
		cards_root.add_child(b)

		if b.has_method("cache_base_transform"):
			b.cache_base_transform()

		b.setup(_get_back_data())
		b.card_owner = opp_owner
		b.card_slot = "hand_%d" % i
		b.set_exhausted(false)
		b.set_selected(false)
		b.set_meta("zone", "hand")
		b.set_meta("hand_index", i)
		b.set_meta("face_down", true)

		if "hitbox" in b and b.hitbox:
			b.hitbox.input_pickable = false


func _clear_pending_hand_play() -> void:
	pending_hand_index = -1
	pending_hand_card_uid = -1
	_hide_all_slot_highlights()
	_hide_mana_row_highlight()
	_set_hand_selected_visual_by_index(-1)


func _set_hand_selected_visual_by_index(hand_index: int) -> void:
	for c in cards_root.get_children():
		if !is_instance_valid(c):
			continue
		if !(c.has_meta("zone") and str(c.get_meta("zone")) == "hand"):
			continue
		if "card_owner" in c and str(c.card_owner) != local_player:
			continue
		if c.has_method("set_selected_visual"):
			c.set_selected_visual(false)

	if hand_index == -1:
		return

	for c in cards_root.get_children():
		if !is_instance_valid(c):
			continue
		if !(c.has_meta("zone") and str(c.get_meta("zone")) == "hand"):
			continue
		if int(c.get_meta("hand_index", -1)) == hand_index:
			if c.has_method("set_selected_visual"):
				c.set_selected_visual(true)
			return


func _on_hand_card_clicked(card: Node) -> void:
	if game_phase == "mulligan":
		log_output("⛔ aguarde o mulligan terminar")
		return
	if current_turn != local_player:
		log_output("⛔ não é seu turno")
		return

	var idx: int = int(card.get_meta("hand_index", -1))
	if idx < 0:
		return

	if pending_hand_index == idx:
		log_output("↩️ cancelou jogar da mão")
		_clear_pending_hand_play()
		return

	pending_hand_index = idx
	pending_hand_card_uid = 0
	_set_hand_selected_visual_by_index(pending_hand_index)

	log_output("✅ clique em slot livre (campo) ou no tapete (mana)")
	_show_free_slots_highlight_if_needed()


func _pick_top_hand_card_at_mouse() -> Node:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = mouse_pos
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 0x7fffffff

	var hits: Array = space.intersect_point(q, 64)
	var best_card: Node = null
	var best_z: int = -999999

	for h in hits:
		var area: Area2D = h.get("collider", null)
		if area == null:
			continue
		var card: Node = area.get_parent()
		if card == null:
			continue
		if not (card.has_meta("zone") and str(card.get_meta("zone")) == "hand"):
			continue
		if "card_owner" in card and str(card.card_owner) != local_player:
			continue

		var z: int = int(card.z_index)
		if z > best_z:
			best_z = z
			best_card = card

	return best_card


func _update_hand_hover() -> void:
	var top := _pick_top_hand_card_at_mouse()
	if top == _hovered_hand_card:
		return

	if _hovered_hand_card != null and is_instance_valid(_hovered_hand_card):
		_hovered_hand_card.set_hand_hover(false)

	_hovered_hand_card = top
	if _hovered_hand_card != null and is_instance_valid(_hovered_hand_card):
		_hovered_hand_card.set_hand_hover(true)


func _pick_top_mana_card_at_mouse() -> Node:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = mouse_pos
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 0x7fffffff

	var hits: Array = space.intersect_point(q, 64)
	var best_card: Node = null
	var best_z: int = -999999

	for h in hits:
		var area: Area2D = h.get("collider", null)
		if area == null:
			continue
		var card: Node = area.get_parent()
		if card == null:
			continue
		if not (card.has_meta("zone") and str(card.get_meta("zone")) == "mana"):
			continue

		var z: int = int(card.z_index)
		if z > best_z:
			best_z = z
			best_card = card

	return best_card


func _update_mana_hover() -> void:
	var top := _pick_top_mana_card_at_mouse()
	if top == _hovered_mana_card:
		return

	if _hovered_mana_card != null and is_instance_valid(_hovered_mana_card):
		_hovered_mana_card.set_hand_hover(false)

	_hovered_mana_card = top
	if _hovered_mana_card != null and is_instance_valid(_hovered_mana_card):
		_hovered_mana_card.set_hand_hover(true)


# ============================================================
# MANA LAYOUT / MANA HELPERS
# ============================================================
func _mana_pos(owner: String, index: int, total: int) -> Vector2:
	var x := MANA_X_COL
	var cy: float = MANA_Y_CENTER_BOTTOM if owner == local_player else MANA_Y_CENTER_TOP

	var y_min: float
	var y_max: float

	if owner == local_player:
		y_min = cy + MANA_Y_MIN
		y_max = cy + MANA_Y_MAX
	else:
		y_min = cy - MANA_Y_MAX
		y_max = cy - MANA_Y_MIN

	if y_max < y_min:
		var tmp := y_min
		y_min = y_max
		y_max = tmp

	var span: float = y_max - y_min
	var gap: float = MANA_GAP_TOUCH
	var needed: float = gap * float(total - 1)

	if needed > span:
		gap = span / float(total - 1)
		gap = max(gap, MANA_GAP_MIN)

	var start_y := (y_min + y_max) * 0.5 - 0.5 * gap * float(total - 1)
	var y := start_y + gap * float(index)
	return Vector2(x, y)


func _relayout_mana(owner: String) -> void:
	var list: Array = mana_line[owner]
	var total: int = list.size()

	for i in range(total):
		var uid: int = int(list[i])
		var c := get_card_by_uid(uid)
		if c == null:
			continue
		if !(c.has_meta("zone") and str(c.get_meta("zone")) == "mana"):
			continue

		var p := _mana_pos(owner, i, total)
		c.position = p
		c.scale = Vector2(CARD_SCALE, CARD_SCALE)
		c.z_index = 0
		c.z_as_relative = false

		if c.has_method("cache_base_transform"):
			c.cache_base_transform()


func _relayout_all_mana() -> void:
	_relayout_mana("p1")
	_relayout_mana("p2")


func _count_total_mana(owner: String) -> int:
	return mana_line[owner].size()


func _count_untapped_mana(owner: String) -> int:
	var count := 0
	for uid in mana_line[owner]:
		var c := get_card_by_uid(int(uid))
		if c != null and !bool(c.exhausted):
			count += 1
	return count


func _can_pay_with_untapped_mana(owner: String, cost: int) -> bool:
	if cost <= 0:
		return true
	return _count_untapped_mana(owner) >= cost


func _tap_mana_to_pay(owner: String, cost: int) -> void:
	var left: int = cost
	if left <= 0:
		return

	for uid in mana_line[owner]:
		var c := get_card_by_uid(int(uid))
		if c == null:
			continue
		if bool(c.exhausted):
			continue
		c.set_exhausted(true)
		left -= 1
		if left <= 0:
			return


func _dump_mana_state(tag: String) -> void:
	for owner in ["p1", "p2"]:
		var total: int = mana_line[owner].size()
		for i in range(total):
			var uid: int = int(mana_line[owner][i])
			var c := get_card_by_uid(uid)
			if c == null:
				continue

			var cur: Vector2 = c.position
			var exp: Vector2 = _mana_pos(owner, i, total)
			var drift: float = cur.distance_to(exp)
			var sc: Vector2 = Vector2.ONE
			if "scale" in c:
				sc = c.scale


func _dump_mana_next_frame(tag: String) -> void:
	await get_tree().process_frame
	_dump_mana_state(tag + "_NEXT_FRAME")


# ============================================================
# DRAW / TURN / MULLIGAN FLOW
# ============================================================
func _draw_card(owner: String) -> void:
	var deck: Array[int] = deck_p1 if owner == "p1" else deck_p2
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2

	if deck.is_empty():
		log_output("❌ deck vazio (%s)" % owner)
		return

	var card_id: int = int(deck.pop_back())
	hand.append(card_id)
	log_output("📥 %s comprou (mão=%d deck=%d)" % [owner, hand.size(), deck.size()])


func _perform_mulligan(owner: String) -> void:
	var deck: Array[int] = deck_p1 if owner == "p1" else deck_p2
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2

	for cid in hand:
		deck.append(int(cid))
	hand.clear()
	deck.shuffle()

	var target := _opening_hand_size(owner)
	for i in range(target):
		_draw_card(owner)


func _start_turn(owner: String) -> void:
	mana_played_this_turn[owner] = false
	_refresh_player_cards(owner)
	_enable_attacks_for_owner(owner)

	if skip_first_turn_draw and owner == "p1":
		skip_first_turn_draw = false
	else:
		_draw_card(owner)

	_update_ui()
	_render_hands()
	_relayout_all_mana()
	_broadcast_snapshot()


func _on_buy_pressed() -> void:
	if current_turn != local_player:
		log_output("⛔ não é seu turno")
		return

	_clear_pending_hand_play()

	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_buy")
		return

	_draw_card(current_turn)
	_update_ui()
	_render_hands()
	_broadcast_snapshot()


func _on_end_turn_pressed() -> void:
	if game_phase == "mulligan":
		log_output("⛔ aguarde o mulligan terminar")
		return

	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_end_turn")
		return

	log_output("⏭️ %s passou o turno" % current_turn)
	_clear_selection()
	_clear_pending_hand_play()

	turn_number += 1
	current_turn = "p2" if current_turn == "p1" else "p1"

	if game_phase != "main":
		_update_ui()
		_broadcast_snapshot()
		return

	_start_turn(current_turn)
	return

	mana_played_this_turn[current_turn] = false
	_refresh_player_cards(current_turn)
	_draw_card(current_turn)
	_update_ui()
	_dump_mana_state("END_TURN_AFTER_LOCAL")
	_dump_mana_next_frame("END_TURN_AFTER_LOCAL")
	_broadcast_snapshot()


func _try_finish_mulligan_and_start() -> void:
	if mulligan_done["p1"] and mulligan_done["p2"]:
		game_phase = "main"
		current_turn = "p1"
		skip_first_turn_draw = true
		log_output("🎲 mulligan concluído. Iniciando jogo: turno p1 (sem compra no 1º turno)")
		_start_turn("p1")
		_update_ui()
		_render_hands()
		_relayout_all_mana()
		_broadcast_snapshot()
	else:
		_broadcast_snapshot()


# ============================================================
# PLAY FROM HAND / FIELD / MANA
# ============================================================
func _pick_free_field_slot_at_mouse(owner: String) -> int:
	var mp_global: Vector2 = get_global_mouse_position()
	var half: Vector2 = SLOT_HL_SIZE * 0.5

	for i in range(1, FIELD_CAPACITY + 1):
		if field_slots[owner][i - 1] != null:
			continue

		var name: String = _field_marker_name(owner, i)
		var m: Marker2D = slots.get_node(name)
		var p: Vector2 = m.global_position
		var rect := Rect2(p - half, SLOT_HL_SIZE)
		if rect.has_point(mp_global):
			return i

	return -1


func _play_from_hand_to_slot(owner: String, hand_index: int, slot_idx: int) -> void:
	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2
	if hand_index < 0 or hand_index >= hand.size():
		return
	if slot_idx < 1 or slot_idx > FIELD_CAPACITY:
		return
	if field_slots[owner][slot_idx - 1] != null:
		log_output("⛔ slot %d ocupado (%s)" % [slot_idx, owner])
		return

	var card_id: int = int(hand[hand_index])
	var data: Dictionary = CardDB.get_card_data(card_id)
	var t: String = str(data.get("type", "")).to_lower().strip_edges()

	if t == "mana":
		log_output("⛔ carta de mana deve ir para a área de mana")
		return

	var cost: int = int(data.get("cost", 0))
	if !_can_pay_with_untapped_mana(owner, cost):
		log_output("⛔ mana insuficiente (%s): custo=%d (livre=%d)" % [owner, cost, _count_untapped_mana(owner)])
		return

	_tap_mana_to_pay(owner, cost)
	hand.remove_at(hand_index)

	var pos: Vector2 = _get_field_slot_pos(owner, slot_idx)
	var c: Node = cardscene.instantiate()
	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = pos
	c.z_index = 0
	c.z_as_relative = false
	cards_root.add_child(c)

	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = load(str(data["art_path"]))
	c.setup(data)

	c.card_owner = owner
	c.card_slot = "%s_slot_%d" % [owner, slot_idx]
	c.set_exhausted(false)
	c.set_selected(false)
	c.set_meta("summoned_turn", turn_number)

	var has_rush: bool = false
	if c.has_method("has_effect"):
		has_rush = bool(c.call("has_effect", "rush"))

	var lock_now: bool = !has_rush
	if c.has_method("set_cant_attack_lock"):
		c.call("set_cant_attack_lock", lock_now)

	c.card_uid = next_card_uid
	next_card_uid += 1
	cards_by_uid[int(c.card_uid)] = c

	_occupy_field_slot(owner, slot_idx, int(c.card_uid))
	c.set_meta("zone", "field")
	c.clicked.connect(_on_card_clicked)

	if c.has_method("cache_base_transform"):
		c.cache_base_transform()

	log_output("🃏 %s jogou no slot %d (custo=%d)" % [owner, slot_idx, cost])


func _play_mana_from_hand(owner: String, hand_index: int) -> void:
	if LIMIT_MANA_PER_TURN and mana_played_this_turn[owner]:
		log_output("⛔ você já baixou mana neste turno")
		return

	var hand: Array[int] = hand_p1 if owner == "p1" else hand_p2
	if hand_index < 0 or hand_index >= hand.size():
		return
	if mana_line[owner].size() >= MANA_CAPACITY:
		log_output("⛔ limite de mana atingido")
		return

	var card_id: int = int(hand[hand_index])
	var data: Dictionary = CardDB.get_card_data(card_id)
	var t: String = str(data.get("type", "")).to_lower().strip_edges()
	if t != "mana":
		return

	hand.remove_at(hand_index)

	var c: Node = cardscene.instantiate()
	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.z_index = 0
	c.z_as_relative = false
	cards_root.add_child(c)

	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = load(str(data["art_path"]))
	c.setup(data)

	if c.has_method("set_hand_hover"):
		c.set_hand_hover(false)
	if "hitbox" in c and c.hitbox:
		c.hitbox.input_pickable = false

	c.card_owner = owner
	c.card_slot = "mana"
	c.set_exhausted(false)
	c.card_uid = next_card_uid
	next_card_uid += 1
	cards_by_uid[int(c.card_uid)] = c
	c.set_meta("zone", "mana")

	mana_line[owner].append(int(c.card_uid))
	mana_played_this_turn[owner] = true
	_relayout_mana(owner)

	log_output("🔷 %s baixou mana (total=%d)" % [owner, mana_line[owner].size()])


# ============================================================
# ATTACK / COMBAT RULES
# ============================================================
func _can_attack(card: Node) -> bool:
	if card == null or !is_instance_valid(card):
		return false
	if str(card.card_owner) != current_turn:
		return false
	if bool(card.exhausted):
		return false

	var st := int(card.get_meta("summoned_turn", -999999))
	if st == turn_number and !(card.has_method("has_effect") and card.has_effect("rush")):
		return false

	return true


func _on_card_clicked(card: Node) -> void:
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		rpc_id(1, "request_click_field", int(card.card_uid))
		return

	if pending_hand_index != -1:
		_clear_pending_hand_play()

	var zone := ""
	if card.has_meta("zone"):
		zone = str(card.get_meta("zone"))

	if zone == "hero":
		if selected_attacker == null:
			return
		if str(card.card_owner) == current_turn:
			return

		_resolve_attack(selected_attacker, card)
		if is_instance_valid(selected_attacker):
			selected_attacker.set_exhausted(true)
		_clear_selection()
		_update_ui()
		_broadcast_snapshot()
		return

	if zone != "field":
		return

	if selected_attacker == card:
		_clear_selection()
		return

	if selected_attacker == null:
		if !_can_attack(card):
			return
		selected_attacker = card
		card.set_selected(true)
		return

	if str(card.card_owner) == current_turn:
		if !_can_attack(card):
			return
		_clear_selection()
		selected_attacker = card
		card.set_selected(true)
		return

	_resolve_attack(selected_attacker, card)
	if is_instance_valid(selected_attacker):
		selected_attacker.set_exhausted(true)
	_clear_selection()
	_update_ui()
	_broadcast_snapshot()


func _resolve_attack(attacker: Node, defender: Node) -> void:
	if attacker == null or defender == null:
		return
	if !is_instance_valid(attacker) or !is_instance_valid(defender):
		return

	var defender_zone := ""
	if defender.has_meta("zone"):
		defender_zone = str(defender.get_meta("zone"))

	if defender_zone == "hero":
		var dmg: int = max(int(attacker.atk), 0)
		var hero_owner: String = str(defender.card_owner)

		log_output("🛡️ HERO atacado! %s (%d) → Hero de %s | dmg=%d" % [
			str(attacker.card_name), int(attacker.atk), hero_owner, dmg
		])

		if hero_owner == "p1":
			p1_hp = max(p1_hp - dmg, 0)
		else:
			p2_hp = max(p2_hp - dmg, 0)

		_update_ui()
		_broadcast_snapshot()
		return

	var diff: int = int(attacker.atk) - int(defender.def)
	log_output("⚔️ %s (%d) → %s (%d) | diff=%d" % [
		str(attacker.card_name), int(attacker.atk), str(defender.card_name), int(defender.def), diff
	])

	if diff > 0:
		_send_card_to_graveyard(defender)

	_update_ui()
	_broadcast_snapshot()


func _apply_attack_lock_state(card: Node) -> void:
	if card == null or !is_instance_valid(card):
		return
	if !(card.has_meta("zone") and str(card.get_meta("zone")) == "field"):
		return

	if card.has_method("get_cant_attack_lock") and card.has_method("set_cant_attack_lock"):
		card.set_cant_attack_lock(bool(card.get_cant_attack_lock()))


func _enable_attacks_for_owner(owner: String) -> void:
	for c in cards_root.get_children():
		if !is_instance_valid(c):
			continue
		if !(c.has_meta("zone") and str(c.get_meta("zone")) == "field"):
			continue
		if "card_owner" in c and str(c.card_owner) != owner:
			continue
		if c.has_method("set_cant_attack_lock"):
			c.call("set_cant_attack_lock", false)


# ============================================================
# NETWORK — START / JOIN / SIGNALS
# ============================================================
func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(8910, 2)
	if err != OK:
		_set_net_status("host falhou: %s (%s)" % [str(err), error_string(err)])
		log_output("❌ host falhou: %s (%s)" % [str(err), error_string(err)])
		return

	multiplayer.multiplayer_peer = peer
	_wire_multiplayer_signals()
	_set_net_status("host ok ✅ (aguardando player)")
	local_player = "p1"
	hero_choice_p1 = int(Global.my_hero_id)

	deck_p1.clear()
	deck_p2.clear()
	if Global.my_deck.size() == DECK_SIZE:
		deck_p1 = Global.my_deck.duplicate(true)
		log_output("✅ deck p1 carregado do Global (size=%d) first5=%s" % [deck_p1.size(), str(deck_p1.slice(0, 5))])
	else:
		log_output("⚠️ Global.my_deck inválido p1 (size=%d). Vai cair no random depois." % Global.my_deck.size())

	log_output("🟢 host criado (p1)")
	match_started = false
	game_phase = "lobby"
	mulligan_done["p1"] = false
	mulligan_done["p2"] = false

	_clear_all_field_cards_local()
	_clear_all_mana_cards_local()
	_clear_hand_visuals()
	cards_by_uid.clear()
	_reset_field_slots()
	_reset_mana_line()
	hand_p1.clear()
	hand_p2.clear()

	_update_ui()
	log_output("[LOBBY] host pronto. aguardando p2 conectar e enviar loadout")


func _join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, 8910)
	if err != OK:
		_set_net_status("join falhou: %s (%s)" % [str(err), error_string(err)])
		log_output("❌ join falhou: %s (%s)" % [str(err), error_string(err)])
		return

	multiplayer.multiplayer_peer = peer
	_wire_multiplayer_signals()
	_set_net_status("conectando...")
	local_player = "p2"
	log_output("🟡 join em %s" % ip)


func _wire_multiplayer_signals() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _owner_from_sender() -> String:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return local_player
	return "p1" if sender == 1 else "p2"


func _on_connected_to_server() -> void:
	_set_net_status("conectado ✅")
	log_output("🟢 conectado ao host")
	rpc_id(1, "request_snapshot")

	if !multiplayer.is_server():
		var my_deck: Array = _build_my_deck_for_client()
		var my_hero_id: int = Global.my_hero_id
		log_output("[LOBBY] enviando loadout deck=%d hero_id=%d" % [my_deck.size(), my_hero_id])
		rpc_id(1, "request_set_loadout", my_deck, my_hero_id)


func _on_connection_failed() -> void:
	_set_net_status("falha ao conectar ❌")
	log_output("❌ falha ao conectar")


func _on_server_disconnected() -> void:
	_set_net_status("host desconectou ⚠️")
	log_output("⚠️ host desconectou")


func _on_peer_connected(id: int) -> void:
	log_output("🔌 peer conectou: %d" % id)
	if !multiplayer.is_server():
		return

	if match_started:
		rpc_id(id, "apply_snapshot", _build_snapshot())
		return

	log_output("[MULL] aguardando request_set_deck do p2 para iniciar partida")
	rpc_id(id, "apply_snapshot", _build_snapshot())


func _on_peer_disconnected(id: int) -> void:
	log_output("🔌 peer saiu: %d" % id)


func _build_my_deck_for_client() -> Array:
	if Global.my_deck.size() == DECK_SIZE:
		return Global.my_deck.duplicate(true)
	var d: Array = []
	for i in range(DECK_SIZE):
		d.append(randi_range(1, 3))
	return d


# ============================================================
# NETWORK — CLIENT -> HOST RPCS
# ============================================================
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
	_render_hands()
	_broadcast_snapshot()


@rpc("any_peer", "reliable")
func request_play_from_hand_to_slot(hand_index: int, slot_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var sender_owner: String = "p1" if sender == 1 else "p2"
	if sender_owner != current_turn:
		return

	_play_from_hand_to_slot(sender_owner, int(hand_index), int(slot_idx))
	_update_ui()
	_render_hands()
	_broadcast_snapshot()


@rpc("any_peer", "reliable")
func request_play_mana_from_hand(hand_index: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var owner: String = "p1" if sender == 1 else "p2"
	if owner != current_turn:
		return

	_play_mana_from_hand(owner, int(hand_index))
	_update_ui()
	_render_hands()
	_broadcast_snapshot()


@rpc("any_peer", "reliable")
func request_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	rpc_id(sender_id, "apply_snapshot", _build_snapshot())


@rpc("any_peer", "reliable")
func request_keep_hand() -> void:
	if !multiplayer.is_server():
		return
	var owner := _owner_from_sender()
	if game_phase != "mulligan":
		return
	if mulligan_done[owner]:
		return

	mulligan_done[owner] = true
	log_output("✅ %s KEEP" % owner)
	_try_finish_mulligan_and_start()


@rpc("any_peer", "reliable")
func request_mulligan() -> void:
	if !multiplayer.is_server():
		return
	var owner := _owner_from_sender()
	if game_phase != "mulligan":
		return
	if mulligan_done[owner]:
		return

	_perform_mulligan(owner)
	mulligan_done[owner] = true
	log_output("🔁 %s MULLIGAN" % owner)
	_try_finish_mulligan_and_start()


@rpc("any_peer", "reliable")
func request_set_deck(deck_list: Array) -> void:
	if !multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var owner: String = "p1" if sender == 1 else "p2"
	if owner != "p2":
		return

	if deck_list == null or deck_list.size() != DECK_SIZE:
		log_output("⛔ deck inválido do p2 (size=%d)" % (deck_list.size() if deck_list != null else -1))
		return

	deck_p2.clear()
	for x in deck_list:
		deck_p2.append(int(x))

	log_output("✅ deck do p2 recebido (size=%d)" % deck_p2.size())

	if !match_started:
		match_started = true
		mulligan_done["p1"] = false
		mulligan_done["p2"] = false
		current_turn = "p1"
		for i in range(_opening_hand_size("p1")):
			_draw_card("p1")
		for i in range(_opening_hand_size("p2")):
			_draw_card("p2")

		game_phase = "mulligan"
		current_turn = "p1"
		skip_first_turn_draw = true
		log_output("🎲 mãos iniciais compradas. Fase: MULLIGAN (aguardando decisões)")

		_update_ui()
		_render_hands()
		_relayout_all_mana()
		_broadcast_snapshot()
	else:
		_broadcast_snapshot()


@rpc("any_peer", "reliable")
func request_set_loadout(deck_list: Array, hero_id: int) -> void:
	if !multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var owner: String = "p1" if sender == 1 else "p2"
	if owner != "p2":
		return

	if deck_list == null or deck_list.size() != DECK_SIZE:
		log_output("⛔ deck inválido do p2 (size=%d)" % (deck_list.size() if deck_list != null else -1))
		return

	deck_p2.clear()
	for x in deck_list:
		deck_p2.append(int(x))

	hero_choice_p2 = int(hero_id)
	log_output("✅ loadout p2 recebido: deck=%d hero_id=%d" % [deck_p2.size(), hero_choice_p2])

	if !match_started:
		_start_match_from_lobby()
	else:
		_broadcast_snapshot()


func _start_match_from_lobby() -> void:
	match_started = true
	current_turn = "p1"
	skip_first_turn_draw = true

	if deck_p1.is_empty():
		_build_random_deck(deck_p1)

	p1_hp = HERO_MAX_HP
	p2_hp = HERO_MAX_HP

	_spawn_initial_field()

	for i in range(_opening_hand_size("p1")):
		_draw_card("p1")
	for i in range(_opening_hand_size("p2")):
		_draw_card("p2")

	game_phase = "mulligan"
	mulligan_done["p1"] = false
	mulligan_done["p2"] = false

	log_output("🎲 partida iniciada. Fase: MULLIGAN")
	_update_ui()
	_render_hands()
	_relayout_all_mana()
	_render_all_decks()
	_broadcast_snapshot()


# ============================================================
# SNAPSHOT BUILD / BROADCAST / APPLY
# ============================================================
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
	var mana_cards: Array = []
	var sel_uid := -1
	var heroes: Array = []

	for owner in ["p1", "p2"]:
		var uid := int(hero_uid.get(owner, -1))
		var h := get_card_by_uid(uid)
		if h != null:
			heroes.append({
				"uid": int(h.card_uid),
				"owner": str(h.card_owner),
				"card_id": int(h.card_id)
			})

	if selected_attacker != null and is_instance_valid(selected_attacker):
		sel_uid = int(selected_attacker.card_uid)

	for c in cards_root.get_children():
		if not is_instance_valid(c):
			continue
		if not c.has_meta("zone"):
			continue

		var z := str(c.get_meta("zone"))
		if z == "field":
			var st := int(c.get_meta("summoned_turn", -1))
			var ca: bool = false
			if c.has_method("get_cant_attack_lock"):
				ca = bool(c.call("get_cant_attack_lock"))

			field_cards.append({
				"uid": int(c.card_uid),
				"owner": str(c.card_owner),
				"slot": str(c.card_slot),
				"ex": bool(c.exhausted),
				"card_id": int(c.card_id),
				"cant_attack": ca,
				"summoned_turn": st
			})

	for owner in ["p1", "p2"]:
		for i in range(mana_line[owner].size()):
			var uid := int(mana_line[owner][i])
			var m := get_card_by_uid(uid)
			if m == null:
				continue
			mana_cards.append({
				"uid": int(m.card_uid),
				"owner": str(m.card_owner),
				"ex": bool(m.exhausted),
				"card_id": int(m.card_id),
				"order": i
			})

	return {
		"turn": current_turn,
		"turn_number": turn_number,
		"p1_hp": p1_hp,
		"p2_hp": p2_hp,
		"deck_p1": deck_p1,
		"deck_p2": deck_p2,
		"hand_p1": hand_p1,
		"hand_p2": hand_p2,
		"grave_p1": grave_p1,
		"grave_p2": grave_p2,
		"field": field_cards,
		"mana": mana_cards,
		"mana_played_p1": bool(mana_played_this_turn["p1"]),
		"mana_played_p2": bool(mana_played_this_turn["p2"]),
		"phase": game_phase,
		"mull_done_p1": bool(mulligan_done["p1"]),
		"mull_done_p2": bool(mulligan_done["p2"]),
		"selected_uid": sel_uid,
		"heroes": heroes
	}


func _hand_signature() -> String:
	return "%s|%s|%s|%s|%s|%s" % [
		local_player,
		current_turn,
		game_phase,
		str(mulligan_done["p1"]),
		str(mulligan_done["p2"]),
		str(hand_p1) + "/" + str(hand_p2)
	]


func _update_hand_visuals_if_needed() -> void:
	var sig := _hand_signature()
	if sig == _last_hand_sig:
		return
	_last_hand_sig = sig
	_render_hands()


@rpc("authority", "reliable")
func apply_snapshot(snap: Dictionary) -> void:
	_pending_snap = snap
	if _snap_scheduled:
		return
	_snap_scheduled = true
	call_deferred("_apply_pending_snapshot")


func _apply_pending_snapshot() -> void:
	_snap_scheduled = false
	if _pending_snap.is_empty():
		return
	_apply_snapshot_heavy(_pending_snap)
	_pending_snap = {}


@rpc("authority", "reliable")
func _apply_snapshot_heavy(snap: Dictionary) -> void:
	_p2_snap_logged = false
	current_turn = str(snap.get("turn", "p1"))
	turn_number = int(snap.get("turn_number", turn_number))
	p1_hp = int(snap.get("p1_hp", 20))
	p2_hp = int(snap.get("p2_hp", 20))
	hand_p1 = snap.get("hand_p1", []) as Array[int]
	hand_p2 = snap.get("hand_p2", []) as Array[int]
	deck_p1 = snap.get("deck_p1", []) as Array[int]
	deck_p2 = snap.get("deck_p2", []) as Array[int]
	game_phase = str(snap.get("phase", "main"))
	mulligan_done["p1"] = bool(snap.get("mull_done_p1", false))
	mulligan_done["p2"] = bool(snap.get("mull_done_p2", false))
	mana_played_this_turn["p1"] = bool(snap.get("mana_played_p1", false))
	mana_played_this_turn["p2"] = bool(snap.get("mana_played_p2", false))
	grave_p1 = snap.get("grave_p1", []) as Array[int]
	grave_p2 = snap.get("grave_p2", []) as Array[int]

	_update_ui()
	_reset_field_slots()
	_reset_mana_line()

	var alive: Dictionary = {}

	for cd in (snap.get("field", []) as Array):
		var uid := int(cd["uid"])
		alive[uid] = true
		var c := get_card_by_uid(uid)
		if c == null:
			c = _spawn_field_from_cd(cd)
		if local_player == "p2" and !_p2_snap_logged:
			_p2_snap_logged = true
		_update_field_card_from_cd(c, cd)

	var temp := {"p1": [], "p2": []}
	for cd in (snap.get("mana", []) as Array):
		var uid := int(cd["uid"])
		alive[uid] = true
		var m := get_card_by_uid(uid)
		if m == null:
			m = _spawn_mana_from_cd(cd)
		_update_mana_card_from_cd(m, cd)
		temp[str(cd["owner"])].append({"order": int(cd["order"]), "uid": uid})

	for owner in ["p1", "p2"]:
		temp[owner].sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
		mana_line[owner].clear()
		for it in temp[owner]:
			mana_line[owner].append(int(it["uid"]))
		_relayout_mana(owner)

	for hd in (snap.get("heroes", []) as Array):
		var uid_h := int(hd.get("uid", -1))
		if uid_h == -1:
			continue
		alive[uid_h] = true

		var h: Node = get_card_by_uid(uid_h)
		if h == null:
			h = _spawn_hero_from_cd(hd)
		else:
			_update_hero_from_cd(h, hd)

	for uid in cards_by_uid.keys():
		if alive.has(uid):
			continue

		var node: Node = cards_by_uid.get(uid, null)
		if node == null or !is_instance_valid(node):
			cards_by_uid.erase(uid)
			continue

		var z: String = ""
		if node.has_meta("zone"):
			z = str(node.get_meta("zone"))
		if z != "field" and z != "mana":
			continue

		node.queue_free()
		cards_by_uid.erase(uid)

	_update_hand_visuals_if_needed()
	_render_all_grave_tops()
	_render_all_decks()


# ============================================================
# SNAPSHOT SPAWN / UPDATE HELPERS
# ============================================================
func _spawn_hero_from_cd(hd: Dictionary) -> Node:
	var owner: String = str(hd.get("owner", "p1"))
	var uid: int = int(hd.get("uid", -1))
	var card_id: int = int(hd.get("card_id", HERO_CARD_ID))

	var h: Node = cardscene.instantiate()
	h.scale = Vector2(CARD_SCALE, CARD_SCALE)
	h.position = _hero_pos(owner)
	h.z_index = 5
	h.z_as_relative = false
	cards_root.add_child(h)

	var data: Dictionary = CardDB.get_card_data(card_id).duplicate(true)
	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = _get_tex(str(data["art_path"]))
	h.setup(data)

	h.card_owner = owner
	h.card_slot = "hero"
	h.card_uid = uid
	h.set_meta("zone", "hero")
	h.set_exhausted(false)
	h.set_selected(false)
	h.clicked.connect(_on_card_clicked)

	cards_by_uid[uid] = h
	hero_uid[owner] = uid

	if h.has_method("cache_base_transform"):
		h.cache_base_transform()

	return h


func _update_hero_from_cd(h: Node, hd: Dictionary) -> void:
	if h == null or !is_instance_valid(h):
		return
	var owner: String = str(hd.get("owner", "p1"))
	h.set_meta("zone", "hero")
	h.card_owner = owner
	h.card_slot = "hero"
	h.position = _hero_pos(owner)


func _spawn_field_from_cd(cd: Dictionary) -> Node:
	var owner: String = str(cd.get("owner", "p1"))
	var slot_name: String = str(cd.get("slot", "p1_slot_1"))
	var card_id: int = int(cd.get("card_id", -1))
	var uid: int = int(cd.get("uid", -1))

	var idx := _slot_index_from_card_slot(slot_name)
	if idx == -1:
		idx = 1

	var pos: Vector2 = _get_field_slot_pos(owner, idx)
	var c: Node = cardscene.instantiate()
	c.scale = Vector2(CARD_SCALE, CARD_SCALE)
	c.position = pos
	c.z_index = 0
	c.z_as_relative = false
	cards_root.add_child(c)

	var data: Dictionary = CardDB.get_card_data(card_id)
	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = _get_tex(str(data["art_path"])) if has_method("_get_tex") else load(str(data["art_path"]))
	c.setup(data)

	c.card_owner = owner
	c.card_slot = slot_name
	c.card_uid = uid
	c.set_meta("zone", "field")
	c.set_meta("summoned_turn", int(cd.get("summoned_turn", -1)))

	var ca: bool = bool(cd.get("cant_attack", false))
	if c.has_method("set_cant_attack_lock"):
		c.call("set_cant_attack_lock", ca)

	c.clicked.connect(_on_card_clicked)
	cards_by_uid[uid] = c
	_occupy_field_slot(owner, idx, uid)

	if c.has_method("cache_base_transform"):
		c.cache_base_transform()

	return c


func _update_field_card_from_cd(c: Node, cd: Dictionary) -> void:
	if c == null or !is_instance_valid(c):
		return

	var owner: String = str(cd.get("owner", "p1"))
	var slot_name: String = str(cd.get("slot", "p1_slot_1"))
	var ex: bool = bool(cd.get("ex", false))

	c.set_meta("zone", "field")
	if "card_owner" in c:
		c.card_owner = owner
	if "card_slot" in c:
		c.card_slot = slot_name

	var idx := _slot_index_from_card_slot(slot_name)
	if idx == -1:
		idx = 1
	c.position = _get_field_slot_pos(owner, idx)

	if c.has_method("set_exhausted"):
		c.set_exhausted(ex)

	c.set_meta("summoned_turn", int(cd.get("summoned_turn", -1)))

	var ca: bool = bool(cd.get("cant_attack", false))
	if c.has_method("set_cant_attack_lock"):
		c.call("set_cant_attack_lock", ca)

	_occupy_field_slot(owner, idx, int(cd.get("uid", -1)))


func _spawn_mana_from_cd(cd: Dictionary) -> Node:
	var owner: String = str(cd.get("owner", "p1"))
	var card_id: int = int(cd.get("card_id", -1))
	var uid: int = int(cd.get("uid", -1))
	var ex: bool = bool(cd.get("ex", false))

	var m: Node = cardscene.instantiate()
	m.scale = Vector2(CARD_SCALE, CARD_SCALE)
	m.z_index = 0
	m.z_as_relative = false
	cards_root.add_child(m)

	var data: Dictionary = CardDB.get_card_data(card_id)
	data["card_id"] = card_id
	if data.has("art_path"):
		data["art_texture"] = _get_tex(str(data["art_path"]))
	m.setup(data)

	m.card_owner = owner
	m.card_slot = "mana"
	m.card_uid = uid
	m.set_meta("zone", "mana")
	if m.has_method("set_exhausted"):
		m.set_exhausted(ex)
	if m.has_method("set_hand_hover"):
		m.set_hand_hover(false)

	cards_by_uid[uid] = m
	return m


func _update_mana_card_from_cd(m: Node, cd: Dictionary) -> void:
	if m == null or !is_instance_valid(m):
		return
	var owner: String = str(cd.get("owner", "p1"))
	var ex: bool = bool(cd.get("ex", false))

	m.set_meta("zone", "mana")
	if "card_owner" in m:
		m.card_owner = owner
	if "card_slot" in m:
		m.card_slot = "mana"
	if m.has_method("set_exhausted"):
		m.set_exhausted(ex)


# ============================================================
# MISC UTILITIES
# ============================================================
@rpc("authority", "reliable")
func apply_dummy() -> void:
	pass


func _get_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path)
	_tex_cache[path] = t
	return t


func _on_connected_to_server_request_snapshot() -> void:
	rpc_id(1, "request_snapshot")
