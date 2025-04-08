# card_data.gd
extends Resource
class_name CardData # Diamo un nome alla nostra classe di risorsa

# Definiamo le proprietà che ogni carta avrà
@export var suit: String = "" # Seme (es. "Bastoni", "Denari", ecc.) - Non usato nelle regole base, ma utile averlo
@export var rank_name: String = "" # Nome del rango (es. "Re", "Asso", "7")
@export var value: int = 0 # Valore numerico per il confronto (Asso=1, 2=2... Fante=8, Cavallo=9, Re=10)
@export var texture_front: Texture2D # Texture per il fronte della carta
# @export var texture_back: Texture2D # Potremmo aggiungere una texture per il retro più avanti

# Funzione opzionale per inizializzare una carta (non strettamente necessaria ora)
func _init(s: String = "", rn: String = "", v: int = 0, tex: Texture2D = null):
	suit = s
	rank_name = rn
	value = v
	texture_front = tex

# Funzione per ottenere una rappresentazione testuale della carta (utile per debug)
#func to_string() -> String:
#	return str(rank_name, " (", value, ")")
