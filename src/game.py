import random
import os
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, field
from src.cards import Card

@dataclass
class Player:
    """Represents a player in the game."""
    id: str
    name: str
    hand: List[Card] = field(default_factory=list)
    score: int = 0
    is_czar: bool = False
    submitted_cards: List[Card] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Returns player data as a dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "score": self.score,
            "is_czar": self.is_czar,
            "has_submitted": len(self.submitted_cards) > 0,
            "hand_size": len(self.hand)
        }

class GameManager:
    """Manages the CAH game state and logic."""
    def __init__(self):
        self.players: Dict[str, Player] = {}
        self.white_deck: List[Card] = []
        self.black_deck: List[Card] = []
        self.current_black_card: Optional[Card] = None
        self.czar_index: int = 0
        self.state: str = "LOBBY" # LOBBY, PLAYING, SELECTION, RESULTS
        self.last_winner: Optional[str] = None
        
        # Initial Czar configuration
        try:
            self.czar_index = int(os.getenv("CZAR_START_INDEX", "0"))
        except ValueError:
            self.czar_index = 0

    def set_czar_index(self, index: int):
        """Sets the index for the next Czar."""
        self.czar_index = index

    def set_decks(self, white_cards: List[Card], black_cards: List[Card]):
        """Sets the initial decks and shuffles them."""
        self.white_deck = white_cards.copy()
        self.black_deck = black_cards.copy()
        random.shuffle(self.white_deck)
        random.shuffle(self.black_deck)

    def add_player(self, player_id: str, name: str) -> Player:
        """Adds a new player to the game."""
        player = Player(id=player_id, name=name)
        # Give initial hand
        self.deal_cards(player, 10)
        self.players[player_id] = player
        return player

    def remove_player(self, player_id: str):
        """Removes a player from the game."""
        if player_id in self.players:
            del self.players[player_id]
            if len(self.players) < 3 and self.state != "LOBBY":
                self.state = "LOBBY"

    def deal_cards(self, player: Player, count: int):
        """Deals a specified number of white cards to a player."""
        for _ in range(count):
            if self.white_deck:
                player.hand.append(self.white_deck.pop())

    def start_round(self):
        """Starts a new round of the game."""
        if len(self.players) < 3:
            return "Need at least 3 players to start."

        self.state = "PLAYING"
        self.last_winner = None
        
        # Reset player submissions
        for player in self.players.values():
            player.submitted_cards = []
            player.is_czar = False
            # Ensure everyone has 10 cards
            self.deal_cards(player, 10 - len(player.hand))

        # Assign Czar
        player_ids = list(self.players.keys())
        
        # Ensure index is within bounds
        if self.czar_index >= len(player_ids):
            self.czar_index = 0
            
        czar_id = player_ids[self.czar_index]
        self.players[czar_id].is_czar = True
        self.czar_index += 1

        # Draw black card
        if self.black_deck:
            self.current_black_card = self.black_deck.pop()
        else:
            # Reshuffle if empty? For now just restart
            return "Black deck empty!"

    def submit_card(self, player_id: str, card_indices: List[int]):
        """Handles a player submitting white cards."""
        player = self.players.get(player_id)
        if not player or player.is_czar or player.submitted_cards or self.state != "PLAYING":
            return False

        if not self.current_black_card:
            return False

        required_count = self.current_black_card.num_gaps
        if len(card_indices) != required_count:
            return False

        # Validate indices
        if any(idx < 0 or idx >= len(player.hand) for idx in card_indices):
            return False
        
        # Check for duplicates
        if len(set(card_indices)) != len(card_indices):
            return False

        # Sort indices in descending order to pop correctly
        sorted_indices = sorted(card_indices, reverse=True)
        
        selected_cards = []
        # First retrieve them to preserve order of selection? 
        # Actually, usually order of selection matters for filling blanks.
        # But if we pop from back, we mess up referencing by original index.
        # So we should gather cards first, then remove them.
        
        for idx in card_indices:
            selected_cards.append(player.hand[idx])
            
        player.submitted_cards = selected_cards
        
        # Remove from hand (using the sorted descending indices)
        for idx in sorted_indices:
            player.hand.pop(idx)
            
        # Check if all non-czar players have submitted
        all_submitted = all(len(p.submitted_cards) > 0 or p.is_czar for p in self.players.values())
        if all_submitted:
            self.state = "SELECTION"
        return True

    def pick_winner(self, czar_id: str, winner_player_id: str):
        """Handles the Czar picking a winner."""
        czar = self.players.get(czar_id)
        if not czar or not czar.is_czar or self.state != "SELECTION":
            return False

        winner = self.players.get(winner_player_id)
        if winner and winner.submitted_cards:
            winner.score += 1
            self.last_winner = winner.name
            self.state = "RESULTS"
            return True
        return False

    def get_game_state(self, player_id: Optional[str] = None) -> Dict[str, Any]:
        """Returns the current game state, optionally filtered for a specific player."""
        state = {
            "state": self.state,
            "players": [p.to_dict() for p in self.players.values()],
            "current_black_card": self.current_black_card.to_dict() if self.current_black_card else None,
            "last_winner": self.last_winner,
        }
        
        if player_id and player_id in self.players:
            player = self.players[player_id]
            state["hand"] = [card.to_dict() for card in player.hand]
            state["is_czar"] = player.is_czar
        
        # In SELECTION phase, show submitted cards (anonymized)
        if self.state == "SELECTION" or self.state == "RESULTS":
            submissions = []
            for p_id, p in self.players.items():
                if p.submitted_cards:
                    filled_text = ""
                    if self.current_black_card:
                        filled_text = self.current_black_card.fill_gaps(p.submitted_cards)

                    submissions.append({
                        "player_id": p_id, 
                        # Actually Czar shouldn't know who submitted what, 
                        # but for simplicity in this implementation we'll send IDs.
                        # Real CAH anonymizes this.
                        "cards": [c.to_dict() for c in p.submitted_cards],
                        "filled_text": filled_text
                    })
            # Shuffle submissions to anonymize for Czar
            if self.state == "SELECTION":
                random.shuffle(submissions)
            state["submissions"] = submissions
            
        return state
