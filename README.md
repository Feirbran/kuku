
# 🃏 KUKU – Un gioco di carte narrativo ispirato al Decamerone

Benvenuti in **Kuku**, un gioco di carte strategico e narrativo ambientato nella Firenze del 1300 durante l'epidemia di peste. Ispirato al *Decamerone* di Giovanni Boccaccio, il gioco trasporta i giocatori in un’epoca di panico, superstizione e racconti, dove ogni carta può cambiare il destino… o far perdere la sanità mentale.

---

## 🎭 Concept

Durante la peste nera, un gruppo di giovani nobili si ritira in campagna per sfuggire alla morte. Ma anche lontani dalla città, non possono fuggire dai racconti, dagli intrighi e dalle conseguenze delle loro azioni.

- Ambientazione: Firenze, 1348
- Ispirazione narrativa: *Decamerone*
- Genere: Gioco di carte narrativo, visual novel, party game
- Tono: Satirico, ironico, psicologico

---

## 🛠️ Stato di sviluppo

Il progetto è attivamente in sviluppo su **Godot 4**.

### ✅ Funzionalità attualmente presenti

- 🎲 Turni dinamici per più giocatori
- 🧠 Sistema base di **sanità mentale** (Mental Health)
- 🃏 Carte con eventi, dialoghi e conseguenze multiple
- 💬 Scelte narrative ramificate
- 🔄 Gestione del mazzo, scarti e pescate
- 🧑‍🤝‍🧑 Due giocatori gestiti separatamente (player0, player1)
- 🖥️ Integrazione iniziale della UI per visualizzare parametri

### 🧪 In sviluppo

- 🔧 Collegamento completo tra UI e dati del gioco
- 🧩 Modularizzazione del codice (estrazione da `game_manager.gd`)
- 📜 Altre carte e narrazioni storiche/surrealistiche
- 🎨 Stile grafico coerente e immersivo
- 🔊 Sonoro ambientale medievale

---

## 🧠 Meccaniche principali

- **Sanità Mentale**: ogni scelta o evento può aumentare o ridurre la lucidità mentale del personaggio.
- **Carte Evento**: attivano storie o scelte morali, con effetti immediati o a lungo termine.
- **Turni**: i giocatori si alternano pescando carte, risolvendo eventi e prendendo decisioni.
- **Narrativa Ramificata**: le scelte portano a dialoghi alternativi e conseguenze diverse, anche comiche o tragiche.

---

## 📂 Struttura del progetto

- `game_manager.gd` – Controlla il flusso generale del gioco
- `card.gd` – Script base per le carte evento
- `deck.gd` / `pile.gd` – Gestione mazzo e pila scarti
- `player.gd` – Stato e proprietà dei giocatori
- `UI/` – Contiene etichette, pulsanti, segnalatori della UI
- `Main.tscn` – Scena principale

---

## 🐛 Problemi noti

- ❗ Etichette della sanità mentale non collegate correttamente alla scena (`player0_sanity_label`)
- ❗ Variabili non riconosciute in alcuni ambiti (`mental_health`)
- 🔧 File `game_manager.gd` molto esteso: si consiglia una futura separazione in più moduli
- 🚧 Alcune carte non hanno ancora effetti completi

---

## 💡 Roadmap (Prossimi Obiettivi)

- [ ] Collegamento dinamico tra dati e UI
- [ ] Sviluppo della modalità storia
- [ ] Disegno artistico per carte e sfondi
- [ ] Implementazione effetti sonori e musica medievale
- [ ] Testing multiplayer locale
- [ ] Localizzazione ITA/ENG


---

## 📜 Licenza

Questo progetto è distribuito sotto licenza **MIT**. Sentiti libero di usarlo, modificarlo e condividerlo.

---

## 👤 Autori

- 👑 **Feirbran** – Ideatore, sviluppatore principale, sceneggiatura
- 🎨 Collaborazioni future aperte (grafica, suono, test)

---

> *"Non con l’armi ma con le carte si combatte la peste."*
