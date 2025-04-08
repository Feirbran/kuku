# deck_manager.gd
extends Node
class_name DeckManager

# Array che conterrà TUTTE le risorse CardData del nostro mazzo completo
@export var all_card_data: Array[CardData] = []

# Array per il mazzo attuale (durante il gioco)
var current_deck: Array[CardData] = []
# Array per gli scarti
var discard_pile: Array[CardData] = []

# Chiamato quando il nodo entra nell'albero delle scene la prima volta
func _ready():
	print("DeckManager pronto.")
	# All'inizio, popola il mazzo attuale con tutte le carte definite
	reset_and_shuffle()
	# Stampa il mazzo mescolato per controllo (puoi rimuoverlo più tardi)
	# print("Mazzo iniziale: ", current_deck)
	# print("Carte nel mazzo: ", current_deck.size())

# Prepara un nuovo mazzo mescolato
func reset_and_shuffle():
	# Copia tutte le carte definite nell'array del mazzo attuale
	current_deck = all_card_data.duplicate()
	# Svuota gli scarti
	discard_pile.clear()
	# Mescola il mazzo attuale
	current_deck.shuffle()
	print("Mazzo resettato e mescolato. Carte: ", current_deck.size())

# Pesca una carta dalla cima del mazzo
func draw_card() -> CardData:
	if current_deck.is_empty():
		# Se il mazzo è vuoto, mescola gli scarti e mettili nel mazzo
		if discard_pile.is_empty():
			printerr("ERRORE: Mazzo e scarti vuoti! Impossibile pescare.")
			return null # Nessuna carta disponibile
		else:
			print("Mazzo vuoto. Rimescolo gli scarti...")
			current_deck = discard_pile.duplicate()
			discard_pile.clear()
			current_deck.shuffle()

	# Rimuovi e restituisci la prima carta dall'array del mazzo
	return current_deck.pop_front()

# Aggiunge una carta (o più carte) alla pila degli scarti
func discard_card(card: CardData):
	if card != null:
		discard_pile.push_back(card)

func discard_cards(cards: Array[CardData]):
	for card in cards:
		discard_card(card)

# Ritorna il numero di carte rimaste nel mazzo di pesca
func cards_remaining() -> int:
	return current_deck.size()
