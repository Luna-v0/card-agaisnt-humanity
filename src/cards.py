import csv
from typing import List, Dict, Any

class Card:
    """Represents a single game card (white or black)."""
    def __init__(self, card_type: str, text: str):
        self.card_type = card_type
        self.text = text

    @property
    def num_gaps(self) -> int:
        if "Preta" not in self.card_type:
            return 0
        count = self.text.count("_")
        return max(1, count) # At least 1 gap if it's a black card

    def to_dict(self) -> Dict[str, Any]:
        """Returns the card as a dictionary."""
        return {
            "card_type": self.card_type, 
            "text": self.text,
            "num_gaps": self.num_gaps if "Preta" in self.card_type else 0
        }

    def fill_gaps(self, white_cards: List['Card']) -> str:
        """Fills the gaps in a black card with the text from white cards."""
        if "Preta" not in self.card_type:
            return self.text
        
        result = self.text
        if "_" not in result:
            # If no gaps, append white card text
            white_text = " ".join([c.text for c in white_cards])
            return f"{result} {white_text}"
        
        for white_card in white_cards:
            result = result.replace("_", f"[{white_card.text}]", 1)
        
        return result

def load_cards_from_csv(file_path: str) -> List[Card]:
    """
    Loads cards from a CSV file.

    Args:
        file_path: The path to the CSV file.

    Returns:
        A list of Card objects.
    """
    cards = []
    with open(file_path, mode='r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            card_type = row["Tipo da carta"]
            card_text = row["Texto da carta"]
            cards.append(Card(card_type, card_text))
    return cards

if __name__ == "__main__":
    # Example usage:
    cards_data = load_cards_from_csv("cards.csv")
    print(f"Loaded {len(cards_data)} cards.")
    for i, card in enumerate(cards_data[:5]): # Print first 5 cards
        print(f"Card {i+1}: Type={card.card_type}, Text={card.text}")
