#!/bin/bash

# Function to kill background processes on exit
cleanup() {
    echo -e "\nShutting down CAH Game..."
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null
    [ -n "$GODOT_PID" ] && kill $GODOT_PID 2>/dev/null
    exit
}

trap cleanup SIGINT SIGTERM

echo "--- Starting CAH Game ---"
export PYTHONUNBUFFERED=1

# Start Backend
uv run python main.py &
SERVER_PID=$!

echo "Waiting for server to start..."
sleep 3

# Start Frontend (Single Instance)
echo "--- Starting Godot Client ---"
godot --path frontend &
GODOT_PID=$!

echo "Game running. Select 'Quick Play (Czar)' or 'Quick Play (Player)' in the menu."
echo "Press Ctrl+C to stop."
wait
