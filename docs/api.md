# WebSocket API Reference

The backend communicates with clients using WebSocket messages. All messages are JSON objects.

## Base Structure

Each message contains a `type` and a `payload`.

**Example:**
```json
{
  "type": "join",
  "payload": {
    "name": "MyUsername"
  }
}
```

## Client -> Server Messages

| Type | Payload Example | Description |
| :--- | :--- | :--- |
| `join` | `{"name": "Alice"}` | Registers a new player with the given name. |
| `start_game` | `{}` | Starts a new game (if enough players). |
| `submit_card` | `{"indices": [0, 2]}` | Submits the cards at the specified indices in the player's hand. **Note**: `index` (singular) is deprecated but still supported for single-card submissions. |
| `pick_winner` | `{"player_id": "player-uuid"}` | (Czar only) Selects the winner of the round. |

## Server -> Client Messages

### Game State Update

The server broadcasts the full game state on any significant change (player join, card submitted, round change).

**Type:** `game_state`

**Payload:**
```json
{
  "state": "LOBBY", // "LOBBY", "PLAYING", "SELECTION", "RESULTS"
  "players": [
    {
      "id": "uuid-1234",
      "name": "Alice",
      "score": 0,
      "is_czar": true,
      "has_submitted": false,
      "hand_size": 10
    }
  ],
  "current_black_card": {
    "card_type": "Pergunta (Preta)",
    "text": "Why can't I sleep at night?",
    "num_gaps": 1
  },
  "last_winner": null,
  "hand": [ // Only sent to the specific player
    { "text": "Bees?", "card_type": "Resposta (Branca)" }
  ],
  "is_czar": true, // Whether receiving player is Czar
  "submissions": [ // Only in SELECTION/RESULTS phase
    {
      "player_id": "uuid-5678",
      "cards": [{"text": "Bees?"}],
      "filled_text": "Why can't I sleep at night? [Bees?]"
    }
  ]
}
```

### Error

Sent when an action fails.

**Type:** `error`

**Payload:**
```json
{
  "message": "Need at least 3 players to start."
}
```
