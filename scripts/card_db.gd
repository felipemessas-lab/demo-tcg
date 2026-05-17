extends Node
class_name CardDB

const GOLEM := 1
const GHOST_KNIGHT := 2
const BASIC_LAND := 3
const HERO_GOLD_KING := 4
const HERO_WOLF := 5


static func get_card_data(id: int) -> Dictionary:
	match id:
		GOLEM:
			return {
				"id": GOLEM,
				"name": "Golem",
				"cost": 1,
				"type": "creature",
				"rules": "Golem feito de lava\nEfeitos: Rush",
				"atk": 2,
				"def": 6,
				"art_path": "res://assets/cards/golem.png",
				"effects": [
				  {"id":"rush"},
				  {"id":"lifesteal", "pct": 50} # ou "amount": 2 etc
				],
			}
		GHOST_KNIGHT:
			return {
				"id": GHOST_KNIGHT,
				"name": "Cavaleiro Fantasma",
				"cost": 2,
				"type": "creature",
				"rules": "Cavaleiro fantasma\nEfeitos: Lifesteal",
				"atk": 7,
				"def": 2,
				"art_path": "res://assets/cards/ghost_knight.png",
				"effects": [
				  
				  {"id":"lifesteal", "pct": 100} # ou "amount": 2 etc
				],
			}
			
		BASIC_LAND:
			return {
				"id": BASIC_LAND,
				"name": "Terreno Básico",
				"cost": 0,
				"type": "mana",
				"rules": "Vira para gerar 1 mana.",
				"mana_amount": 1,
				"art_path": "res://assets/cards/mana_forest.png",
				
			}
		
		HERO_GOLD_KING:
			return {
				"id": HERO_GOLD_KING,
				"name": "Gold King",
				"cost": 0,
				"type": "hero",
				"rules": "Hero target",
				"atk": 0,
				"def": 9999,
				"art_path": "res://assets/cards/gold_king.png",
				"frame_path": "res://assets/cards/frame_heroi_branco.png",
				"label_color": [0, 0, 0, 1.0],          # cor do texto
				#"label_outline": [0.0, 0.0, 0.0, 0.85],         # outline (opcional)
				#"label_outline_size": 4,                         # outline size (opcional)
			}
			
		HERO_WOLF:
			return {
				"id": HERO_GOLD_KING,
				"name": "Wolf",
				"cost": 0,
				"type": "hero",
				"rules": "Hero target",
				"atk": 0,
				"def": 9999,
				"art_path": "res://assets/cards/heroi_forest.png",
				"frame_path": "res://assets/cards/frame_heroi_preto.png",
				"label_color": [1.0, 0.95, 0.85, 1.0],          # cor do texto
				#"label_outline": [0.0, 0.0, 0.0, 0.85],         # outline (opcional)
				#"label_outline_size": 4,                         # outline size (opcional)
			}
		
		_:
			return {}
