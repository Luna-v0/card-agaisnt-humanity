import json
import uuid
import os
import random
from typing import Dict, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
import uvicorn
from src.cards import load_cards_from_csv
from src.game import GameManager

game_manager = GameManager()
AUTO_PLAY = os.getenv("AUTO_PLAY", "false").lower() == "true"

@asynccontextmanager
async def lifespan(app: FastAPI):
    all_cards = load_cards_from_csv("cards.csv")
    white_cards = [c for c in all_cards if "Resposta (Branca)" in c.card_type]
    black_cards = [c for c in all_cards if "Pergunta (Preta)" in c.card_type]
    game_manager.set_decks(white_cards, black_cards)
    print(f"Loaded {len(white_cards)} white cards and {len(black_cards)} black cards.")
    yield

app = FastAPI(lifespan=lifespan)

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, player_id: str):
        await websocket.accept()
        self.active_connections[player_id] = websocket

    def disconnect(self, player_id: str):
        if player_id in self.active_connections:
            del self.active_connections[player_id]

    async def send_personal_message(self, message: dict, player_id: str):
        if player_id in self.active_connections:
            await self.active_connections[player_id].send_json(message)

    async def broadcast(self, message: dict):
        for connection in self.active_connections.values():
            await connection.send_json(message)

connection_manager = ConnectionManager()

async def broadcast_game_state():
    for player_id in list(connection_manager.active_connections.keys()):
        state = game_manager.get_game_state(player_id)
        await connection_manager.send_personal_message({
            "type": "game_state",
            "payload": state
        }, player_id)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    player_id = str(uuid.uuid4())
    await connection_manager.connect(websocket, player_id)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")
            payload = data.get("payload", {})

            if msg_type == "join":
                mode = payload.get("mode")
                if mode:
                    global AUTO_PLAY
                    AUTO_PLAY = True
                    if mode == "czar":
                        game_manager.set_czar_index(0)
                    elif mode == "player":
                        game_manager.set_czar_index(1)

                game_manager.add_player(player_id, payload.get("name", "Unknown"))
                
                # DEBUG MODE / QUICK PLAY: Add dummy players
                if AUTO_PLAY or mode:
                    if len(game_manager.players) < 3:
                        game_manager.add_player("dummy-1", "Bot Bob")
                        game_manager.add_player("dummy-2", "Bot Alice")
                
                await broadcast_game_state()
                
                # Auto-start if mode selected
                if mode and game_manager.state == "LOBBY":
                     error = game_manager.start_round()
                     if not error:
                         await broadcast_game_state()
                         if AUTO_PLAY:
                             await handle_auto_play(player_id)

            elif msg_type == "start_game":
                error = game_manager.start_round()
                if error:
                    await connection_manager.send_personal_message({
                        "type": "error",
                        "payload": {"message": error}
                    }, player_id)
                else:
                    await broadcast_game_state()
                    if AUTO_PLAY:
                        await handle_auto_play(player_id)

            elif msg_type == "submit_card":
                indices = payload.get("indices")
                # Fallback / backward compat
                if indices is None and "index" in payload:
                    indices = [payload.get("index")]

                if indices and game_manager.submit_card(player_id, indices):
                    await broadcast_game_state()
                    if AUTO_PLAY:
                        await handle_auto_play(player_id)

            elif msg_type == "pick_winner":
                if game_manager.pick_winner(player_id, payload.get("player_id")):
                    await broadcast_game_state()

    except Exception:
        connection_manager.disconnect(player_id)
        game_manager.remove_player(player_id)
        await broadcast_game_state()

async def handle_auto_play(trigger_player_id: str):
    if game_manager.state == "PLAYING":
        changed = False
        # Bots check if they need to submit
        for p_id in list(game_manager.players.keys()):
            player = game_manager.players[p_id]
            # Simple heuristic: if name starts with "Bot", it's a bot
            if player.name.startswith("Bot") and not player.is_czar and not player.submitted_cards:
                if player.hand and game_manager.current_black_card:
                    num_gaps = game_manager.current_black_card.num_gaps
                    if len(player.hand) >= num_gaps:
                        # Pick random indices
                        indices = random.sample(range(len(player.hand)), num_gaps)
                        game_manager.submit_card(p_id, indices)
                        changed = True
        
        if changed:
            await broadcast_game_state()
            # If state changed to SELECTION after submission, handle Czar logic recursively or immediately
            if game_manager.state == "SELECTION":
                await handle_auto_play(trigger_player_id)

    elif game_manager.state == "SELECTION":
        # Check if Czar is a bot
        czar_id = None
        for p_id, player in game_manager.players.items():
            if player.is_czar:
                czar_id = p_id
                break
        
        if czar_id:
            czar = game_manager.players[czar_id]
            if czar.name.startswith("Bot"):
                # Czar is a bot, pick a winner
                candidates = [p_id for p_id, p in game_manager.players.items() if p.submitted_cards]
                if candidates:
                    winner_id = random.choice(candidates)
                    if game_manager.pick_winner(czar_id, winner_id):
                        await broadcast_game_state()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
