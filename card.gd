extends Node2D

signal clicked(card)

@onready var visual: Node2D = $visual
@onready var art: Sprite2D = $visual/art
@onready var frame_slot: Control = $visual/FrameSlot
@onready var hitbox: Area2D = $hitbox

# --------------------------
# Hover/Select tuning
# --------------------------
@export var hover_enabled: bool = true
@export var hover_scale: float = 1.6
@export var selected_scale: float = 1.28
@export var hover_time: float = 0.08
@export var hover_z: int = 9999
@export var hover_on_exhausted: bool = true
@export var hover_lift_y: float = 40.0

@onready var icon_anchor: Marker2D = $visual/icon_anchor
@onready var lock_icon: Sprite2D = $visual/lock_icon


const ART_POS := Vector2(-1, -179.5)
const CARD_BACK_FRAME: Texture2D = preload("res://assets/cards/card_back.png")

# ✅ Frame scene (criaturas por enquanto)
const FRAME_CREATURE_SCN: PackedScene = preload("res://ui/frames/FrameCreature.tscn")
const FRAME_MANA_SCN: PackedScene = preload("res://ui/frames/FrameMana.tscn")
const FRAME_HERO_SCN: PackedScene = preload("res://ui/frames/FrameHero.tscn")

var _born_pos: Vector2 = Vector2.ZERO
var _born_zone: String = "none"

var summoned_turn: int =-1

var cant_attack_lock: bool = false

signal debug_log(msg: String)

func _log(msg: String) -> void:
	emit_signal("debug_log", msg)
# --------------------------
# Card data
# --------------------------
var card_name := "card"
var cost := 0
var card_type := ""
var rules := ""
var atk := 0
var def := 0
var card_owner: String = "p1"

var exhausted: bool = false
var card_uid: int = -1
var card_id: int = -1
var card_slot: String = ""

var effects: Array = []

# --------------------------
# Cached transform / state
# --------------------------
var _base_scale: Vector2
var _base_pos: Vector2
var _base_z: int

var _hover_z_index: int = 800
var _base_parent: Node = null
var _base_child_index: int = -1

var _tw: Tween
var _is_hovered := false
var _selected := false

# Frame instance atual (plugável)
var _frame_inst: Node2D = null

# Glow (shader)
var _glow_mat: ShaderMaterial
var _frame_frame_node: Node = null # pode ser Sprite2D ou TextureRect

func _ready() -> void:
	_born_pos = position
	_born_zone = str(get_meta("zone")) if has_meta("zone") else "none"


	# Se nascer em 0,0, imprime stack pra saber o caminho (em debug funciona bem)

	
	if lock_icon and icon_anchor:
		lock_icon.position = icon_anchor.position
		lock_icon.visible = false
	
	art.position = ART_POS

	# clique/hover via hitbox
	hitbox.clicked.connect(_on_hitbox_clicked)
	hitbox.mouse_entered.connect(_on_hitbox_mouse_entered)
	hitbox.mouse_exited.connect(_on_hitbox_mouse_exited)

	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = load("res://shaders/outline_glow.gdshader")

	cache_base_transform()

	# Cria frame default (pra não ficar vazio ao instanciar)
	_set_frame_by_type("creature")
	
	_apply_frame_glow_material()
	set_selected_visual(false)

	update_ui()


# =========================================================
# CHAME ISSO no Main DEPOIS de setar position/scale/z_index
# =========================================================
func cache_base_transform() -> void:
	_base_scale = scale
	_base_pos = position
	_base_z = z_index
	
	var zone := str(get_meta("zone")) if has_meta("zone") else "none"

	
	_base_parent = get_parent()
	if _base_parent != null:
		_base_child_index = _base_parent.get_children().find(self)
	else:
		_base_child_index = -1


# =========================================================
# Setup card visuals/data
# - Se card_id == -1 => modo "verso"
# =========================================================
func setup(data: Dictionary) -> void:
	card_id = int(data.get("card_id", -1))

	if data.has("name"): card_name = str(data["name"])
	if data.has("cost"): cost = int(data["cost"])
	if data.has("type"): card_type = str(data["type"])
	if data.has("rules"): rules = str(data["rules"])
	if data.has("atk"): atk = int(data["atk"])
	if data.has("def"): def = int(data["def"])
	if data.has("effects"): effects = data.get("effects", [])

	if data.has("art_texture") and data["art_texture"] != null:
		art.texture = data["art_texture"]
	
	


	var is_back: bool = (card_id == -1)

	art.visible = not is_back

	if is_back:
		_set_back_frame()
	else:
		var fp := str(data.get("frame_path", "")).strip_edges()
		var label_color: Color = _color_from_any(data.get("label_color", [0,0,0,1]))
		_set_frame_by_type(card_type if card_type != "" else "creature", fp, label_color)
		#var label_color_2 := Color([1,1,1,1])
		
		update_ui()

func _color_from_any(v, fallback: Color = Color(1,1,1,1)) -> Color:
	if v is Color:
		return v

	if v is Array:
		var a := v as Array
		if a.size() >= 3:
			var r := float(a[0])
			var g := float(a[1])
			var b := float(a[2])
			var al := float(a[3]) if a.size() >= 4 else 1.0
			return Color(r, g, b, al)
		return fallback

	if v is String:
		# aceita "#RRGGBB" ou "#RRGGBBAA"
		return Color(v)

	return fallback
	
func update_ui() -> void:
	# Se tiver frame instanciado e ele aceitar apply_data, manda tudo pra ele
	if _frame_inst and is_instance_valid(_frame_inst) and _frame_inst.has_method("apply_data"):
		_frame_inst.apply_data({
			"name": card_name,
			"cost": cost,
			"type": card_type,
			"rules": rules,
			"atk": atk,
			"def": def,
		})


# =========================================================
# Frame management (plugável)
# =========================================================
func _clear_frame_slot() -> void:
	for c in frame_slot.get_children():
		c.queue_free()
	_frame_inst = null
	_frame_frame_node = null


func _set_frame_by_type(t: String,frame_path: String = "",label_color: Color = Color(1,1,1,1)) -> void:
	_clear_frame_slot()

	var tt := t.to_lower().strip_edges()

	if tt == "mana":
		_frame_inst = FRAME_MANA_SCN.instantiate()
	elif tt == "hero":
		_frame_inst = FRAME_HERO_SCN.instantiate()
	else:
		_frame_inst = FRAME_CREATURE_SCN.instantiate()

	frame_slot.add_child(_frame_inst)
	# garante que o FrameUI (Control) preenche o FrameSlot (Control)
	
	#if ui and ui is Control:
	#	print("FrameUI size=", (ui as Control).size, " pos=", (ui as Control).position)
	
	_disable_mouse_recursively(_frame_inst)

	# ✅ agora pode ser Sprite2D OU TextureRect
	_frame_frame_node = _frame_inst.get_node_or_null("FrameUI/Frame")
	_apply_frame_glow_material()
	
		# ✅ opcional: trocar textura do frame via CardDB (ex: heróis diferentes)
	# ✅ troca textura se veio frame_path
	

	if _frame_frame_node and frame_path.strip_edges() != "":
		_set_frame_texture(frame_path)
	
	# ✅ só labels específicos (você escolhe quais)
	_apply_selected_labels_color(label_color)
	
	
	
func _apply_selected_labels_color(font_color: Color) -> void:
	if _frame_inst == null or !is_instance_valid(_frame_inst):
		return

	# ✅ coloque aqui os labels que você quer tingir
	var label_paths: Array[String] = [
		"control/name",
		"control/cost",
		"control/type",
		
	]

	for p in label_paths:
		var n := _frame_inst.get_node_or_null(p)
		if n == null:
			# ajuda a achar path errado sem quebrar nada
			print("⚠️ label não encontrado:", p, " (frame=", _frame_inst.name, ")")
			continue
		if n is Label:
			(n as Label).add_theme_color_override("font_color", font_color)
		else:
			print("⚠️ node não é Label:", p, " class=", n.get_class())
	


func _set_frame_texture(path: String) -> void:
	if _frame_frame_node == null or !is_instance_valid(_frame_frame_node):
		return
	var tex := load(path)
	if !(tex is Texture2D):
		return

	if _frame_frame_node is Sprite2D:
		(_frame_frame_node as Sprite2D).texture = tex
	elif _frame_frame_node is TextureRect:
		(_frame_frame_node as TextureRect).texture = tex
		
func _set_back_frame() -> void:
	_clear_frame_slot()

	# cria um TextureRect (fica perfeito com “full rect” se seu frame scene for Control)
	var back := TextureRect.new()
	back.name = "frame"
	back.texture = CARD_BACK_FRAME
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	frame_slot.add_child(back)

	_frame_frame_node = back
	_apply_frame_glow_material()
	set_selected_visual(false)


func _apply_frame_glow_material() -> void:
	if _frame_frame_node == null or !is_instance_valid(_frame_frame_node):
		return

	# Sprite2D
	if _frame_frame_node is Sprite2D:
		(_frame_frame_node as Sprite2D).material = _glow_mat
		return

	# TextureRect
	if _frame_frame_node is TextureRect:
		# Godot 4 geralmente aceita 'material' em CanvasItem
		(_frame_frame_node as TextureRect).material = _glow_mat
		return


func _disable_mouse_recursively(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_disable_mouse_recursively(ch)


# =========================================================
# CLICK
# =========================================================
func _on_hitbox_clicked() -> void:
	emit_signal("clicked", self)


# =========================================================
# HOVER (automático pelo hitbox) - campo/deck
# =========================================================
func _on_hitbox_mouse_entered() -> void:
	
	_log("[HOVER_ENTER] uid=" + str(card_uid)
		+ " zone=" + (str(get_meta("zone")) if has_meta("zone") else "none")
		+ " hover_enabled=" + str(hover_enabled)
		+ " exhausted=" + str(exhausted)
		+ " selected=" + str(_selected)
		+ " is_hovered=" + str(_is_hovered)
	)
	print("1")
	print("THUMB CONFIG hover_enabled=", hover_enabled, 
	  " scale=", _base_scale," is hovered =", _is_hovered)
	#_log("[CALL] mouse_enter uid=" + str(card_uid) + " zone=" + str(get_meta("zone")))
	if not hover_enabled: return
	print("2")
	if exhausted and not hover_on_exhausted: return
	print("3")
	if _selected: return
	print("4")
	if _is_hovered: return
	print("5")

	_is_hovered = true
	z_index = _hover_z_index

	_tween_move_and_scale(
		_base_pos + Vector2(0, -hover_lift_y),
		_base_scale * hover_scale
	)
	


func _on_hitbox_mouse_exited() -> void:

	_log("[HOVER_EXIT] uid=" + str(card_uid)
		+ " zone=" + (str(get_meta("zone")) if has_meta("zone") else "none")
	)

	if not hover_enabled: return
	if _selected: return
	if not _is_hovered: return

	_is_hovered = false
	_tween_move_and_scale(_base_pos, _base_scale)
	z_index = _base_z



# =========================================================
# HOVER CONTROLADO PELO MAIN (mão sobreposta)
# =========================================================
func set_hand_hover(on: bool) -> void:
	_log("[CALL] set_hand_hover(" + str(on) + ") uid=" + str(card_uid) + " zone=" + str(get_meta("zone")))

	if not hover_enabled:
		return
	if exhausted and not hover_on_exhausted:
		return
	if _selected:
		return

	if on:
		if _is_hovered:
			return
		_is_hovered = true

		z_index = _hover_z_index
		if get_parent() != null:
			get_parent().move_child(self, get_parent().get_child_count() - 1)
		
		_tween_move_and_scale(
			_base_pos + Vector2(0, -hover_lift_y),
			_base_scale * hover_scale
		)

	else:
		if not _is_hovered:
			return
		_is_hovered = false

		_tween_move_and_scale(_base_pos, _base_scale)

		z_index = _base_z

		if _base_parent != null and is_instance_valid(_base_parent) and _base_child_index >= 0:
			_base_parent.move_child(self, clamp(_base_child_index, 0, _base_parent.get_child_count() - 1))


# =========================================================
# Tween helpers
# =========================================================
func _tween_move_and_scale(target_pos: Vector2, target_scale: Vector2) -> void:
	var zone := str(get_meta("zone")) if has_meta("zone") else "none"



	
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_trans(Tween.TRANS_QUAD)
	_tw.set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", target_pos, hover_time)
	_tw.parallel().tween_property(self, "scale", target_scale, hover_time)


func _restore_z_after() -> void:
	

	if has_meta("zone") and str(get_meta("zone")) == "hand":
		return
	if _tw and _tw.is_valid():
		_tw.finished.connect(func(): z_index = _base_z)
	else:
		z_index = _base_z


# =========================================================
# SELECT (usado no ataque)
# =========================================================
func set_selected(on: bool) -> void:
	

	_selected = on

	if _frame_frame_node and is_instance_valid(_frame_frame_node):
		if _frame_frame_node is CanvasItem:
			(_frame_frame_node as CanvasItem).modulate = Color(1.25, 1.25, 1.25, 1) if on else Color(1, 1, 1, 1)

	if on:
		_is_hovered = false
		z_index = _hover_z_index
		_tween_move_and_scale(_base_pos + Vector2(0, -hover_lift_y), _base_scale * selected_scale)
	else:
		_tween_move_and_scale(_base_pos, _base_scale)
		_restore_z_after()


# =========================================================
# EXHAUSTED
# =========================================================
func set_exhausted(on: bool) -> void:
	exhausted = on

	var zone := ""
	if has_meta("zone"):
		zone = str(get_meta("zone"))

	# Mana: tap suave (25° + alpha)
	if zone == "mana":
		rotation_degrees = 25.0 if on else 0.0
		modulate.a = 0.55 if on else 1.0
	else:
		# Campo: mantém 90° como estava
		rotation_degrees = 90.0 if on else 0.0
		modulate.a = 1.0

	if on and not hover_on_exhausted:
		force_unhover()


func force_unhover() -> void:
	

	if _selected:
		return
	_is_hovered = false
	if _tw and _tw.is_valid():
		_tw.kill()
	scale = _base_scale
	position = _base_pos
	z_index = _base_z


# =========================================================
# VISUAL: glow (seleção da mão / etc)
# =========================================================
func set_selected_visual(on: bool) -> void:
	if !_glow_mat:
		return
	_glow_mat.set_shader_parameter("intensity", 1.0 if on else 0.0)
	_glow_mat.set_shader_parameter("thickness", 20.0)
	_glow_mat.set_shader_parameter("alpha", 0.9)
	_glow_mat.set_shader_parameter("glow_color", Color(0.35, 0.85, 1.0))


func has_effect(id: String) -> bool:
	for e in effects:
		if typeof(e) == TYPE_STRING and e == id:
			return true
		if typeof(e) == TYPE_DICTIONARY and e.get("id", "") == id:
			return true
	return false
	
	
func set_cant_attack_lock(on: bool) -> void:
	if lock_icon:
		lock_icon.visible = on
		cant_attack_lock = on

func get_cant_attack_lock() -> bool:
	return cant_attack_lock
