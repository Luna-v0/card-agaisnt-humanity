extends Control

@onready var ws = $WebSocketClient
@onready var login_container: HBoxContainer = %LoginContainer
@onready var game_container: VBoxContainer = %GameContainer
@onready var name_input: LineEdit = %NameInput
@onready var join_button: Button = %JoinButton
@onready var black_card_label = %BlackCardLabel
@onready var hand_container = %HandContainer
@onready var submissions_container = %SubmissionsContainer
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
    
    _setup_visuals()

func _setup_visuals():
    # 1. Background & Root
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg = ColorRect.new()
    bg.color = Color("#2C3E50")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    move_child(bg, 0)
    
    if game_container:
        game_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    
    # 2. Side-by-Side Layout
    var main_split = HBoxContainer.new()
    main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_split.add_theme_constant_override("separation", 20)
    
    # Replace BlackCardLabel with RichTextLabel
    if black_card_label.get_parent():
        black_card_label.get_parent().remove_child(black_card_label)
    black_card_label.queue_free()
    
    black_card_label = RichTextLabel.new()
    black_card_label.name = "BlackCardRTL"
    black_card_label.bbcode_enabled = true
    black_card_label.scroll_active = false
    black_card_label.custom_minimum_size = Vector2(280, 380)
    black_card_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    black_card_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    # RTL Styling
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color.BLACK
    sb.corner_radius_top_left = 15
    sb.corner_radius_top_right = 15
    sb.corner_radius_bottom_left = 15
    sb.corner_radius_bottom_right = 15
    sb.content_margin_left = 30
    sb.content_margin_right = 30
    sb.content_margin_top = 40 # Top padding to center vertically somewhat
    sb.content_margin_bottom = 30
    sb.shadow_color = Color(0,0,0,0.5)
    sb.shadow_size = 8
    
    black_card_label.add_theme_stylebox_override("normal", sb)
    black_card_label.add_theme_color_override("default_color", Color.WHITE)
    black_card_label.add_theme_font_size_override("normal_font_size", 22)
    black_card_label.text = "[center]Waiting for game...[/center]"

    # Left Side
    var left_side = CenterContainer.new()
    left_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_side.size_flags_stretch_ratio = 0.35
    left_side.add_child(black_card_label)
    main_split.add_child(left_side)
    
    # Right Side
    var right_side = VBoxContainer.new()
    right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_side.size_flags_stretch_ratio = 0.65
    right_side.alignment = BoxContainer.ALIGNMENT_CENTER
    main_split.add_child(right_side)
    
    # Submissions
    var lbl_sub = Label.new()
    lbl_sub.text = "Submissions:"
    lbl_sub.add_theme_font_size_override("font_size", 16)
    right_side.add_child(lbl_sub)
    
    if submissions_container and is_instance_valid(submissions_container):
        submissions_container.queue_free()
    
    submissions_container = HBoxContainer.new()
    submissions_container.add_theme_constant_override("separation", 15)
    
    var scroll_sub = ScrollContainer.new()
    scroll_sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll_sub.size_flags_stretch_ratio = 0.4
    scroll_sub.custom_minimum_size.y = 240
    scroll_sub.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll_sub.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll_sub.add_child(submissions_container)
    right_side.add_child(scroll_sub)
    
    # Hand (No Scroll, Overlap)
    var lbl_hand = Label.new()
    lbl_hand.text = "Your Hand:"
    lbl_hand.add_theme_font_size_override("font_size", 16)
    right_side.add_child(lbl_hand)
    
    if hand_container and is_instance_valid(hand_container):
        hand_container.queue_free()
    
    hand_container = HBoxContainer.new()
    hand_container.name = "HandHBox"
    hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
    # Negative separation for overlap
    hand_container.add_theme_constant_override("separation", -60)
    
    # Wrapper for hand to center vertically in its space
    var hand_wrapper = CenterContainer.new()
    hand_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hand_wrapper.size_flags_stretch_ratio = 0.6
    hand_wrapper.add_child(hand_container)
    right_side.add_child(hand_wrapper)
    
    # Clean up and Add
    for child in game_container.get_children():
        if child != main_split:
            game_container.remove_child(child)
    game_container.add_child(main_split)

func get_card_style(bg_color: Color) -> StyleBoxFlat:
    var sb = StyleBoxFlat.new()
    sb.bg_color = bg_color
    sb.corner_radius_top_left = 12
    sb.corner_radius_top_right = 12
    sb.corner_radius_bottom_left = 12
    sb.corner_radius_bottom_right = 12
    sb.shadow_color = Color(0,0,0,0.3)
    sb.shadow_size = 4
    sb.border_width_bottom = 2
    sb.border_width_right = 2
    sb.border_color = Color(0,0,0,0.1)
    sb.content_margin_left = 15
    sb.content_margin_right = 15
    sb.content_margin_top = 15
    sb.content_margin_bottom = 15
    return sb

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
        black_card_label.text = "[center]" + bc.get("text") + "[/center]"
    else:
        black_card_label.text = "[center]Waiting for game to start...[/center]"
        
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
    
    render_hand()

func render_hand():
    for child in hand_container.get_children():
        child.queue_free()
    
    if is_czar:
        var l = Label.new()
        l.text = "You are the Czar! Wait for others to submit."
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.add_theme_font_size_override("font_size", 18)
        hand_container.add_child(l)
        return

    for i in range(my_hand.size()):
        var card = my_hand[i]
        
        # Wrapper for overlap effect
        var wrapper = Control.new()
        wrapper.custom_minimum_size = Vector2(100, 220) # Narrower than card
        wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
        
        var btn = Button.new()
        btn.text = card.get("text")
        btn.custom_minimum_size = Vector2(160, 220)
        btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        btn.add_theme_font_size_override("font_size", 14)
        
        # Determine Style
        var is_selected = i in selected_indices
        var bg_color = Color.WHITE
        if is_selected:
            bg_color = Color("#ECF0F1")
            
        var style_normal = get_card_style(bg_color)
        if is_selected:
            style_normal.border_color = Color("#3498DB")
            style_normal.border_width_left = 3
            style_normal.border_width_top = 3
            style_normal.border_width_right = 3
            style_normal.border_width_bottom = 3
            
        var style_hover = get_card_style(Color("#F5F5F5"))
        var style_pressed = get_card_style(Color("#BDC3C7"))
        
        btn.add_theme_stylebox_override("normal", style_normal)
        btn.add_theme_stylebox_override("hover", style_hover)
        btn.add_theme_stylebox_override("pressed", style_pressed)
        
        btn.add_theme_color_override("font_color", Color.BLACK)
        btn.add_theme_color_override("font_hover_color", Color.BLACK)
        btn.add_theme_color_override("font_pressed_color", Color.BLACK)
        
        btn.pressed.connect(_on_card_selected.bind(i))
        btn.mouse_entered.connect(_on_card_hover.bind(btn))
        btn.mouse_exited.connect(_on_card_exit.bind(btn))
        
        wrapper.add_child(btn)
        hand_container.add_child(wrapper)

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
        btn.custom_minimum_size = Vector2(160, 220)
        btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        btn.add_theme_font_size_override("font_size", 14)
        
        # Style
        var style_normal = get_card_style(Color.WHITE)
        var style_hover = get_card_style(Color("#F5F5F5"))
        var style_pressed = get_card_style(Color("#BDC3C7"))
        
        btn.add_theme_stylebox_override("normal", style_normal)
        btn.add_theme_stylebox_override("hover", style_hover)
        btn.add_theme_stylebox_override("pressed", style_pressed)
        
        btn.add_theme_color_override("font_color", Color.BLACK)
        btn.add_theme_color_override("font_hover_color", Color.BLACK)
        btn.add_theme_color_override("font_pressed_color", Color.BLACK)
        
        if is_czar and status_label.text.contains("SELECTION"):
            btn.disabled = false
            btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            btn.pressed.connect(_on_winner_picked.bind(sub.get("player_id")))
            # Czar Interaction: Hover to see filled text
            btn.mouse_entered.connect(_on_submission_hover.bind(sub))
            btn.mouse_exited.connect(_reset_black_card)
        else:
            btn.disabled = true
            btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
            
        submissions_container.add_child(btn)

func _on_card_hover(btn: Button):
    btn.position.y = -40
    btn.z_index = 10

func _on_card_exit(btn: Button):
    btn.position.y = 0
    btn.z_index = 0

func _on_submission_hover(sub: Dictionary):
    var text = sub.get("filled_text", "")
    if text == "": return
    # Replace brackets with color tags
    text = text.replace("[", "[color=#F1C40F]")
    text = text.replace("]", "[/color]")
    black_card_label.text = "[center]" + text + "[/center]"

func _reset_black_card():
    var text = current_black_card_data.get("text", "")
    black_card_label.text = "[center]" + text + "[/center]"

func _on_winner_picked(player_id: String):
    send_message("pick_winner", {"player_id": player_id})

func print_log(text: String):
    message_log.text += text + "\n"
    message_log.scroll_vertical = message_log.get_v_scroll_bar().max_value
