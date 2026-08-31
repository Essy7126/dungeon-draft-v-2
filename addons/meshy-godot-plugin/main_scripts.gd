@tool
extends CenterContainer

var bridge_running = false
var tcp_server: TCPServer
var peerTCP: StreamPeerTCP
var _peer_receive_buffer := PackedByteArray()
var _peer_request_deadline_msec := 0
var server_port = 5325
var editor_interface: EditorInterface

const BRIDGE_BIND_ADDRESS := "127.0.0.1"
const ALLOWED_WEB_ORIGINS := [
	"https://meshy.ai",
	"https://www.meshy.ai",
]
const ALLOWED_IMPORT_FORMATS := [
	# Keep this list aligned with _import_model's magic-byte detection. Text
	# glTF and OBJ were previously accepted by the HTTP endpoint but could never
	# pass the importer, which made the bridge acknowledge doomed jobs.
	"fbx", "glb", "zip",
]
const ALLOWED_DOWNLOAD_DOMAIN := "meshy.ai"
const HTTP_MAX_HEADER_BYTES := 16 * 1024
const HTTP_MAX_BODY_BYTES := 64 * 1024
const HTTP_REQUEST_TIMEOUT_MSEC := 5000
const BLOCKED_ZIP_EXTENSIONS := [
	"bat", "cmd", "cs", "dll", "dylib", "exe", "gd", "gdc", "gdextension",
	"gdshader", "gdshaderinc", "godot", "import", "pck", "ps1", "py", "res",
	"scn", "sh", "so", "tscn", "tres", "uid",
]

# --- Download / import progress toast (bottom-right editor overlay) ---
var _active_download: HTTPRequest = null
var _progress_panel: PanelContainer = null
var _progress_title: Label = null
var _progress_detail: Label = null
var _progress_bar: ProgressBar = null
var _progress_hide_at_msec: int = 0
var _next_import_request_id := 1
var _import_jobs := {}

func _ready():
	tcp_server = TCPServer.new()
	
	# 检查editor_interface是否已初始化
	print("_ready: editor_interface initialization status: ", editor_interface != null)

	# update status label
	_update_status_label()

func _process(_delta):
	# process request every frame
	# print(bridge_running, tcp_server, tcp_server.get_local_port(), tcp_server.is_connection_available())
	# Process one short-lived HTTP/1.1 connection at a time. In particular, do
	# not replace peerTCP while an earlier request is still being assembled: TCP
	# is a byte stream and headers/body routinely arrive in several frames.
	if bridge_running and tcp_server and peerTCP == null \
			and tcp_server.is_connection_available():
		peerTCP = tcp_server.take_connection()
		_peer_receive_buffer = PackedByteArray()
		_peer_request_deadline_msec = (
			Time.get_ticks_msec() + HTTP_REQUEST_TIMEOUT_MSEC
		)
	if peerTCP != null:
		# https://docs.godotengine.org/en/stable/classes/class_streampeertcp.html#class-streampeertcp
		var request_peer := peerTCP
		_handle_peer_tcp(request_peer)
	# Keep the download/import progress toast in sync each frame.
	_update_download_progress()


func _update_status_label():
	var status_label = $VBoxContainer/StatusLabel
	if status_label:
		status_label.text = "Bridge: " + ("Running" if bridge_running else "Stopped")
	
	# update button text
	var bridge_button = $VBoxContainer/Bridge
	if bridge_button:
		bridge_button.text = "Stop Meshy Bridge" if bridge_running else "Run Meshy Bridge"

# --- Progress toast -----------------------------------------------------------
# A small non-blocking overlay pinned to the editor's bottom-right corner, so the
# user sees download/import progress on any main-screen tab (not just the Meshy
# tab, and without watching the Output console).

func _ensure_progress_ui() -> void:
	if _progress_panel and is_instance_valid(_progress_panel):
		return
	if not editor_interface:
		return
	var base = editor_interface.get_base_control()
	if not base:
		return

	_progress_panel = PanelContainer.new()
	_progress_panel.name = "MeshyProgressToast"
	_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin the panel's bottom-right corner 20px from the editor's bottom-right
	# corner and let it grow up-left to fit its content, so text is never
	# clipped regardless of the editor font scale / HiDPI. (A fixed-size rect
	# was too small for the scaled font and overflowed.)
	_progress_panel.anchor_left = 1.0
	_progress_panel.anchor_top = 1.0
	_progress_panel.anchor_right = 1.0
	_progress_panel.anchor_bottom = 1.0
	_progress_panel.offset_left = -20.0
	_progress_panel.offset_top = -20.0
	_progress_panel.offset_right = -20.0
	_progress_panel.offset_bottom = -20.0
	_progress_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_progress_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_progress_panel.add_child(margin)

	var vb = VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	_progress_title = Label.new()
	_progress_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_title.text = "Meshy"
	vb.add_child(_progress_title)

	_progress_detail = Label.new()
	_progress_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_progress_detail)

	_progress_bar = ProgressBar.new()
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.custom_minimum_size = Vector2(300, 0)
	vb.add_child(_progress_bar)

	base.add_child(_progress_panel)
	_progress_panel.visible = false

func _show_progress(title: String, detail: String, ratio: float) -> void:
	_ensure_progress_ui()
	if not _progress_panel:
		return
	_progress_panel.visible = true
	_progress_title.text = title
	_progress_detail.text = detail
	if ratio < 0.0:
		# Indeterminate phase (e.g. importing): hide the bar, keep the text.
		_progress_bar.visible = false
	else:
		_progress_bar.visible = true
		_progress_bar.value = clampf(ratio, 0.0, 1.0) * 100.0

func _finish_progress(detail: String) -> void:
	# Show a final line, then auto-hide the toast shortly after.
	_show_progress("Meshy", detail, 1.0)
	_progress_hide_at_msec = Time.get_ticks_msec() + 2500

func _update_download_progress() -> void:
	# Poll the active download's byte counts and reflect them in the toast.
	if _active_download and is_instance_valid(_active_download):
		var total = _active_download.get_body_size()
		var got = _active_download.get_downloaded_bytes()
		if total > 0:
			var pct = float(got) / float(total)
			_show_progress("Meshy · Downloading model",
				"%d%%  (%.1f / %.1f MB)" % [int(pct * 100.0), got / 1048576.0, total / 1048576.0], pct)
		else:
			_show_progress("Meshy · Downloading model", "%.1f MB downloaded" % (got / 1048576.0), -1.0)
	# Auto-hide once the finish timer elapses.
	if _progress_hide_at_msec > 0 and Time.get_ticks_msec() >= _progress_hide_at_msec:
		_progress_hide_at_msec = 0
		if _progress_panel and is_instance_valid(_progress_panel):
			_progress_panel.visible = false

func _exit_tree() -> void:
	# The toast is parented to the editor base control (not to us), so free it
	# explicitly on unload to avoid leaving an orphan overlay behind.
	if _progress_panel and is_instance_valid(_progress_panel):
		_progress_panel.queue_free()
		_progress_panel = null
	if peerTCP != null:
		peerTCP.disconnect_from_host()
		peerTCP = null
		_peer_receive_buffer = PackedByteArray()
		_peer_request_deadline_msec = 0

# 创建一个新的3D场景
func _create_new_3d_scene() -> Node3D:
	if not editor_interface:
		return null
	
	# 创建新的3D根节点
	var root = Node3D.new()
	root.name = "MeshyScene"
	
	# 使用编辑器接口创建新场景
	# 首先需要将根节点包装成PackedScene并保存
	var packed_scene = PackedScene.new()
	packed_scene.pack(root)
	
	# 生成唯一的场景文件路径
	var scene_path = "res://imported_models/meshy_scene_%d.tscn" % Time.get_unix_time_from_system()
	
	# 确保目录存在
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://imported_models"):
		dir.make_dir("res://imported_models")
	
	# 保存场景
	var error = ResourceSaver.save(packed_scene, scene_path)
	if error != OK:
		print("ERROR: Cannot save new scene: ", error)
		root.queue_free()
		return null
	
	# 在编辑器中打开这个场景
	editor_interface.open_scene_from_path(scene_path)
	
	# 获取编辑后的场景根节点
	var edited_root = editor_interface.get_edited_scene_root()
	if edited_root:
		print("New 3D scene created and opened: ", scene_path)
		return edited_root
	else:
		print("ERROR: Failed to get edited scene root after opening")
		return null

func _on_open_meshy_pressed() -> void:
	OS.shell_open("https://www.meshy.ai/")

func _on_run_bridge_pressed():
	bridge_running = !bridge_running
	
	if bridge_running:
		# start server
		var error = tcp_server.listen(server_port, BRIDGE_BIND_ADDRESS)
		if error != OK:
			print("ERROR: cannot start server: ", error)
			bridge_running = false
		else:
			print(
				"Meshy Bridge started on ", BRIDGE_BIND_ADDRESS, ":", server_port
			)
	else:
		# stop server
		tcp_server.stop()
		if peerTCP != null:
			peerTCP.disconnect_from_host()
			peerTCP = null
			_peer_receive_buffer = PackedByteArray()
			_peer_request_deadline_msec = 0
		print("Meshy Bridge stopped")
	
	# update status label
	_update_status_label()

func _handle_peer_tcp(client: StreamPeerTCP) -> void:
	# Capture the peer for the full operation. A later connection must never
	# receive (or close) a response belonging to this request.
	if client == null or client != peerTCP:
		return
	if _peer_request_deadline_msec > 0 \
			and Time.get_ticks_msec() > _peer_request_deadline_msec:
		_send_json_response(
			client,
			{"status": "error", "message": "HTTP request timed out"},
			408
		)
		_release_peer(client, false)
		return
	var poll_error := client.poll()
	if poll_error != OK:
		_release_peer(client, true)
		return
	var available := client.get_available_bytes()
	if available > 0:
		var data := client.get_data(available)
		if data[0] != OK:
			_release_peer(client, true)
			return
		var parsed := _consume_http_fragment(_peer_receive_buffer, data[1])
		_peer_receive_buffer = parsed.get("buffer", PackedByteArray())
		match str(parsed.get("state", "error")):
			"waiting":
				return
			"ready":
				_handle_http_request(client, parsed.get("request", {}))
				_release_peer(client, false)
				return
			_:
				_send_json_response(
					client,
					{
						"status": "error",
						"message": str(parsed.get("message", "Malformed HTTP request")),
					},
					int(parsed.get("status_code", 400))
				)
				_release_peer(client, false)
				return
	var status := client.get_status()
	if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		_release_peer(client, false)


func _release_peer(client: StreamPeerTCP, disconnect := false) -> void:
	if disconnect and client != null:
		client.disconnect_from_host()
	if client == peerTCP:
		peerTCP = null
		_peer_receive_buffer = PackedByteArray()
		_peer_request_deadline_msec = 0

func _consume_http_fragment(
		receive_buffer: PackedByteArray,
		fragment: PackedByteArray
) -> Dictionary:
	var maximum_request_size := HTTP_MAX_HEADER_BYTES + HTTP_MAX_BODY_BYTES
	if receive_buffer.size() > maximum_request_size \
			or fragment.size() > maximum_request_size - receive_buffer.size():
		return _http_parse_error(
			PackedByteArray(),
			413,
			"HTTP request exceeds the bridge limit"
		)
	var buffer := receive_buffer.duplicate()
	buffer.append_array(fragment)
	var header_end := _find_http_header_end(buffer)
	if header_end < 0:
		if buffer.size() > HTTP_MAX_HEADER_BYTES:
			return _http_parse_error(buffer, 431, "HTTP headers are too large")
		return {"state": "waiting", "buffer": buffer}
	var complete_header_size := header_end + 4
	if complete_header_size > HTTP_MAX_HEADER_BYTES:
		return _http_parse_error(buffer, 431, "HTTP headers are too large")
	var head_bytes := buffer.slice(0, header_end)
	if not _is_valid_http_head_bytes(head_bytes):
		return _http_parse_error(buffer, 400, "Malformed HTTP headers")
	var parsed_head := _parse_http_head(head_bytes.get_string_from_ascii())
	if not bool(parsed_head.get("ok", false)):
		return _http_parse_error(
			buffer,
			int(parsed_head.get("status_code", 400)),
			str(parsed_head.get("message", "Malformed HTTP request"))
		)
	var content_length := int(parsed_head.get("content_length", 0))
	if content_length > HTTP_MAX_BODY_BYTES:
		return _http_parse_error(buffer, 413, "HTTP request body is too large")
	var expected_size := complete_header_size + content_length
	if buffer.size() > expected_size:
		return _http_parse_error(buffer, 400, "HTTP body exceeds Content-Length")
	if buffer.size() < expected_size:
		return {"state": "waiting", "buffer": buffer}
	var request: Dictionary = parsed_head.get("request", {})
	request["body_bytes"] = buffer.slice(complete_header_size, expected_size)
	return {
		"state": "ready",
		"buffer": buffer,
		"request": request,
	}


func _find_http_header_end(bytes: PackedByteArray) -> int:
	if bytes.size() < 4:
		return -1
	for index in range(bytes.size() - 3):
		if bytes[index] == 13 and bytes[index + 1] == 10 \
				and bytes[index + 2] == 13 and bytes[index + 3] == 10:
			return index
	return -1


func _is_valid_http_head_bytes(bytes: PackedByteArray) -> bool:
	for byte in bytes:
		# HTTP field syntax is ASCII. Permit CR/LF separators and horizontal tab
		# inside values, but reject NUL, other controls and non-ASCII octets.
		if byte > 126:
			return false
		if byte < 32 and byte != 9 and byte != 10 and byte != 13:
			return false
	return true


func _parse_http_head(head: String) -> Dictionary:
	var lines := head.split("\r\n", true)
	if lines.is_empty():
		return {"ok": false, "message": "Missing HTTP request line"}
	var request_line := lines[0].split(" ", false)
	if request_line.size() != 3 or request_line[2] != "HTTP/1.1":
		return {"ok": false, "message": "Malformed HTTP request line"}
	var method := str(request_line[0])
	var path := str(request_line[1])
	if method not in ["GET", "POST", "OPTIONS"] or not path.begins_with("/") \
			or _contains_control_character(path):
		return {"ok": false, "message": "Unsupported HTTP request line"}
	var headers := {}
	for index in range(1, lines.size()):
		var line := str(lines[index])
		if line.is_empty() or line.begins_with(" ") or line.begins_with("\t") \
				or line.contains("\r") or line.contains("\n"):
			return {"ok": false, "message": "Malformed HTTP header"}
		var separator := line.find(":")
		if separator <= 0:
			return {"ok": false, "message": "Malformed HTTP header"}
		var name := line.left(separator).to_lower()
		if not _is_valid_http_header_name(name) or headers.has(name):
			return {"ok": false, "message": "Duplicate or malformed HTTP header"}
		headers[name] = line.substr(separator + 1).strip_edges()
	if headers.has("transfer-encoding"):
		return {
			"ok": false,
			"message": "Transfer-Encoding is not supported",
		}
	var content_length := 0
	if headers.has("content-length"):
		var raw_length := str(headers["content-length"])
		if not _is_ascii_decimal(raw_length) or raw_length.length() > 10:
			return {"ok": false, "message": "Malformed Content-Length"}
		content_length = int(raw_length)
		if content_length > HTTP_MAX_BODY_BYTES:
			return {
				"ok": false,
				"status_code": 413,
				"message": "HTTP request body is too large",
			}
	elif method == "POST":
		return {
			"ok": false,
			"status_code": 411,
			"message": "Content-Length is required",
		}
	if method != "POST" and content_length != 0:
		return {"ok": false, "message": "Request body is not allowed for this method"}
	return {
		"ok": true,
		"content_length": content_length,
		"request": {
			"method": method,
			"path": path,
			"headers": headers,
		},
	}


func _is_valid_http_header_name(name: String) -> bool:
	if name.is_empty():
		return false
	for index in range(name.length()):
		var codepoint := name.unicode_at(index)
		var is_letter := codepoint >= 97 and codepoint <= 122
		var is_digit := codepoint >= 48 and codepoint <= 57
		if not is_letter and not is_digit and not "!#$%&'*+-.^_`|~".contains(
				char(codepoint)
		):
			return false
	return true


func _is_ascii_decimal(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint < 48 or codepoint > 57:
			return false
	return true


func _http_parse_error(
		buffer: PackedByteArray,
		status_code: int,
		message: String
) -> Dictionary:
	return {
		"state": "error",
		"buffer": buffer,
		"status_code": status_code,
		"message": message,
	}


func _handle_http_request(client, request: Dictionary) -> void:
	var method := str(request.get("method", ""))
	var path := str(request.get("path", ""))
	var headers: Dictionary = request.get("headers", {})
	var origin := str(headers.get("origin", "")).strip_edges()
	if not _is_allowed_origin(origin):
		_send_json_response(
			client,
			{"status": "error", "message": "Origin not allowed"},
			403
		)
		return
	# print("HTTP request: ", method, " ", path)

	var response = {}
	
	# handle request
	if method == "GET" and (path == "/status" or path == "/ping"):
		# return status info
		response = {
			"status": "ok",
			"dcc": "godot",
			"version": Engine.get_version_info().string
		}
		_send_json_response(client, response, 200, origin)
	elif method == "GET" and path.begins_with("/imports/"):
		var import_id := path.trim_prefix("/imports/")
		if import_id.is_empty() or not _import_jobs.has(import_id):
			_send_json_response(
				client,
				{"status": "error", "message": "Import request not found"},
				404,
				origin
			)
		else:
			_send_json_response(client, _import_jobs[import_id], 200, origin)
	elif  path == "/import":
		if method == "OPTIONS":
			_send_cors_headers(client, origin)
		elif method == "POST":
			var raw_content_type := str(headers.get("content-type", ""))
			var content_type := ""
			if not raw_content_type.is_empty():
				var content_type_parts := raw_content_type.split(";", false)
				if not content_type_parts.is_empty():
					content_type = content_type_parts[0].strip_edges().to_lower()
			if content_type != "application/json":
				_send_json_response(
					client,
					{"status": "error", "message": "Content-Type must be application/json"},
					415,
					origin
				)
				return
			var body_bytes: PackedByteArray = request.get("body_bytes", PackedByteArray())
			var body := body_bytes.get_string_from_utf8()
			var json = JSON.parse_string(body)
			if not _is_valid_import_payload(json):
				_send_json_response(
					client,
					{"status": "error", "message": "Invalid import payload"},
					400,
					origin
				)
				return
			var import_payload: Dictionary = json
			var accepted := _queue_import_request(import_payload)
			if not bool(accepted.get("accepted", false)):
				_send_json_response(
					client,
					{
						"status": "error",
						"message": str(accepted.get("message", "Import could not be queued")),
					},
					int(accepted.get("status_code", 503)),
					origin
				)
				return
			_send_import_accepted_response(
				client,
				str(accepted["import_id"]),
				origin
			)
		else:
			# return error response
			response = {
				"status": "error",
				"message": "Invalid request format"
			}
			_send_json_response(client, response, 400, origin)
	else:
		# return 404 response
		response = {
			"status": "path not found"
		}
		_send_json_response(client, response, 404, origin)


func _is_allowed_origin(origin: String) -> bool:
	# Native clients do not send Origin. Browser callers must be Meshy itself.
	return origin.is_empty() or ALLOWED_WEB_ORIGINS.has(origin.to_lower())


func _is_valid_import_payload(payload: Variant) -> bool:
	if typeof(payload) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = payload
	# Valider exactement la chaîne qui sera transmise à HTTPRequest : ne jamais
	# normaliser silencieusement une URL différente de celle reçue.
	var url := str(data.get("url", ""))
	var format := str(data.get("format", "")).strip_edges().to_lower()
	return _is_safe_download_url(url) and ALLOWED_IMPORT_FORMATS.has(format)


func _is_safe_download_url(url: String) -> bool:
	var trimmed_url := url.strip_edges()
	if url != trimmed_url or _contains_control_character(trimmed_url):
		return false
	var lower := trimmed_url.to_lower()
	if not lower.begins_with("https://"):
		return false
	var remainder := lower.substr("https://".length())
	var authority_end := remainder.length()
	for separator in ["/", "?", "#"]:
		var separator_index := remainder.find(separator)
		if separator_index >= 0:
			authority_end = mini(authority_end, separator_index)
	var authority := remainder.left(authority_end)
	if authority.is_empty() or authority.contains("@"):
		return false
	# Meshy currently provides DNS hostnames. Refusing IP literals avoids the
	# many alternate IPv4/IPv6 spellings that can bypass textual private-range
	# checks (for example ::ffff:127.0.0.1 or octal IPv4 components).
	if authority.begins_with("["):
		return false
	var port_separator := authority.find(":")
	if authority.count(":") > 1:
		return false
	var host := authority.left(port_separator) if port_separator >= 0 else authority
	var port := authority.substr(port_separator + 1) if port_separator >= 0 else ""
	if port_separator >= 0 and port != "443":
		return false
	host = host.trim_suffix(".")
	if host.is_empty() or not host.contains("."):
		return false
	for label in host.split("."):
		if label.is_empty() or label.begins_with("-") or label.ends_with("-"):
			return false
		for index in range(label.length()):
			var codepoint := label.unicode_at(index)
			var is_letter := codepoint >= 97 and codepoint <= 122
			var is_digit := codepoint >= 48 and codepoint <= 57
			if not is_letter and not is_digit and codepoint != 45:
				return false
	# A domain allow-list prevents DNS rebinding and public-host SSRF without
	# trying to duplicate an IP resolver in request validation.
	return host == ALLOWED_DOWNLOAD_DOMAIN or host.ends_with(
		"." + ALLOWED_DOWNLOAD_DOMAIN
	)


func _send_cors_headers(client, origin := ""):
	var response = "HTTP/1.1 200 OK\r\n"
	if not origin.is_empty():
		response += "Access-Control-Allow-Origin: " + origin + "\r\n"
		response += "Vary: Origin\r\n"
		# Chromium's Private Network Access preflight requires this when a public
		# Meshy page calls a loopback bridge. Origin validation above keeps the
		# permission scoped to Meshy.
		response += "Access-Control-Allow-Private-Network: true\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Access-Control-Max-Age: 86400\r\n"
	response += "Content-Length: 0\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	
	client.put_data(response.to_utf8_buffer())
	client.disconnect_from_host()

func _send_json_response(client, data, status_code = 200, origin := ""):
	var json = JSON.stringify(data)
	var response = "HTTP/1.1 %d %s\r\n" % [
		status_code,
		_http_reason_phrase(status_code),
	]
	response += "Content-Type: application/json\r\n"
	if not origin.is_empty() and _is_allowed_origin(origin):
		response += "Access-Control-Allow-Origin: " + origin + "\r\n"
		response += "Vary: Origin\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Content-Length: " + str(json.to_utf8_buffer().size()) + "\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	response += json
	
	client.put_data(response.to_utf8_buffer())
	client.disconnect_from_host()


func _send_import_accepted_response(client, import_id: String, origin := "") -> void:
	_send_json_response(client, {
		"status": "accepted",
		"import_id": import_id,
		"status_url": "/imports/" + import_id,
		"message": "Download and import queued",
	}, 202, origin)


func _http_reason_phrase(status_code: int) -> String:
	match status_code:
		200:
			return "OK"
		202:
			return "Accepted"
		400:
			return "Bad Request"
		403:
			return "Forbidden"
		404:
			return "Not Found"
		408:
			return "Request Timeout"
		409:
			return "Conflict"
		411:
			return "Length Required"
		413:
			return "Content Too Large"
		415:
			return "Unsupported Media Type"
		431:
			return "Request Header Fields Too Large"
		503:
			return "Service Unavailable"
		_:
			return "Error"

# Turn the webapp-supplied model name into a filesystem-safe file/dir name.
# Reserved characters (\ / : * ? " < > | and control chars) are stripped, but
# spaces are kept so the folder reads naturally ("Cute Dragon"). Trailing dots
# and spaces are trimmed because Windows rejects them on folder names.
func _sanitize_name(raw: String) -> String:
	var out := raw.strip_edges()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\n", "\r", "\t"]:
		out = out.replace(ch, "_")
	for index in range(out.length() - 1, -1, -1):
		var codepoint := out.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			out = out.erase(index, 1)
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges()
	while out.ends_with(".") or out.ends_with(" "):
		out = out.substr(0, out.length() - 1)
	# Windows interprets these names as devices, extension comprise. They must
	# not become directories under imported_models/.
	var device_name := out.get_slice(".", 0).to_upper()
	if device_name in ["CON", "PRN", "AUX", "NUL"] \
			or _is_numbered_windows_device(device_name):
		out = "Meshy_" + out
	# Keep enough headroom for the generated suffix, file name and import files.
	if out.length() > 96:
		out = out.left(96).strip_edges()
		while out.ends_with(".") or out.ends_with(" "):
			out = out.left(out.length() - 1)
	return out

# Recover a model name from the download URL when the request carries no `name`.
# The backend already embeds the resolved (family) model name in the signed
# URL's filename, e.g.
#   https://assets.meshy.ai/uploads/Meshy_AI_Breeze_Scout_0623093444_texture.glb?Expires=…
# We strip the query string and extension, then peel off Meshy's "Meshy_AI_"
# prefix and the trailing "_<timestamp>_<stage>" so it reads as "Breeze Scout".
# If the filename doesn't match that convention we fall back to the raw basename
# rather than guessing.
func _name_from_url(url: String) -> String:
	if url == "":
		return ""
	# Drop the query string, keep the last path segment, strip the extension.
	var raw := url.split("?")[0].get_file().get_basename()
	if raw == "":
		return ""
	var re := RegEx.new()
	re.compile("^Meshy_AI_(.+?)_\\d{6,}")
	var m := re.search(raw)
	if m:
		# Underscores stand in for spaces in Meshy's download filenames.
		return m.get_string(1).replace("_", " ")
	# Unknown naming convention: use the raw basename as-is.
	return raw

# Create a dedicated subfolder for one imported model and return its res:// path.
# On a name clash (re-importing the same model) append _1, _2, … so a new import
# never clobbers an earlier copy that may still be referenced in a scene.
func _make_unique_dir(parent_dir: String, base_name: String) -> String:
	var dir = DirAccess.open(parent_dir)
	if not dir:
		# Fallback: return a path without the uniqueness check if the dir won't open.
		return parent_dir.path_join(base_name)
	var candidate = base_name
	var n = 1
	while dir.dir_exists(candidate):
		candidate = "%s_%d" % [base_name, n]
		n += 1
	dir.make_dir(candidate)
	return parent_dir.path_join(candidate)


func _queue_import_request(json_payload: Dictionary) -> Dictionary:
	# The importer has one download and one recognition slot. Reject overlap
	# explicitly instead of acknowledging a second request that would overwrite
	# the first one's progress state.
	if (_active_download and is_instance_valid(_active_download)) \
			or not _pending_import_path.is_empty() \
			or not _pending_import_id.is_empty():
		return {
			"accepted": false,
			"status_code": 409,
			"message": "Another Meshy import is already in progress",
		}
	var import_id := "meshy-%d-%d" % [
		int(Time.get_unix_time_from_system()),
		_next_import_request_id,
	]
	_next_import_request_id += 1
	_import_jobs[import_id] = {
		"status": "queued",
		"import_id": import_id,
	}
	if not _download_and_import_file(json_payload, import_id):
		_import_jobs[import_id] = {
			"status": "failed",
			"import_id": import_id,
			"message": "Download could not be started",
		}
		return {
			"accepted": false,
			"status_code": 503,
			"message": "Download could not be started",
		}
	return {
		"accepted": true,
		"import_id": import_id,
	}


func _set_import_job_status(
		import_id: String,
		status: String,
		message := ""
) -> void:
	if import_id.is_empty():
		return
	var job := {
		"status": status,
		"import_id": import_id,
	}
	if not message.is_empty():
		job["message"] = message
	_import_jobs[import_id] = job


func _download_and_import_file(json_payload, import_id := "") -> bool:
	print("Starting file download: ", json_payload.url, " format: ", json_payload.format)
	
	# download file
	var http = HTTPRequest.new()
	# Do not let an allow-listed URL redirect the editor towards a local or
	# otherwise untrusted endpoint after validation.
	http.max_redirects = 0
	add_child(http)
	# connect signal
	http.connect(
		"request_completed",
		_on_download_completed.bind(json_payload, import_id)
	)

	# Track this request so _process can poll its byte counts for the toast.
	_active_download = http
	_show_progress("Meshy · Downloading model", "Starting…", 0.0)

	# start download
	var error = http.request(json_payload.url)
	if error != OK:
		print("ERROR: download request failed: ", error)
		_active_download = null
		_finish_progress("Download failed")
		http.queue_free()
		return false
	_set_import_job_status(import_id, "downloading")
	return true


func _on_download_completed(
		result,
		response_code,
		headers,
		body,
		json_payload,
		import_id := ""
):
	print("Download completed: result=", result, " response_code=", response_code, " data_size=", body.size())

	# Stop polling the request for progress and release the node.
	if _active_download and is_instance_valid(_active_download):
		_active_download.queue_free()
	_active_download = null

	if result != HTTPRequest.RESULT_SUCCESS:
		print("ERROR: download failed: ", result)
		_finish_progress("Download failed")
		_set_import_job_status(import_id, "failed", "Download failed")
		return

	if response_code != 200:
		print("ERROR: download response code error: ", response_code)
		_finish_progress("Download failed (HTTP %d)" % response_code)
		_set_import_job_status(
			import_id,
			"failed",
			"Download failed (HTTP %d)" % response_code
		)
		return
	
	# Save into a per-model subfolder named after the model, so each model's mesh
	# + textures + materials stay grouped under imported_models/<model name>/
	# instead of a flat pile of timestamp-named files. The webapp already sends
	# the model name in json_payload.name (the same name used for the node).
	var res_dir = "res://imported_models"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(res_dir):
		dir.make_dir(res_dir)

	var base_name = _sanitize_name(json_payload.get("name", ""))
	if base_name == "":
		# No `name` in the request (e.g. an un-renamed remesh/texture child task,
		# whose name lives only on the root task). Recover it from the download
		# URL's filename, which the backend names after the model.
		base_name = _sanitize_name(_name_from_url(json_payload.get("url", "")))
	if base_name == "":
		base_name = "Meshy_Model"

	# A fresh subfolder per import (suffixed _1/_2 on name clash). Reuse the
	# actual folder leaf (e.g. "Breeze Scout_1") for the file AND node names, so a
	# re-imported same-named model gets a unique, predictable node name that
	# matches its folder. Otherwise both nodes are "Meshy_Breeze Scout" and Godot
	# silently auto-dedups the second to "Meshy_Breeze Scout2".
	var model_dir = _make_unique_dir(res_dir, base_name)
	var unique_name = model_dir.get_file()
	var file_name = unique_name + "." + json_payload.format
	var file_path = model_dir.path_join(file_name)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# save file
		file.store_buffer(body)
		file.flush()
		file = null
		
		# ensure file exists and is accessible
		if FileAccess.file_exists(file_path):
			# _wait_for_file_recognition triggers a single up-front filesystem
			# scan and then polls until the import lands (with a GLTFDocument
			# fallback on timeout).
			print("File saved, waiting for Godot to recognize it...")

			# Remember the unique folder name so _continue_import names the imported
			# node to match its folder exactly (including any _1/_2 suffix).
			_pending_import_name = unique_name
			_pending_import_id = import_id
			_set_import_job_status(import_id, "processing")

			_show_progress("Meshy · Importing", "Processing model…", -1.0)

			# 使用定时器等待文件识别
			_wait_for_file_recognition(file_path)
		else:
			print("ERROR: file not found: ", file_path)
			_set_import_job_status(import_id, "failed", "Downloaded file was not saved")
	else:
		print("ERROR: cannot save file: ", file_path)
		_set_import_job_status(import_id, "failed", "Downloaded file could not be written")

# 存储待导入的文件路径和重试信息
var _pending_import_path: String = ""
# 来自前端请求 body 的模型名(与其它 bridge 对齐:优先用请求 name,缺失时回退文件名)
var _pending_import_name: String = ""
var _pending_import_id: String = ""
var _pending_import_retries: int = 0
const IMPORT_MAX_RETRIES: int = 30  # 使用常量避免脚本重载时被重置
var _import_check_timer: Timer = null

# 修改_wait_for_file_recognition函数，使用Timer而不是await（避免脚本重载问题）
func _wait_for_file_recognition(file_path: String) -> void:
	print("Waiting for file recognition: ", file_path)
	
	# 存储待导入的文件路径
	_pending_import_path = file_path
	_pending_import_retries = 0

	# Trigger ONE filesystem scan up front so the editor imports the file we
	# just wrote even while it is unfocused. Godot otherwise only rescans on
	# focus, so ResourceLoader never sees the file and we fall back to the
	# uncompressed GLTFDocument path. Scanning once, early, also lets the import
	# finish before any later focus-scan, avoiding the duplicate
	# "Task 'reimport' already exists" race.
	if editor_interface:
		var fs = editor_interface.get_resource_filesystem()
		if fs and not fs.is_scanning():
			fs.scan()

	# 如果已有定时器在运行，先停止
	if _import_check_timer and is_instance_valid(_import_check_timer):
		_import_check_timer.stop()
		_import_check_timer.queue_free()
	
	# 创建定时器
	_import_check_timer = Timer.new()
	_import_check_timer.wait_time = 0.3
	_import_check_timer.one_shot = false
	add_child(_import_check_timer)
	
	# 连接超时信号
	_import_check_timer.timeout.connect(_on_import_check_timeout)
	
	# 启动定时器
	_import_check_timer.start()

func _on_import_check_timeout() -> void:
	if _pending_import_path.is_empty():
		if _import_check_timer:
			_import_check_timer.stop()
			_import_check_timer.queue_free()
			_import_check_timer = null
		return
		
	_pending_import_retries += 1
	print("Waiting for file recognition... Attempts: ", _pending_import_retries)
	
	# 检查文件是否已被识别
	if ResourceLoader.exists(_pending_import_path):
		print("File recognized: ", _pending_import_path)
		var path_to_import = _pending_import_path
		_pending_import_path = ""
		
		if _import_check_timer:
			_import_check_timer.stop()
			_import_check_timer.queue_free()
			_import_check_timer = null
		
		# 延迟调用以确保文件系统完全就绪
		call_deferred("_continue_import", path_to_import)
		return
	
	# The up-front scan (in _wait_for_file_recognition) drives the import; here
	# we only poll. If recognition never lands, the timeout below imports via
	# GLTFDocument as a fallback.
		
	if _pending_import_retries >= IMPORT_MAX_RETRIES:
		print("File recognition timeout! Attempting to import anyway...")
		var path_to_import = _pending_import_path
		_pending_import_path = ""
		
		if _import_check_timer:
			_import_check_timer.stop()
			_import_check_timer.queue_free()
			_import_check_timer = null
		
		# 即使超时也尝试导入（会使用 GLTFDocument 后备方案）
		call_deferred("_continue_import", path_to_import)

# 添加新函数，继续导入过程
func _continue_import(file_path: String) -> void:
	# 优先使用前端请求 body 里的 name(与 Unity/Blender/3dsMax/Maya 对齐),
	# 为空时回退到从下载文件名推断
	var name = _pending_import_name if _pending_import_name != "" else file_path.get_file().get_basename()

	var json_payload = {
		# "format": format, # 格式将在_import_model中检测
		"name": name
	}
	
	# 导入模型
	var import_id := _pending_import_id
	_pending_import_id = ""
	var handed_to_importer := _import_model(file_path, json_payload)
	# Some importers (notably FBX) continue asynchronously after this hand-off.
	# Report that fact honestly; individual importer logs/toasts remain the source
	# of final success or failure until they expose a completion signal.
	if handed_to_importer:
		_set_import_job_status(import_id, "handed_to_importer")
		_finish_progress("Import processing started: " + name)
	else:
		_set_import_job_status(
			import_id,
			"failed",
			"Downloaded file is not a supported model"
		)
		_finish_progress("Import failed: unsupported model")


func _import_model(file_path, json_payload) -> bool:
	print("Preparing to detect and import model: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("ERROR: Cannot open file for type detection: ", file_path)
		return false
		
	# 读取文件头部的魔数 (读取更多字节以检测FBX)
	var magic_bytes = file.get_buffer(21) # FBX magic number is 21 bytes long
	file.close() # 检测后关闭文件
	
	var detected_format = ""
	
	if magic_bytes.size() >= 21: # Check for FBX magic number
		# FBX Magic Number: "Kaydara FBX Binary  \x00"
		var fbx_magic = PackedByteArray([0x4B, 0x61, 0x79, 0x64, 0x61, 0x72, 0x61, 0x20, 0x46, 0x42, 0x58, 0x20, 0x42, 0x69, 0x6E, 0x61, 0x72, 0x79, 0x20, 0x20, 0x00])
		if magic_bytes.slice(0, 21) == fbx_magic:
			detected_format = "fbx"
	
	if detected_format.is_empty(): # Only check for GLB and ZIP if FBX isn't detected
		if magic_bytes.size() >= 4:
			# 检查GLB魔数 "glTF" (0x676C5446)
			if magic_bytes[0] == 0x67 and magic_bytes[1] == 0x6C and magic_bytes[2] == 0x54 and magic_bytes[3] == 0x46:
				detected_format = "glb"
			# 检查ZIP魔数 "PK" (0x504B) - 只需要前两个字节
			elif magic_bytes[0] == 0x50 and magic_bytes[1] == 0x4B:
				detected_format = "zip"
			
	if detected_format.is_empty():
		print("ERROR: Unknown or unsupported file format. Magic bytes: ", magic_bytes.hex_encode())
		return false

	print("Detected file format: ", detected_format)
	
	# 使用检测到的格式进行处理
	match detected_format:
		"glb":
			_import_gltf(file_path, json_payload.name)
		"fbx":
			_import_fbx(file_path, json_payload.name)
		"zip":
			_import_zip(file_path, json_payload.name)
		_:
			print("Unsupported format (logical error): ", detected_format)
			return false
	return true

func _import_gltf(file_path, name):
	print("Starting GLTF/GLB import")
	
	# 检查编辑器接口
	if not editor_interface:
		print("ERROR: editor_interface is null")
		return
		
	# 检查场景根，如果没有打开的场景则创建一个新场景
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		print("No open scene, creating a new 3D scene...")
		edited_scene_root = _create_new_3d_scene()
		if not edited_scene_root:
			print("ERROR: Failed to create new scene")
			return
		
	print("Scene root node: ", edited_scene_root.name)
	
	# 创建容器节点
	var container = Node3D.new()
	container.name = "Meshy_" + (name if name else "Model")
	
	# 添加到当前场景
	edited_scene_root.add_child(container)
	container.owner = edited_scene_root
	
	# 使用ResourceLoader加载场景
	print("Loading model: ", file_path)
	var resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
	
	if resource:
		print("Resource loaded successfully: ", resource.get_class())
		
		# 根据资源类型进行处理
		if resource is PackedScene:
			# 实例化场景
			var scene_instance = resource.instantiate()
			print("Scene instantiated successfully: ", scene_instance.get_class())
			
			# 添加到容器
			container.add_child(scene_instance)
			
			# 递归设置所有节点的所有权为场景根
			_recursive_set_owner(scene_instance, edited_scene_root)
			
			# 将实例保存为场景中的本地资源
			print("Converting instance to local resource")
			scene_instance.owner = edited_scene_root
			
			# 将动画和材质等资源转为本地
			_make_resources_local(scene_instance)
		else:
			print("Resource is not PackedScene type, cannot instantiate")
			container.queue_free()
			return
	else:
		print("Resource loading failed, attempting with GLTFDocument")
		
		var gltf = GLTFDocument.new()
		var state = GLTFState.new()
		var error = gltf.append_from_file(file_path, state)
		
		if error == OK:
			var scene = gltf.generate_scene(state)
			if scene:
				# 添加到容器
				container.add_child(scene)
				
				# 设置所有权
				_recursive_set_owner(scene, edited_scene_root)
				
				# 将动画和材质等资源转为本地
				_make_resources_local(scene)
				
				print("GLTFDocument import successful")
			else:
				print("ERROR: Scene generation failed")
				container.queue_free()
				return
		else:
			print("GLTF/GLB import failed, error code: ", error)
			container.queue_free()
			return
	
	# 通知编辑器刷新和选择新节点
	editor_interface.get_selection().clear()
	editor_interface.get_selection().add_node(container)
	
	# 标记场景为已修改，以便保存
	edited_scene_root.set_meta("__editor_changed", true)
	
	print("GLTF/GLB import successful: ", file_path)

func _import_fbx(file_path, name):
	print("Starting FBX import")
	
	# 检查编辑器接口
	if not editor_interface:
		print("ERROR: editor_interface is null")
		return
		
	# 检查场景根，如果没有打开的场景则创建一个新场景
	var edited_scene_root = editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		print("No open scene, creating a new 3D scene...")
		edited_scene_root = _create_new_3d_scene()
		if not edited_scene_root:
			print("ERROR: Failed to create new scene")
			return
		
	print("Scene root node: ", edited_scene_root.name)
	
	# 创建容器节点
	var container = Node3D.new()
	container.name = "Meshy_" + (name if name else "Model")
	
	# 添加到当前场景
	edited_scene_root.add_child(container)
	container.owner = edited_scene_root
	
	# 使用ResourceLoader加载场景
	print("Loading model: ", file_path)
	# Godot 4.x has native FBX import support
	
	var resource = null
	var retry_count = 0
	var max_retries = 10 # Max retries
	var retry_delay = 0.2 # seconds
	
	# Try loading the resource with retries
	while retry_count < max_retries:
		resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
		if resource:
			print("Resource loaded successfully (attempts: ", retry_count + 1, "): ", resource.get_class())
			break # Successfully loaded, exit loop
		
		print("Resource loading failed, retrying... (attempts: ", retry_count + 1, ")")
		retry_count += 1
		await get_tree().create_timer(retry_delay).timeout # Wait before retrying
		
	if resource:
		# 根据资源类型进行处理
		if resource is PackedScene:
			# 实例化场景
			var scene_instance = resource.instantiate()
			print("Scene instantiated successfully: ", scene_instance.get_class())
			
			# 添加到容器
			container.add_child(scene_instance)
			
			# 递归设置所有节点的所有权为场景根
			_recursive_set_owner(scene_instance, edited_scene_root)
			
			# 将实例保存为场景中的本地资源
			print("Converting instance to local resource")
			scene_instance.owner = edited_scene_root
			
			# 将动画和材质等资源转为本地
			_make_resources_local(scene_instance)
		else:
			print("Resource is not PackedScene type, cannot instantiate")
			container.queue_free()
			return
	else:
		print("FBX import failed: Could not load resource (max retries reached). Please ensure FBX importer is correctly set up or the file is valid.")
		container.queue_free()
		return
	
	# 通知编辑器刷新和选择新节点
	editor_interface.get_selection().clear()
	editor_interface.get_selection().add_node(container)
	
	# 标记场景为已修改，以便保存
	edited_scene_root.set_meta("__editor_changed", true)
	
	print("FBX import successful: ", file_path)

# 将节点及其子节点中的所有资源转为本地资源
func _make_resources_local(node):
	# 检查并处理动画播放器
	if node is AnimationPlayer:
		_make_animations_local(node)
	
	# 处理网格实例
	if node is MeshInstance3D:
		_make_mesh_local(node)
	
	# 递归处理所有子节点
	for child in node.get_children():
		_make_resources_local(child)

# 将动画播放器中的动画转为本地资源
func _make_animations_local(anim_player: AnimationPlayer):
	# Godot 4.x 使用 AnimationLibrary 管理动画
	var library_names = anim_player.get_animation_library_list()
	
	for lib_name in library_names:
		var library = anim_player.get_animation_library(lib_name)
		if not library:
			continue
			
		# 制作库的副本
		var local_library = AnimationLibrary.new()
		var animation_names = library.get_animation_list()
		
		for anim_name in animation_names:
			var animation = library.get_animation(anim_name)
			if animation:
				# 制作动画的副本
				var local_animation = animation.duplicate()
				local_library.add_animation(anim_name, local_animation)
				print("Animation converted to local: ", lib_name + "/" + anim_name if lib_name else anim_name)
		
		# 移除旧库并添加新的本地库
		anim_player.remove_animation_library(lib_name)
		anim_player.add_animation_library(lib_name, local_library)
	
	print("All animations converted to local")

# 将网格实例中的网格和材质转为本地资源
func _make_mesh_local(mesh_instance):
	var mesh = mesh_instance.mesh
	if mesh:
		# 制作网格的副本
		var local_mesh = mesh.duplicate()
		mesh_instance.mesh = local_mesh
		
		# 处理网格中的材质
		var material_count = local_mesh.get_surface_count()
		for i in range(material_count):
			var material = local_mesh.surface_get_material(i)
			if material:
				# 制作材质的副本
				var local_material = material.duplicate()
				local_mesh.surface_set_material(i, local_material)
		
		print("Mesh and materials converted to local")

# 递归设置所有节点的所有权
func _recursive_set_owner(node, owner):
	for child in node.get_children():
		child.owner = owner
		_recursive_set_owner(child, owner)

# 计算子节点数量的辅助函数
func _count_children(node):
	var count = 0
	for child in node.get_children():
		count += 1 + _count_children(child)
	return count

func _import_zip(file_path, name):
	print("Starting ZIP file processing: ", file_path, " name: ", name)
	
	var zip_reader = ZIPReader.new()
	var err = zip_reader.open(file_path)
	
	if err != OK:
		print("ERROR: Cannot open ZIP file: ", err)
		return

	var files_in_zip = zip_reader.get_files()
	if files_in_zip.is_empty():
		print("WARNING: ZIP file is empty.")
		zip_reader.close()
		return

	# Extract into the model's own folder (the directory the downloaded zip was
	# saved into by _on_download_completed), so the FBX and its textures land
	# under imported_models/<model name>/ next to each other — not in a separate
	# extracted_<name>_<timestamp> folder.
	var extract_path = file_path.get_base_dir()

	var dir_access = DirAccess.open("res://")
	if not dir_access:
		print("ERROR: Cannot access resource directory")
		zip_reader.close()
		return

	if not DirAccess.dir_exists_absolute(extract_path):
		err = dir_access.make_dir_recursive(extract_path)
		if err != OK:
			print("ERROR: Cannot create extraction directory: ", extract_path, " error code: ", err)
			zip_reader.close()
			return

	print("Extracting to directory: ", extract_path)

	var fbx_found = false
	var extracted_fbx_path = ""

	# 提取文件
	for file_in_zip in files_in_zip:
		var target_file_path := _safe_zip_target(extract_path, file_in_zip)
		if target_file_path.is_empty():
			print("WARNING: Refusing unsafe ZIP entry: ", file_in_zip)
			continue
		if file_in_zip.ends_with("/") or file_in_zip.ends_with("\\"):
			continue
		if not _is_safe_zip_content(file_in_zip):
			print("WARNING: Refusing active ZIP content: ", file_in_zip)
			continue
		var file_data = zip_reader.read_file(file_in_zip)
		
		# 确保目标文件的父目录存在 (处理ZIP内的目录结构)
		var target_dir = target_file_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(target_dir):
			err = dir_access.make_dir_recursive(target_dir)
			if err != OK:
				print("WARNING: Cannot create subdirectory: ", target_dir, " file: ", file_in_zip)
				continue # 跳过这个文件

		# 写入文件
		var file_access = FileAccess.open(target_file_path, FileAccess.WRITE)
		if file_access:
			file_access.store_buffer(file_data)
			file_access.close()
			print("Extracted: ", target_file_path)
			
			# 检查是否是FBX文件
			if file_in_zip.get_extension().to_lower() == "fbx":
				fbx_found = true
				extracted_fbx_path = target_file_path
		else:
			print("ERROR: Cannot write extracted file: ", target_file_path)

	zip_reader.close()
	print("ZIP file extraction complete: ", extract_path)
	
	# 不手动调用 filesystem.scan()，让 Godot 自动检测新文件
	# 这样可以避免与自动导入冲突产生的 "Task 'reimport' already exists" 错误
	print("ZIP extraction complete, waiting for Godot to recognize files...")

	# 如果在ZIP中找到FBX文件，则导入它
	if fbx_found:
		print("FBX file found in ZIP, starting import: ", extracted_fbx_path)
		# 调用 _wait_for_file_recognition 等待FBX文件被识别
		_wait_for_file_recognition(extracted_fbx_path)
	else:
		print("WARNING: No FBX model found in ZIP. Skipping model import.")
	
	# 删除原始的（可能错误命名的）ZIP文件
	var remove_err = DirAccess.remove_absolute(file_path)
	if remove_err == OK:
		print("Successfully deleted original ZIP file: ", file_path)
	else:
		print("ERROR: Failed to delete original ZIP file: ", file_path, " error code: ", remove_err)


func _safe_zip_target(extract_path: String, archive_entry: String) -> String:
	var normalized_entry := archive_entry.replace("\\", "/")
	if normalized_entry != normalized_entry.strip_edges():
		return ""
	if normalized_entry.is_empty() or normalized_entry.begins_with("/"):
		return ""
	var components := normalized_entry.split("/", false)
	for component in components:
		if not _is_safe_zip_component(component):
			return ""
	var root := extract_path.simplify_path().trim_suffix("/")
	if root.is_empty():
		return ""
	var target := root.path_join(normalized_entry).simplify_path()
	if target != root and not target.begins_with(root + "/"):
		return ""
	return target


func _is_safe_zip_component(component: String) -> bool:
	if component.is_empty() or component == "." or component == "..":
		return false
	if component != component.strip_edges() or component.ends_with("."):
		return false
	if component.contains(":"):
		return false
	if _contains_control_character(component):
		return false
	# Windows treats these device names specially even when an extension is
	# present. Rejecting them also keeps extraction behavior cross-platform.
	var device_name := component.get_slice(".", 0).to_upper()
	if device_name in ["CON", "PRN", "AUX", "NUL"]:
		return false
	if _is_numbered_windows_device(device_name):
		return false
	return true


func _is_numbered_windows_device(device_name: String) -> bool:
	if not device_name.begins_with("COM") and not device_name.begins_with("LPT"):
		return false
	var suffix := device_name.substr(3)
	return suffix.length() == 1 and suffix.is_valid_int() \
		and int(suffix) >= 1 and int(suffix) <= 9


func _is_safe_zip_content(archive_entry: String) -> bool:
	var extension := archive_entry.replace("\\", "/").get_extension().to_lower()
	return not BLOCKED_ZIP_EXTENSIONS.has(extension)


func _contains_control_character(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return true
	return false

	
