# Setup and Installation

This guide explains how to set up the development environment for the CAH backend.

## Prerequisites

*   **Python**: Version 3.10 or higher.
*   **uv**: (Optional) A fast Python package manager.

## Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/cah-test.git
    cd cah-test
    ```

2.  Create a virtual environment:
    ```bash
    python -m venv .venv
    ```
    OR using `uv`:
    ```bash
    uv venv
    ```

3.  Activate the virtual environment:
    *   **Linux/macOS**:
        ```bash
        source .venv/bin/activate
        ```
    *   **Windows**:
        ```bash
        .venv\Scripts\activate
        ```

4.  Install dependencies:
    ```bash
    pip install -e .
    ```
    OR using `uv`:
    ```bash
    uv sync
    ```

## Running the Server

Start the server using `uvicorn`:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server will start listening on `ws://0.0.0.0:8000/ws`.

## Frontend Setup

1.  Open Godot 4 (or compatible version).
2.  Import the project located in the `frontend/` directory.
3.  Modify `WS_URL` in `Main.gd` if the backend is running on a different host/port.
4.  Run the project.

## Debugging

To run the game with automatic bots (for testing):

1.  Set the `AUTO_PLAY` environment variable to `true`.
2.  Run the server.
3.  Join as a player. The bots will automatically submit cards.

```bash
AUTO_PLAY=true uvicorn main:app --reload
```
