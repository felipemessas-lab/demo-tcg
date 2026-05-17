extends Control
"""
CardThumb:
- É um Control (UI) para o GridContainer conseguir organizar (layout)
- Renderiza a card.tscn (Node2D) dentro de um SubViewport
- Emite signal pressed(card_id) quando clicar
"""

const CardDB = preload("res://scripts/card_db.gd")
const CARD_SCN: PackedScene = preload("res://card.tscn")

@export var thumb_scale: float = 0.18
@export var allow_card_hover: bool = false

@onready var world: Node2D = $View/SubViewport/World
@onready var btn: Button = $Click

signal pressed(card_id: int)
signal hovered(card_id: int)

var card_id: int = -1
var _card: Node = null

@export var debug_click_rect: bool = true
@export var debug_ui: bool = true

@export var library_hover_zoom := 1.45
@export var library_hover_lift_y := 20.0

@onready var glow: Panel = $View/SubViewport/Glow




			
func _ready() -> void:
	# btn.pressed.connect(func(): emit_signal("pressed", card_id))
	#_debug_sizes()
	btn.pressed.connect(func():
		print("[THUMB] pressed card_id=", card_id, " node=", name)
		emit_signal("pressed", card_id)
	)
	
	btn.mouse_entered.connect(func():
		emit_signal("hovered", card_id)
		#print("[THUMB] mouse entered card_id=", card_id, " node=", name)
		#call_deferred("_dbg_print_rects") # espera layout acontecer
		# efeito visual leve
		modulate = Color(1.06, 1.06, 1.06, 1.0)
	)
	btn.mouse_exited.connect(func():
		modulate = Color(1, 1, 1, 1)
	)
	set_glow_visible(true)
	
	


	# conecta uma vez só
	

	# opcional: tira o efeito visual do botão


func set_glow_visible(v: bool) -> void:
	if glow:
		glow.visible = v

func set_card(id: int, size_adj: float, face_down: bool = false ) -> void:
	"""
	Instancia uma card.tscn no SubViewport e configura com CardDB.
	"""
	
		# ✅ garante que @onready já rodou
	if world == null:
		# tenta resolver path de novo (caso set_card tenha sido chamado antes do ready)
		world = get_node_or_null("View/SubViewport/World") as Node2D
		if world == null:
			# último recurso: espera 1 frame e tenta novamente
			await get_tree().process_frame
			world = get_node_or_null("View/SubViewport/World") as Node2D
			if world == null:
				push_error("CardThumb: World não encontrado em View/SubViewport/World")
				return

	
		# --- tamanho base (sem deflator) ---
	var view := $View as SubViewportContainer
	var sv := $View/SubViewport as SubViewport
	var base_vp: Vector2 = Vector2(sv.size) # tamanho “nominal” do subviewport

	# --- tamanho final do thumb (deflado) ---
	var vp_def: Vector2 = base_vp * size_adj
	
	# 1) faz o item do grid (CardThumb) encolher (área branca/clique)
	custom_minimum_size = vp_def
	size = vp_def

	# 2) faz o container do viewport encolher (borda branca)
	view.custom_minimum_size = vp_def
	view.size = vp_def
	$View.position = (size - vp_def) * 0.5
	

	# 3) faz o render encolher
	sv.size = Vector2i(vp_def)

	# 4) se o Click é quem captura mouse, ele precisa encolher também
	var click := get_node_or_null("Click") as Control
	if click:
		click.custom_minimum_size = vp_def
		click.size = vp_def
	
	card_id = id
	if card_id == -1:
		return
	#_dbg_thumb_state("BEFORE_CLEAR")
	_clear()
	#_dbg_thumb_state("AFTER_CLEAR")
	# instancia a carta
	_card = CARD_SCN.instantiate() as Node2D
	world.add_child(_card)

	# agora o fit usa o vp_def (sem aplicar deflator de novo)
	_apply_card_fit_to_viewport(_card, Vector2i(vp_def), 1.0)
	_card.cache_base_transform()


	

	# MUITO importante: recache da base DEPOIS de setar pos/scale
	# (senão o card.gd pode “voltar” para 256,384 em hover/restore)
	if _card.has_method("cache_base_transform"):
		_card.cache_base_transform()
	
	# posiciona no centro do viewport (512x768)


	
	
	_card.z_as_relative = false
	_card.z_index = 0

	# MUITO IMPORTANTE:
	# desliga hover/zoom do card dentro do thumbnail
	# (senão a carta "voa" dentro do viewport ao passar o mouse)
	if "hover_enabled" in _card:
		_card.hover_enabled = allow_card_hover

	# também evita que o hitbox da carta "roube" o mouse da UI
	# (o clique do Thumb é no Button por cima)
	if "hitbox" in _card and _card.hitbox:
		_card.hitbox.monitoring = false
		_card.hitbox.monitorable = false
		_card.hitbox.input_pickable = false

	# monta data e chama setup igual no main
	if face_down:
		_card.setup({
			"card_id": -1,
			"art_texture": null
		})
	else:
		var data: Dictionary = CardDB.get_card_data(card_id).duplicate(true)
		data["card_id"] = card_id
		if data.has("art_path"):
			data["art_texture"] = load(str(data["art_path"]))
		_card.setup(data)

	# cache base (não é obrigatório aqui, mas mantém consistente)
	if _card.has_method("cache_base_transform"):
		_card.cache_base_transform()

	
	#_dbg_thumb_state("AFTER_CLEAR")

func _clear() -> void:
	if world == null or !is_instance_valid(world):
		# ainda não pronto (ou cena diferente): não faz nada
		return
	for c in world.get_children():
		c.queue_free()
	_card = null


func _dbg_rect(label: String, n: Node) -> void:
	if n == null:
		print("[THUMB RECT] ", label, "=NULL")
		return

	if n is Control:
		var c := n as Control
		print("[THUMB RECT] ", label,
			" type=Control",
			" size=", c.size,
			" global_rect=", c.get_global_rect()
		)
	else:
		# Node2D / outros não tem get_global_rect
		print("[THUMB RECT] ", label,
			" type=", n.get_class(),
			" (sem get_global_rect)",
			" pos=", (n as Node2D).global_position if n is Node2D else "(?)"
		)

func _apply_card_fit_to_viewport(card: Node2D, vp_size: Vector2i, deflactor: float) -> void:
	var cs := card.get_node_or_null("hitbox/collisionshape2d") as CollisionShape2D
	if cs == null or cs.shape == null:
		push_warning("CardThumb: não achei hitbox/collisionshape2d (ou shape null)")
		return

	var base_size: Vector2 = Vector2.ZERO

	# RectangleShape2D (mais comum)
	if cs.shape is RectangleShape2D:
		base_size = (cs.shape as RectangleShape2D).size
	else:
		push_warning("CardThumb: shape não suportado: " + cs.shape.get_class())
		return

	if base_size.x <= 0.0 or base_size.y <= 0.0:
		push_warning("CardThumb: base_size inválido via CollisionShape2D")
		return

	var sx: float = float(vp_size.x) / base_size.x
	var sy: float = float(vp_size.y) / base_size.y
	var s: float = deflactor * minf(sx, sy)
	

	
	card.scale = Vector2(s, s)
	card.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.5)
	

	
	# Se a CollisionShape estiver deslocada, descomente:
	# card.position -= cs.position * s


func _dbg_thumb_state(tag: String) -> void:
	if !debug_ui:
		return

	var view := get_node_or_null("View") as Control
	var sv := get_node_or_null("View/SubViewport") as SubViewport
	var world := get_node_or_null("View/SubViewport/World") as Node2D

	print("---- [THUMB DBG ", tag, "] ----")
	_dbg_rect("ROOT", self)
	_dbg_rect("VIEW", view)
	if sv:
		print("[THUMB DBG] SUBVP size=", sv.size)
	else:
		print("[THUMB DBG] SUBVP = NULL")
	if world:
		print("[THUMB DBG] WORLD global_pos=", world.global_position)
	else:
		print("[THUMB DBG] WORLD = NULL")

	if _card and is_instance_valid(_card):
		print("[THUMB DBG] CARD local_pos=", _card.position,
			" global_pos=", (_card as Node2D).global_position,
			" scale=", (_card as Node2D).scale
		)
	else:
		print("[THUMB DBG] CARD = NULL")
		
		



func _dbg_print_rects() -> void:
	# 1 frame depois, o GridContainer/Scroll já calculou sizes
	await get_tree().process_frame

	if btn == null:
		push_warning("[THUMB DBG] btn é null")
		return

	# Root do CardThumb (Control)
	var r_thumb: Rect2 = get_global_rect()
	var r_btn: Rect2 = btn.get_global_rect()

	print("[THUMB DBG] node=", self, " thumb size=", size, " rect=", r_thumb)
	print("[THUMB DBG] node=", self, " BTN   size=", btn.size, " rect=", r_btn)

	# Se quiser comparar com o View também:
	#var view := get_node_or_null("View")
	#if view and view is Control:
		#print("[THUMB DBG] node=", self, " VIEW  size=", (view as Control).size, " rect=", (view as Control).get_global_rect())


func _debug_sizes():
	var sprite := $visual/art # ajuste o path se precisar
	var shape := $Area2D/CollisionShape2D.shape as RectangleShape2D

	if sprite.texture == null:
		print("❌ Sprite sem textura")
		return

	var tex_size: Vector2 = sprite.texture.get_size()
	var visual_size: Vector2 = tex_size * sprite.scale
	var collision_size: Vector2 = (shape.size if shape != null else Vector2.ZERO)

	print("------ CARD DEBUG ------")
	print("Texture size: ", tex_size)
	print("Sprite scale: ", sprite.scale)
	print("Visual size (texture * scale): ", visual_size)
	print("Collision size: ", collision_size)
	print("------------------------")
