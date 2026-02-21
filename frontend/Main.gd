extends Control

@onready var ws = $WebSocketClient
@onready var login_container: HBoxContainer = %LoginContainer
@onready var game_container: VBoxContainer = %GameContainer
@onready var name_input: LineEdit = %NameInput
@onready var join_button: Button = %JoinButton
@onready var black_card_label: Label = %BlackCardLabel
@onready var hand_container: GridContainer = %HandContainer
@onready var submissions_container: GridContainer = %SubmissionsContainer
@onready var player_list: ItemList = %PlayerList
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton
@onready var message_log: TextEdit = %MessageLog
@onready var submission_label: Label = %SubmissionLabel

const WS_URL = "ws://127.0.0.1:8000/ws"

var my_hand = []
var is_czar = false
var current_black_card_data = {}
var selected_indices = []

func _ready():
    ws.connection_established.connect(_on_connected)
    ws.connection_closed.connect(_on_closed)
    ws.connection_error.connect(_on_error)
    ws.message_received.connect(_on_message)

    join_button.pressed.connect(_on_join_pressed)
    start_button.pressed.connect(_on_start_pressed)
    ws.connect_to_url(WS_URL)
    
    # Add Quick Play buttons
    var btn_czar = Button.new()
    btn_czar.text = "Quick Play (Czar)"
    btn_czar.pressed.connect(_on_quick_czar)
    login_container.add_child(btn_czar)
    
    var btn_player = Button.new()
    btn_player.text = "Quick Play (Player)"
    btn_player.pressed.connect(_on_quick_player)
    login_container.add_child(btn_player)
    
    # Stylize black card
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color.BLACK
    sb.content_margin_left = 20
    sb.content_margin_right = 20
    black_card_label.add_theme_stylebox_override("normal", sb)
    black_card_label.add_theme_color_override("font_color", Color.WHITE)

func _process(_delta):
    ws.poll()

func _on_connected(_proto):
    status_label.text = "Connected. Please join."

func _on_closed(_clean):
    status_label.text = "Disconnected."

func _on_error():
    print_log("Connection error.")

func _on_join_pressed():
    var name_text = name_input.text.strip_edges()
    if name_text == "": return
    send_message("join", {"name": name_text})
    login_container.visible = false
    game_container.visible = true

func _on_quick_czar():
    var name_text = name_input.text.strip_edges()
    if name_text == "": name_text = "Player"
    send_message("join", {"name": name_text, "mode": "czar"})
    login_container.visible = false
    game_container.visible = true

func _on_quick_player():
    var name_text = name_input.text.strip_edges()
    if name_text == "": name_text = "Player"
    send_message("join", {"name": name_text, "mode": "player"})
    login_container.visible = false
    game_container.visible = true

func _on_start_pressed():
    send_message("start_game", {})

func send_message(type: String, payload: Dictionary):
    var msg = {"type": type, "payload": payload}
    ws.send_text(JSON.stringify(msg))

func _on_message(json_text: String):
    var json = JSON.new()
    var err = json.parse(json_text)
    if err != OK: return
    
    var msg = json.get_data()
    var type = msg.get("type")
    var payload = msg.get("payload")
    
    match type:
        "game_state":
            update_game_state(payload)
        "error":
            print_log("Error: " + payload.get("message", "Unknown error"))

func update_game_state(state: Dictionary):
    var game_phase = state.get("state")
    status_label.text = "Phase: " + game_phase
    
    player_list.clear()
    for p in state.get("players", []):
        var czar_tag = " (CZAR)" if p.get("is_czar") else ""
        var sub_tag = " [OK]" if p.get("has_submitted") else ""
        player_list.add_item("%s: %d pts%s%s" % [p.get("name"), p.get("score"), czar_tag, sub_tag])
    
    var bc = state.get("current_black_card")
    current_black_card_data = bc if bc else {}
    
    if game_phase != "PLAYING":
        selected_indices.clear()

    if bc:
        black_card_label.text = bc.get("text")
    else:
        black_card_label.text = "Waiting for game to start..."
        
    my_hand = state.get("hand", [])
    is_czar = state.get("is_czar", false)
    render_hand()
    
    var submissions = state.get("submissions", [])
    render_submissions(submissions)
    
    start_button.visible = (game_phase == "LOBBY" or game_phase == "RESULTS")
    
    if state.get("last_winner"):
        print_log("Winner: " + state.get("last_winner"))

func _on_card_selected(index: int):
    if is_czar: return
    
    var num_gaps = current_black_card_data.get("num_gaps", 1)
    
    if num_gaps <= 1:
        send_message("submit_card", {"indices": [index]})
        print_log("Submitted card index: " + str(index))
        return
        
    if index in selected_indices:
        selected_indices.erase(index)
        print_log("Deselected card index: " + str(index))
    else:
        selected_indices.append(index)
        print_log("Selected card index: " + str(index))
        
    if selected_indices.size() == num_gaps:
        send_message("submit_card", {"indices": selected_indices})
        print_log("Submitted " + str(num_gaps) + " cards.")
        selected_indices.clear()
    else:
        print_log("Selected " + str(selected_indices.size()) + "/" + str(num_gaps))

func render_hand():
    for child in hand_container.get_children():
        child.queue_free()
    
    if is_czar:
        var l = Label.new()
        l.text = "You are the Czar! Wait for others to submit."
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.size_flags_horizontal = SIZE_EXPAND_FILL
        hand_container.add_child(l)
        return

    for i in range(my_hand.size()):
        var card = my_hand[i]
        var btn = Button.new()
        btn.text = card.get("text")
        btn.custom_minimum_size = Vector2(160, 100) # Shorter cards to fit grid
        btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        btn.add_theme_font_size_override("font_size", 11)
        
        # Stylize white card
        var sb = StyleBoxFlat.new()
        sb.bg_color = Color.WHITE
        sb.set_border_width_all(1)
        sb.border_color = Color.GRAY
        btn.add_theme_stylebox_override("normal", sb)
        btn.add_theme_stylebox_override("hover", sb)
        btn.add_theme_stylebox_override("pressed", sb)
        btn.add_theme_color_override("font_color", Color.BLACK)
        btn.add_theme_color_override("font_hover_color", Color.BLACK)
        btn.add_theme_color_override("font_pressed_color", Color.DARK_GRAY)
        
        btn.pressed.connect(_on_card_selected.bind(i))
        hand_container.add_child(btn)

func render_submissions(submissions: Array):
    for child in submissions_container.get_children():
        child.queue_free()
        
    if submissions.is_empty():
        submission_label.visible = false
        return
        
    submission_label.visible = true
    for sub in submissions:
        var btn = Button.new()
        
        var txt = sub.get("filled_text")
        if not txt:
             var cards = sub.get("cards")
             if cards and cards.size() > 0:
                 txt = cards[0].get("text")
             elif sub.get("card"):
                 txt = sub.get("card").get("text")
             else:
                 txt = "Error"
        
        btn.text = txt
        btn.custom_minimum_size = Vector2(160, 100)
        btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        btn.add_theme_font_size_override("font_size", 11)
        
        # Stylize white card for submission
        var sb = StyleBoxFlat.new()
        sb.bg_color = Color.WHITE
        sb.set_border_width_all(1)
        sb.border_color = Color.GRAY
        btn.add_theme_stylebox_override("normal", sb)
        btn.add_theme_color_override("font_color", Color.BLACK)
        
        if is_czar and status_label.text.contains("SELECTION"):
            btn.disabled = false
            btn.pressed.connect(_on_winner_picked.bind(sub.get("player_id")))
        else:
            btn.disabled = true
            
        submissions_container.add_child(btn)

func _on_winner_picked(player_id: String):
    send_message("pick_winner", {"player_id": player_id})

func print_log(text: String):
    message_log.text += text + "\n"
    message_log.scroll_vertical = message_log.get_v_scroll_bar().max_value
