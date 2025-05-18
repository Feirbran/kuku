# Kukù - Psychological Horror Card Game

*Kukù* è un videogioco multiplayer di carte ispirato al tradizionale gioco del Cucù, ambientato nella Firenze del 1348 durante l’epidemia di peste nera. In un’atmosfera tesa e claustrofobica, dieci nobili fiorentini si sfidano in una competizione rituale, dove perdere significa mutilazione... e la follia è sempre in agguato.

## 🎯 Obiettivo del Gioco

Sopravvivere fino alla fine dei dieci giorni di isolamento, mantenendo la propria **sanità mentale** e almeno un dito intatto. Il gioco termina quando resta un solo giocatore o al termine del decimo giorno.

## 🎮 Gameplay

- **Tipo di gioco:** Gioco di carte, Horror psicologico, Multiplayer
- **Numero giocatori:** Fino a 10
- **Motore:** [Godot Engine](https://godotengine.org/)
- **Durata massima:** 10 Giorni (100 Round)
- **Lingua:** Italiano

### Regole Base (Cucù)
- Ogni giocatore riceve una carta.
- A turno, può decidere se tenerla o scambiarla con il vicino.
- Alla fine del round, chi ha la carta più bassa perde un dito (una vita).
- Ogni 10 round si conclude un “giorno”.

## 🧠 Sanità Mentale

La **Sanità Mentale (SM)** è una risorsa vitale:
- Serve per attivare abilità.
- Scende in risposta a eventi, abilità e perdite.
- A valori bassi (<30), influisce negativamente sul comportamento del personaggio.
- A SM=0, il personaggio entra in **breakdown** e perde il controllo delle sue azioni.

## 🎭 Classi

Ogni giocatore interpreta uno dei personaggi ispirati al *Decameron*.  
Ogni classe dispone di:
- **2 abilità attive** (con costo in SM e cooldown)
- **1 abilità passiva**
- **1 abilità disperata**, disponibile solo con SM bassa

Le classi sono progettate per creare sinergie, bluff e caos psicologico.  
Esempi di ruoli:
- **La Comandante**: controlla la struttura del turno.
- **L’Impostore**: può ingannare gli altri copiando le azioni.
- **Il Visionario**: anticipa le mosse altrui.

*(Per il dettaglio delle classi, vedi `docs/classes.md`)*

## 🧩 Funzionalità

### Implementate
- Gestione round e timer
- Sistema di sanità mentale
- UI interattiva per abilità, classi e timer
- Classi con cooldown, costi e abilità attivabili
- Schermata di transizione tra i giorni

### In sviluppo
- Logica di scambio carte (Cucù)
- Eliminazioni e fine partita
- Gestione multiplayer
- Mazzo completo da 168 carte
- Effetti visivi e sonori reattivi allo stato mentale
- Musiche dinamiche legate alla Sanità

## 📁 Struttura del progetto

```
kukù/
├── assets/
│   ├── audio/
│   ├── cards/
│   └── portraits/
├── docs/
│   └── classes.md
├── scenes/
│   ├── Game.tscn
│   ├── Characters/
│   └── UI/
├── scripts/
│   ├── game_logic.gd
│   ├── classes/
│   └── ui/
└── README.md
```

## ⚙️ Requisiti

- Godot Engine (versione 4.2+ consigliata)
- Sistema operativo compatibile (Windows, macOS, Linux)

## 🚀 Avvio rapido

```bash
git clone https://github.com/tuo-utente/kuku.git
cd kuku
godot .
```

## 👥 Crediti

- **Ideazione e game design:** [Il tuo nome/team]
- **Sviluppo:** [Collaboratori qui]
- **Ispirazione narrativa:** *Il Decameron* di Giovanni Boccaccio
- **Motore di gioco:** [Godot Engine](https://godotengine.org/)

## 📜 Licenza

Questo progetto è distribuito sotto licenza **MIT**.  
Sentiti libero di usarlo, modificarlo e contribuire... ma occhio alla follia.

---

> ⚠️ **Avvertenze:**  
> Questo gioco affronta temi maturi, tra cui mutilazioni, malattia e deterioramento mentale.  
> Non è adatto a un pubblico sensibile.
