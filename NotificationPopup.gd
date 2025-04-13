# NotificationPopup.gd
extends PanelContainer # O Control, o ColorRect, a seconda del tipo del tuo nodo radice

# --- RIFERIMENTI AI NODI INTERNI ---
# Assicurati che i percorsi qui sotto ($NomeNodo) corrispondano ESATTAMENTE
# ai nomi che hai dato ai nodi Label e Timer nella tua scena NotificationPopup.tscn!
# Se li hai chiamati diversamente, modifica i nomi qui.

# Riferimento alla Label che mostrerà il messaggio
@onready var message_label: Label = $MessageLabel
# Riferimento al Timer che controllerà la durata della visualizzazione
@onready var display_timer: Timer = $DisplayTimer

# --- INIZIALIZZAZIONE ---
func _ready():
	# Assicuriamoci che il popup sia nascosto all'inizio
	visible = false

	# Colleghiamo il segnale 'timeout' del Timer alla funzione '_on_display_timer_timeout'
	# Questo si può fare anche dall'editor: seleziona il Timer, vai su Nodo > Segnali,
	# fai doppio click su 'timeout' e scegli il nodo radice (con questo script) e la funzione.
	# Questo codice lo fa programmaticamente se non l'hai fatto dall'editor.
	if not display_timer.is_connected("timeout", Callable(self, "_on_display_timer_timeout")):
		var error = display_timer.connect("timeout", Callable(self, "_on_display_timer_timeout"))
		if error != OK:
			printerr("Errore nel collegare il segnale timeout del DisplayTimer!")

# --- FUNZIONE PRINCIPALE (chiamata dall'esterno) ---
# Mostra il popup con un messaggio specifico per una certa durata
func show_message(text_to_show: String, duration: float):
	# Controllo di sicurezza: i nodi Label e Timer esistono?
	if message_label == null:
		printerr("NotificationPopup ERRORE: Nodo Label 'MessageLabel' non trovato!")
		return
	if display_timer == null:
		printerr("NotificationPopup ERRORE: Nodo Timer 'DisplayTimer' non trovato!")
		return

	# Imposta il testo nella Label
	message_label.text = text_to_show

	# Imposta la durata del timer (quanto a lungo resterà visibile)
	display_timer.wait_time = duration

	# Rendi VISIBILE il pannello del popup
	visible = true

	# Avvia il timer
	display_timer.start()

	print("DEBUG: Mostro popup '%s' per %.1f sec." % [text_to_show, duration])


# --- GESTIONE TIMEOUT ---
# Questa funzione viene chiamata automaticamente quando il segnale 'timeout' del Timer viene emesso
func _on_display_timer_timeout():
	print("DEBUG: Timer popup scaduto. Nascondo.")
	# Nascondi di nuovo il pannello del popup
	visible = false
	# NOTA: Invece di nasconderlo potremmo distruggerlo con queue_free().
	# Nascondendolo, l'istanza rimane pronta per essere riutilizzata, il che
	# è leggermente più efficiente se viene mostrato spesso. Se preferisci
	# distruggerlo ogni volta, decommenta la riga qui sotto.
	# queue_free()
