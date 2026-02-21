# Welcome to the CAH Backend Documentation

This project provides a WebSocket-based backend for a Cards Against Humanity (CAH) style game. It is built using [FastAPI](https://fastapi.tiangolo.com/), [WebSockets](https://fastapi.tiangolo.com/advanced/websockets/), and Python.

## Key Features

*   **WebSocket API**: Real-time communication between the frontend (Godot) and the backend.
*   **Game Management**: Handles player joining, game state, round transitions, and scoring.
*   **Card System**: Loads white (answers) and black (questions) cards from a CSV file.
*   **Multi-Card Submissions**: Supports black cards with multiple gaps (e.g., "Step 1: _, Step 2: _").
*   **Czar View**: Provides the Czar with a preview of how the submitted cards fit into the black card text.

## Project Structure

*   `main.py`: The entry point for the FastAPI application and WebSocket endpoint.
*   `src/game.py`: Contains the `GameManager` and `Player` classes, handling the core game logic.
*   `src/cards.py`: Handles loading and processing cards, including filling in the blanks.
*   `cards.csv`: The source file for the game's card content.
*   `frontend/`: Contains the Godot project files for the game client.
