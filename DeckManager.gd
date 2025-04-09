# DeckManager.gd (Versione Pulita)
extends Node
class_name DeckManager

# Array che contiene TUTTE le risorse CardData del mazzo completo.
# DEVI assegnare le tue risorse CardData a questo array nell'Inspector
# del nodo DeckManager (DeckSetupScene) nell'editor Autoload.
@export var all_card_data: Array[CardData] = []

# Array per il mazzo attuale (durante il gioco)
var current_deck: Array[CardData] = []
# Array per gli scarti
var discard_pile: Array[CardData] = []

# Chiamato quando l'Autoload è pronto
func _ready():
	print("DeckManager pronto.")
	if all_card_data.is_empty():
		printerr("ATTENZIONE: 'All Card Data' non è stato assegnato nell'inspector per DeckManager!")
	else:
		print("Numero totale di CardData caricate: ", all_card_data.size())
	# All'inizio, popola il mazzo attuale con tutte le carte definite
	reset_and_shuffle()

# Prepara un nuovo mazzo mescolato
func reset_and_shuffle():
	# Copia tutte le carte definite nell'array del mazzo attuale
	# Usiamo duplicate(true) per una copia profonda se CardData avesse altre risorse interne
	current_deck = all_card_data.duplicate(true)
	# Svuota gli scarti
	discard_pile.clear()
	# Mescola il mazzo attuale
	current_deck.shuffle()
	print("Mazzo resettato e mescolato. Carte nel mazzo pesca: ", current_deck.size())

# Pesca una carta dalla cima del mazzo
func draw_card() -> CardData:
	if current_deck.is_empty():
		# Se il mazzo è vuoto, mescola gli scarti e mettili nel mazzo
		if discard_pile.is_empty():
			printerr("ERRORE: Mazzo e scarti vuoti! Impossibile pescare.")
			return null # Nessuna carta disponibile
		else:
			print("Mazzo pesca vuoto. Rimescolo gli scarti (%d carte)..." % discard_pile.size())
			current_deck = discard_pile.duplicate(true) # Copia profonda
			discard_pile.clear()
			current_deck.shuffle()
			# Controllo extra dopo il rimescolamento
			if current_deck.is_empty():
				printerr("ERRORE: Mazzo ancora vuoto dopo aver rimescolato gli scarti!")
				return null

	# Rimuovi e restituisci la prima carta dall'array del mazzo
	return current_deck.pop_front()

# Aggiunge una carta (o più carte) alla pila degli scarti
func discard_card(card: CardData):
	if card != null:
		# print("Scartata carta: ", card.rank_name) # Debug opzionale
		discard_pile.push_back(card)
	else:
		printerr("Tentativo di scartare una carta null!")

func discard_cards(cards: Array[CardData]):
	for card in cards:
		discard_card(card) # Usa la funzione singola per il controllo null

# Ritorna il numero di carte rimaste nel mazzo di pesca
func cards_remaining() -> int:
	return current_deck.size()

# Ritorna il numero di carte nella pila degli scarti
func discarded_cards_count() -> int:
	return discard_pile.size()
