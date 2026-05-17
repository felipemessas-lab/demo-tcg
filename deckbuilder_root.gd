extends Node2D
"""
DeckBuilder (Node2D raiz) - versão com THUMB (CardThumb.tscn)

O que faz:
1) Renderiza uma "Library" de cartas (esquerda) como miniaturas (CardThumb)
2) Renderiza o "Deck" (direita) como 20 slots de miniaturas
3) Clique na Library -> adiciona carta no deck
4) Clique no Deck -> remove aquela carta do slot
5) Host/Join -> salva no Global e troca para main.tscn
   (o main.gd deve auto-host/auto-join baseado em Global.auto_net_mode)
"""

# ---------------------------------------------------------
# Dependências / Constantes
# ---------------------------------------------------------
const CardDB = preload("res://scripts/card_db.gd")

# Cena wrapper (Control) que renderiza a card.tscn dentro de SubViewport
const THUMB_SCN: PackedScene = preload("res://cardthumb.tscn")

const DECK_SIZE: int = 20

# Ajustes visuais (você pode mexer depois)
const THUMB_SCALE_LIBRARY: float = 0.05
const THUMB_SCALE_DECK: float = 0.05

const COPIES_PER_CARD: int = 10
var collection_count: Dictionary = {} # card_id -> qty disponível

const DECKS_DIR := "user://decks"

var current_deck_name: String = ""

# ---------------------------------------------------------
# Referências da Cena (paths conforme seu print)
# ---------------------------------------------------------
@onready var grid_library: GridContainer = $Control/TextureRect_Library/ScrollContainer/GridLibrary
@onready var grid_deck: GridContainer = $Control/TextureRect_Deck/ScrollContainer/GridDeck

@onready var btn_play: Button = $btnplay
@onready var btn_save: Button = $btnsave
@onready var btn_load: Button = $btnload
@onready var btn_new: Button = $btnnew
@onready var btn_delete: Button = $btndelete
@onready var decks_popup: PopupMenu = $deckspopup
@onready var deck_name: LineEdit = $deck_name# opcional

@onready var deck_count_label: Label = $deck_count_label

@onready var botao_debug: Button = $botao_debug

# ---------------------------------------------------------
# Estado
# ---------------------------------------------------------
var available_ids: Array[int] = []   # pool da library
var deck: Array[int] = []            # deck montado (card_id)
var hero_id_choice: int = -1

func _ready() -> void:
	randomize()

	# 1) Carrega deck salvo (ou cria um default)
	Global.set_default_deck_if_empty()
	deck = Global.my_deck.duplicate(true)
	print("[DECKBUILDER] Global.my_deck size=", Global.my_deck.size())
	print("[DECKBUILDER] deck size=", deck.size(), " sample=", deck.slice(0, min(deck.size(), 10)))


	# 2) Preenche IP com o último usado


	# 3) Define o pool de cartas (placeholder: 1..30)
	available_ids = _build_available_ids()
	
	# inicializa "coleção" com 10 de cada carta
	collection_count.clear()
	for id in available_ids:
		collection_count[int(id)] = COPIES_PER_CARD

	# desconta o que já está no deck carregado do Global
	for cid in deck:
		var id := int(cid)
		if collection_count.has(id):
			collection_count[id] = max(int(collection_count[id]) - 1, 0)

	# 4) Render inicial
	_render_library()
	_render_deck()
	
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)

	# 5) Conecta botões

	
	print("[UI] script rodando em: ", get_path())

	_dbg_rect(^"Control", "Control")
	_dbg_rect(^"Control/TextureRect_Deck", "DeckTR")
	_dbg_rect(^"Control/TextureRect_Deck/ScrollContainer", "DeckScroll")
	_dbg_rect(^"Control/TextureRect_Deck/ScrollContainer/GridDeck", "GridDeck")

	_dbg_rect(^"Control/TextureRect_Library/ScrollContainer/GridLibrary", "GridLibrary")
	
	await get_tree().process_frame
	print("[UI 1F] Control size=", $Control.size)
	print("[UI 1F] DeckScroll size=", $Control/TextureRect_Deck/ScrollContainer.size)
	print("[UI 1F] GridDeck size=", grid_deck.size)
	print("[UI 1F] GridLibrary size=", grid_library.size)
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_new.pressed.connect(_on_new_pressed)
	btn_delete.pressed.connect(_on_delete_pressed)
	decks_popup.id_pressed.connect(_on_deck_popup_item)
	botao_debug.pressed.connect(_on_botao_debug_pressed)
	
func _on_botao_debug_pressed():
	# escolha aqui QUAL card você quer inspecionar
	var card = grid_library

	if card == null:
		print("Card não encontrado!")
		return
	print("\n========== DEBUG TREE ==========")
	_print_tree_recursive(card, 0)
 	#print("========== END DEBUG ==========\n")

func _print_tree_recursive(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var info := ""
	if node is Control:
		info += " size=" + str(node.size)
	
	if node is Node2D:
		info += " scale=" + str(node.scale)


	


func _dbg_rect(path: NodePath, label: String) -> void:
	var n := get_node_or_null(path)
	if n == null:
		print("[UI] ", label, " = NULL  path=", path, "   (script em ", get_path(), ")")
		return
	if n is Control:
		var c := n as Control
		print("[UI] ", label, " rect=", c.get_global_rect(), " size=", c.size)
	else:
		print("[UI] ", label, " type=", n.get_class(), " (não tem get_global_rect)")

# =========================================================
# Pool de cartas (Library)
# =========================================================
func _build_available_ids() -> Array[int]:
	"""
	Define quais cartas aparecem na Library.
	Agora está como range 1..30.
	Depois podemos:
	- pegar do CardDB (se tiver uma lista)
	- ou filtrar por tipo
	"""
	var ids: Array[int] = []
	for i in range(1, 6):
		ids.append(i)
	return ids


# =========================================================
# Render: Library (esquerda)
# =========================================================
func _render_library_old() -> void:
	"""
	Cria um CardThumb para cada card_id disponível.
	Clique no thumb -> adiciona no deck.
	"""
	_clear_children(grid_library)
	var size_adj_library: float = 0.8
	for id in available_ids:
		var thumb: Control = THUMB_SCN.instantiate()

		# configura thumb (API do CardThumb.gd)
		thumb.thumb_scale = THUMB_SCALE_LIBRARY
		thumb.allow_card_hover = false
		

		# clique no thumb adiciona
		var captured_id := id
		thumb.pressed.connect(func(_cid: int):
			print("[DECKBUILDER RECEBEU] id=", _cid, " thumb=", thumb.get_path())
			_add_to_deck(captured_id)
		)

		grid_library.add_child(thumb)
		thumb.set_card(id,size_adj_library ,false)
	
func _render_library() -> void:
	_clear_children(grid_library)
	var size_adj_library: float = 0.8

	for id in available_ids:
		var card_id := int(id)
		var qty: int = int(collection_count.get(card_id, 0))

		var thumb: Control = THUMB_SCN.instantiate()
		thumb.thumb_scale = THUMB_SCALE_LIBRARY
		thumb.allow_card_hover = false
		grid_library.add_child(thumb)

		thumb.set_card(card_id, size_adj_library, false)
		_ensure_thumb_count_badge(thumb, qty)

		# se acabou, desabilita click
		var click_btn := thumb.get_node_or_null("Click")
		if click_btn and click_btn is Button:
			(click_btn as Button).disabled = (qty <= 0)

		var captured_id := card_id
		thumb.pressed.connect(func(_cid: int):
			_add_to_deck(captured_id)
		)

# =========================================================
# Render: Deck (direita)
# =========================================================
func _render_deck() -> void:
	_clear_children(grid_deck)

	var counts: Dictionary = {}
	for x in deck:
		var id := int(x)
		counts[id] = int(counts.get(id, 0)) + 1

	# --- cria uma lista ordenada de ids (pra UI ficar estável) ---
	var ids: Array[int] = []
	for k in counts.keys():
		ids.append(int(k))

	# ✅ adiciona herói na lista de ids (se tiver)
	if hero_id_choice != -1:
		ids.append(int(hero_id_choice))

	ids.sort()
	if hero_id_choice != -1:
		ids.erase(hero_id_choice)
		ids.insert(0, hero_id_choice)

	var size_adj_deck: float = 0.6

	# --- renderiza 1 thumb por carta (com badge xN) ---
	for card_id in ids:

		var is_hero := (hero_id_choice != -1 and int(card_id) == int(hero_id_choice))
		var qty: int = 1 if is_hero else int(counts.get(card_id, 0))

		var thumb: Control = THUMB_SCN.instantiate()
		thumb.thumb_scale = THUMB_SCALE_DECK
		thumb.allow_card_hover = false
		grid_deck.add_child(thumb)

		thumb.set_card(int(card_id), size_adj_deck, false)
		
		if is_hero:
			thumb.set_glow_visible(true)
			print("teste_3")
		else:
			thumb.set_glow_visible(false)
		
		# ✅ badge só para cartas normais (ou deixe para herói se quiser)
		if !is_hero:
			_ensure_thumb_count_badge(thumb, qty)
			thumb.set_glow_visible(false)
			
		else:
			# opcional: garantir que não aparece badge antigo
			# (se seu thumb recicla nodes internamente)
			_remove_thumb_count_badge_if_exists(thumb) # se não tiver, pode apagar essa linha	
			thumb.set_glow_visible(true)	
			
			print("teste_2")
		

		var captured_id := int(card_id)

		thumb.pressed.connect(func(_cid: int):
			if hero_id_choice != -1 and captured_id == int(hero_id_choice):
				# ✅ remove herói
				hero_id_choice = -1

				# ✅ devolve 1 cópia pra library
				if collection_count.has(captured_id):
					collection_count[captured_id] = int(collection_count[captured_id]) + 1

			else:
				# ✅ remove 1 cópia normal
				var idx := deck.find(captured_id)
				if idx != -1:
					deck.remove_at(idx)

					# ✅ devolve 1 cópia pra library
					if collection_count.has(captured_id):
						collection_count[captured_id] = int(collection_count[captured_id]) + 1

			_sync_global_deck()
			_render_deck()
			_render_library()
			_update_deck_counter()
		)
	
	_sync_global_deck()

func _remove_thumb_count_badge_if_exists(thumb: Node) -> void:
	var b := thumb.get_node_or_null("CountBadge")
	if b:
		b.queue_free()

func _ensure_thumb_count_badge(thumb: Control, qty: int) -> void:
	# Cria/atualiza um Label "xN" no canto do thumb
	var badge := thumb.get_node_or_null("CountBadge")
	if badge == null:
		var l := Label.new()
		l.name = "CountBadge"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

		# ocupa a área toda do thumb pra ancorar no canto
		l.anchor_left = 1.0
		l.anchor_top = 0.0
		l.anchor_right = 0.0
		l.anchor_bottom = 1.0
		
		l.offset_left = 6.0
		l.offset_top = 0.0
		l.offset_right = 0.0
		l.offset_bottom = -4.0

		# opcional: deixa mais legível (Godot 4)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)

		thumb.add_child(l)
		badge = l

	(badge as Label).text = "x%d" % qty
	(badge as Label).visible = qty >=0


# =========================================================
# Ações: adicionar/remover deck
# =========================================================
func _add_to_deck(card_id: int) -> void:
	if deck.size() >= DECK_SIZE:
		print("[DECKBUILDER] deck cheio (%d/%d)" % [deck.size(), DECK_SIZE])
		return

	# ✅ regra: só 1 herói no deck
	var data: Dictionary = CardDB.get_card_data(card_id)
	var t := str(data.get("type", "")).to_lower().strip_edges()

	if t == "hero":
		if hero_id_choice != -1:
			print("[DECKBUILDER] só pode ter 1 herói no deck")
			return
		 
			
			#var d2: Dictionary = CardDB.get_card_data(int(cid))
			#var t2 := str(d2.get("type", "")).to_lower().strip_edges()
			#if t2 == "hero":
			#	print("[DECKBUILDER] só pode ter 1 herói no deck")
			#	return
	
	var qty: int = int(collection_count.get(card_id, 0))
	if qty <= 0:
		print("[DECKBUILDER] sem cópias disponíveis do id=", card_id)
		return

	if t == "hero":
		print("test")
		hero_id_choice = card_id
		collection_count[card_id] = qty - 1
	else: 
		deck.append(card_id)
		collection_count[card_id] = qty - 1

	_sync_global_deck()
	_render_deck()
	_render_library()
	_update_deck_counter()


func _remove_from_deck_at(index: int) -> void:
	if index < 0 or index >= deck.size():
		return
	print("teste2")
	var removed_id := int(deck[index])
	deck.remove_at(index)

	if collection_count.has(removed_id):
		collection_count[removed_id] = int(collection_count[removed_id]) + 1

	_sync_global_deck()
	_render_deck()
	_render_library()
	_update_deck_counter()

func _group_deck_for_ui(deck_arr: Array[int]) -> Array:
	var counts := {}
	var first_idx := {}
	for i in range(deck_arr.size()):
		var id := int(deck_arr[i])
		counts[id] = int(counts.get(id, 0)) + 1
		if !first_idx.has(id):
			first_idx[id] = i

	var groups: Array = []
	for id in counts.keys():
		groups.append({
			"card_id": int(id),
			"count": int(counts[id]),
			"first_index": int(first_idx[id])
		})

	# opcional: ordenar por nome, custo, ou id
	#groups.sort_custom(func(a,b): return int(a["card_id"]) < int(b["card_id"]))
	return groups


func _sync_global_deck() -> void:
	"""
	Salva o deck atual no Global para o main consumir depois.
	"""
	Global.my_deck = deck.duplicate(true)
	Global.my_hero_id = hero_id_choice
	_update_deck_counter()


# =========================================================
# Host / Join
# =========================================================


func _on_play_pressed() -> void:
	if !_validate_deck_ready():
		return
	_sync_global_deck()
	
	get_tree().change_scene_to_file("res://main.tscn")


func _validate_deck_ready() -> bool:
	"""
	Regra mínima: deck tem que ter DECK_SIZE cartas.
	Depois podemos adicionar regras de construção aqui.
	"""
	if deck.size() != DECK_SIZE:
		print("[DECKBUILDER] Deck precisa ter %d cartas. Atual=%d" % [DECK_SIZE, deck.size()])
		return false
	
	#var hero_count := _count_heroes_in_deck()
	
	
	#if hero_count != 1:
	if hero_id_choice == -1:
		print("[DECKBUILDER] Deck precisa ter exatamente 1 herói. Atual=%d" )
		return false

	return true


# =========================================================
# Utils
# =========================================================
func _clear_children(n: Node) -> void:
	"""
	Limpa os filhos (usado pra re-renderizar grids).
	"""
	for c in n.get_children():
		c.queue_free()

func _ensure_decks_dir() -> void:
	var abs := ProjectSettings.globalize_path(DECKS_DIR)
	if DirAccess.dir_exists_absolute(abs):
		return
	DirAccess.make_dir_recursive_absolute(abs)

func _sanitize_filename(name: String) -> String:
	var s := name.strip_edges()
	if s == "":
		s = "deck"
	s = s.to_lower()
	var ok := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch in ["_", "-", " "]:
			ok += ch
		else:
			ok += "_"
	ok = ok.replace(" ", "_")
	return ok

func _deck_file_path(deck_name: String) -> String:
	var safe := _sanitize_filename(deck_name)
	return "%s/%s.json" % [DECKS_DIR, safe]

func save_deck(deck_name: String) -> bool:
	
	#Retirar - permitir decks incompletos a serem salvos
	#if deck.size() != DECK_SIZE:
	#	print("[DECKBUILDER] não salvou: deck incompleto (%d/%d)" % [deck.size(), DECK_SIZE])
	#	return false

	_ensure_decks_dir()

	var payload := {
		"version": 1,
		"name": deck_name,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"deck": deck.duplicate(true),
		"hero_id": int(Global.my_hero_id) # se você usa isso
	}

	var path := _deck_file_path(deck_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("[DECKBUILDER] erro abrindo pra escrever: ", path)
		return false

	f.store_string(JSON.stringify(payload, "\t"))
	f.close()

	print("[DECKBUILDER] deck salvo em: ", path)
	return true

func list_saved_decks() -> Array:
	_ensure_decks_dir()

	var abs := ProjectSettings.globalize_path(DECKS_DIR)
	var dir := DirAccess.open(abs)
	if dir == null:
		return []

	var out: Array = []
	dir.list_dir_begin()
	while true:
		var fn := dir.get_next()
		if fn == "":
			break
		if dir.current_is_dir():
			continue
		if !fn.ends_with(".json"):
			continue

		var full_path := "%s/%s" % [DECKS_DIR, fn]
		var meta := _read_deck_meta(full_path)
		if meta.is_empty():
			continue

		out.append({
			"path": full_path,
			"name": str(meta.get("name", fn)),
			"saved_at_unix": int(meta.get("saved_at_unix", 0))
		})
	dir.list_dir_end()

	# mais recente primeiro
	out.sort_custom(func(a,b): return int(a["saved_at_unix"]) > int(b["saved_at_unix"]))
	return out

func _read_deck_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func load_deck(path: String) -> bool:
	var data := _read_deck_meta(path)
	if data.is_empty():
		print("[DECKBUILDER] load falhou (arquivo inválido): ", path)
		return false

	var arr = data.get("deck", [])
	if typeof(arr) != TYPE_ARRAY:
		print("[DECKBUILDER] load falhou (deck não é array): ", path)
		return false

	var loaded: Array[int] = []
	for x in arr:
		loaded.append(int(x))

	if loaded.size() > DECK_SIZE:
		print("[DECKBUILDER] load falhou (size=%d, esperado=%d)" % [loaded.size(), DECK_SIZE])
		return false

	# aplica
	deck = loaded
	Global.my_deck = deck.duplicate(true)
	if data.has("hero_id"):
		Global.my_hero_id = int(data["hero_id"])

	# recalcula coleção (10 cópias por carta - o que está no deck)
	_rebuild_collection_counts_from_deck()

	_render_deck()
	_render_library()
	_update_deck_counter()

	print("[DECKBUILDER] deck carregado: ", str(data.get("name", path)))
	return true

func _rebuild_collection_counts_from_deck() -> void:
	collection_count.clear()
	for id in available_ids:
		collection_count[int(id)] = COPIES_PER_CARD

	for cid in deck:
		var id := int(cid)
		if collection_count.has(id):
			collection_count[id] = max(int(collection_count[id]) - 1, 0)
			
func _on_save_pressed() -> void:
	#Retirar por hora - permite salvar deck mesmo que incompleto
	#if deck.size() != DECK_SIZE:
	#	print("[DECKBUILDER] deck incompleto (%d/%d)" % [deck.size(), DECK_SIZE])
	#	return

	var name := ""
	if deck_name:
		name = deck_name.text.strip_edges()

	if name == "":
		print("[DECKBUILDER] nome vazio")
		return

	current_deck_name = name
	save_deck(current_deck_name)

	print("[DECKBUILDER] salvo:", current_deck_name)

func _on_load_pressed() -> void:
	decks_popup.clear()

	var items := list_saved_decks()
	if items.is_empty():
		decks_popup.add_item("(nenhum deck salvo)")
		decks_popup.set_item_disabled(0, true)
	else:
		for i in range(items.size()):
			var it = items[i]
			decks_popup.add_item("%s" % str(it["name"]), i)
			# guarda o path como metadata do item
			decks_popup.set_item_metadata(i, str(it["path"]))
	
	decks_popup.popup_centered()
	

func _on_deck_popup_item(id: int) -> void:
	var path := str(decks_popup.get_item_metadata(id))

	# pega o texto exibido no popup (nome do deck)
	var deck_names := decks_popup.get_item_text(id)

	if load_deck(path):
		current_deck_name = deck_names
		if deck_name:
			deck_name.text = current_deck_name
	

func _on_new_pressed() -> void:
	deck.clear()

	# gerar nome automático único
	var index := 1
	var base := "New_deck_"
	while true:
		var candidate := base + str(index)
		var path := _deck_file_path(candidate)
		if !FileAccess.file_exists(path):
			current_deck_name = candidate
			deck_name.text = current_deck_name
			print("[DECKBUILDER - 1] novo deck:", current_deck_name)
			break
		index += 1

	if deck_name:
		deck_name.text = current_deck_name

	# reset coleção
	collection_count.clear()
	for id in available_ids:
		collection_count[int(id)] = COPIES_PER_CARD

	_sync_global_deck()
	_render_deck()
	_render_library()
	_update_deck_counter()

	print("[DECKBUILDER] novo deck:", current_deck_name)


func _on_delete_pressed() -> void:
	if current_deck_name == "":
		print("[DECKBUILDER] nenhum deck salvo selecionado")
		return

	var path := _deck_file_path(current_deck_name)

	if !FileAccess.file_exists(path):
		print("[DECKBUILDER] arquivo não encontrado:", path)
		return

	var abs := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs)

	if err != OK:
		print("[DECKBUILDER] erro ao deletar:", err)
		return

	print("[DECKBUILDER] deck deletado:", current_deck_name)

	# 🔥 resetar tudo
	current_deck_name = ""
	if deck_name:
		deck_name.text = ""

	deck.clear()

	collection_count.clear()
	for id in available_ids:
		collection_count[int(id)] = COPIES_PER_CARD

	_sync_global_deck()
	_render_deck()
	_render_library()
	
	
func _update_deck_counter() -> void:
	if deck_count_label:
		deck_count_label.text = "%d / %d" % [deck.size(), DECK_SIZE]

		# opcional: deixar vermelho se incompleto
		if deck.size() != DECK_SIZE:
			deck_count_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			deck_count_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))


func _count_heroes_in_deck() -> int:
	var count := 0
	for cid in deck:
		var data: Dictionary = CardDB.get_card_data(int(cid))
		var t := str(data.get("type", "")).to_lower().strip_edges()
		if t == "hero":
			count += 1
	return count
