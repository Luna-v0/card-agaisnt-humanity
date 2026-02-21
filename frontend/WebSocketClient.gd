extends Node
class_name WebSocketClient

signal connection_established(protocol: String)
signal connection_closed(was_clean: bool)
signal connection_error()
signal message_received(message: String)

var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED

func connect_to_url(url: String) -> int:
    var err = socket.connect_to_url(url)
    if err != OK:
        return err
    last_state = socket.get_ready_state()
    return OK

func poll():
    socket.poll()
    var state = socket.get_ready_state()
    
    if last_state != state:
        if state == WebSocketPeer.STATE_OPEN:
            connection_established.emit(socket.get_selected_protocol())
        elif state == WebSocketPeer.STATE_CLOSED:
            var code = socket.get_close_code()
            var reason = socket.get_close_reason()
            connection_closed.emit(code != -1)
    
    last_state = state
    
    if state == WebSocketPeer.STATE_OPEN:
        while socket.get_available_packet_count() > 0:
            var packet = socket.get_packet()
            message_received.emit(packet.get_string_from_utf8())
            
    if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
        pass
    else:
        # If it was connecting and now it's not and not open, it's an error
        if last_state == WebSocketPeer.STATE_CONNECTING:
             connection_error.emit()

func send_text(message: String) -> int:
    return socket.send_text(message)

func close(code: int = 1000, reason: String = ""):
    socket.close(code, reason)

func is_connected_to_host() -> bool:
    return socket.get_ready_state() == WebSocketPeer.STATE_OPEN
