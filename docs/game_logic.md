# Game Logic and Mechanics

## Cards and Decks

The core of the game revolves around two types of cards:

*   **Black Cards**: Contain a sentence or phrase with one or more blanks (`_`). These are the questions or prompts.
*   **White Cards**: Contain a word or phrase that can fill the blank. These are the answers.

The decks are shuffled at the start of each game. Players draw 10 white cards.

## Game States

The `GameManager` (in `src/game.py`) manages the state transitions:

1.  **LOBBY**: Players join and wait for the game to start.
2.  **PLAYING**: The round begins. A Czar is selected, and a black card is drawn. Players (except the Czar) submit cards.
3.  **SELECTION**: All players have submitted. The Czar reviews the submissions (anonymized) and picks a winner.
4.  **RESULTS**: The winner is announced, and points are awarded. The next round starts automatically or manually.

## Multi-Card Submission

Some black cards require multiple answers. The system handles this by checking the number of underscores (`_`) in the black card text.

*   **Example**: "Step 1: _, Step 2: _" requires 2 cards.
*   **Process**:
    1.  The frontend detects the required number of cards.
    2.  The player selects the required number of cards in order.
    3.  The frontend sends a list of indices (`[0, 2]`) to the backend.
    4.  The backend validates the submission (e.g., correct count, valid indices).
    5.  The cards are removed from the player's hand.

## Czar View

When in the `SELECTION` phase, the Czar receives the submissions with the text already filled into the black card. This allows the Czar to read the full sentence as intended.

*   **Example Black Card**: "I drink _ to forget _."
*   **Submission**: ["Milk", "My Ex"]
*   **Czar View**: "I drink [Milk] to forget [My Ex]."

This logic is handled by the `Card.fill_gaps` method in `src/cards.py`.
