extends GutTest

const MeshyBridgePanel = preload("res://addons/meshy-godot-plugin/main_scripts.gd")


class RecordingPeer:
	extends RefCounted

	var writes: Array[PackedByteArray] = []
	var disconnected := false

	func put_data(data: PackedByteArray) -> Error:
		writes.append(data.duplicate())
		return OK

	func disconnect_from_host() -> void:
		disconnected = true

	func response_text() -> String:
		if writes.is_empty():
			return ""
		return writes[0].get_string_from_utf8()


func _bridge():
	return autofree(MeshyBridgePanel.new())


func test_browser_origin_is_limited_to_meshy() -> void:
	var bridge = _bridge()
	assert_true(bridge._is_allowed_origin("https://www.meshy.ai"))
	assert_true(bridge._is_allowed_origin("https://meshy.ai"))
	assert_true(bridge._is_allowed_origin(""), "les clients natifs n'envoient pas Origin")
	assert_false(bridge._is_allowed_origin("https://example.com"))
	assert_false(bridge._is_allowed_origin("null"))


func test_import_payload_requires_https_and_a_supported_format() -> void:
	var bridge = _bridge()
	assert_true(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/model.glb?signature=fixture",
		"format": "glb",
	}))
	assert_false(bridge._is_valid_import_payload({
		"url": "http://assets.meshy.ai/uploads/model.glb",
		"format": "glb",
	}))
	assert_false(bridge._is_valid_import_payload({
		"url": "https://127.0.0.1/private",
		"format": "glb",
	}))
	assert_false(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/script.exe",
		"format": "exe",
	}))
	assert_false(bridge._is_valid_import_payload({
		"url": "https://example.com/public/model.glb",
		"format": "glb",
	}), "un hote HTTPS public ne doit pas devenir un proxy arbitraire")
	assert_false(bridge._is_valid_import_payload({
		"url": "https://[::ffff:127.0.0.1]/private",
		"format": "glb",
	}), "les litteraux IPv6 ne doivent pas contourner le filtre local")
	assert_false(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai:8443/uploads/model.glb",
		"format": "glb",
	}), "seul le port HTTPS standard est autorise")
	assert_false(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai:/uploads/model.glb",
		"format": "glb",
	}), "un port vide n'est pas une autorite valide")
	assert_false(bridge._is_valid_import_payload({
		"url": "https://evil..assets.meshy.ai/uploads/model.glb",
		"format": "glb",
	}), "les labels DNS vides sont refuses")
	assert_false(bridge._is_valid_import_payload({
		"url": " https://assets.meshy.ai/uploads/model.glb",
		"format": "glb",
	}), "l'URL telechargee doit etre identique a l'URL validee")
	assert_true(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai:443/uploads/model.glb",
		"format": "GLB",
	}))
	assert_true(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/model.fbx",
		"format": "fbx",
	}))
	assert_true(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/model.zip",
		"format": "zip",
	}))
	assert_false(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/model.gltf",
		"format": "gltf",
	}), "le detecteur de l'importeur ne prend pas en charge le glTF texte")
	assert_false(bridge._is_valid_import_payload({
		"url": "https://assets.meshy.ai/uploads/model.obj",
		"format": "obj",
	}), "le detecteur de l'importeur ne prend pas en charge OBJ")


func test_http_request_waits_for_complete_headers_and_exact_utf8_body() -> void:
	var bridge = _bridge()
	var body := JSON.stringify({
		"url": "https://assets.meshy.ai/uploads/model.glb",
		"format": "glb",
		"name": "Dragon dore",
	})
	# Add a multi-byte character without relying on JSON's whitespace/layout.
	body = body.replace("dore", "doré")
	var head := (
		"POST /import HTTP/1.1\r\n"
		+ "Content-Type: application/json\r\n"
		+ "Content-Length: %d\r\n\r\n" % body.to_utf8_buffer().size()
	)
	var request := head.to_utf8_buffer()
	request.append_array(body.to_utf8_buffer())
	var split_header := 19
	var split_body := head.to_utf8_buffer().size() + 3

	var first: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		request.slice(0, split_header)
	)
	assert_eq(first.get("state"), "waiting")
	var second: Dictionary = bridge._consume_http_fragment(
		first.get("buffer", PackedByteArray()),
		request.slice(split_header, split_body)
	)
	assert_eq(second.get("state"), "waiting")
	var complete: Dictionary = bridge._consume_http_fragment(
		second.get("buffer", PackedByteArray()),
		request.slice(split_body)
	)
	assert_eq(complete.get("state"), "ready")
	var parsed_request: Dictionary = complete.get("request", {})
	var parsed_body: PackedByteArray = parsed_request.get(
		"body_bytes",
		PackedByteArray()
	)
	assert_eq(parsed_body.size(), body.to_utf8_buffer().size())
	assert_eq(parsed_body.get_string_from_utf8(), body)


func test_http_parser_rejects_ambiguous_lengths_and_chunked_bodies() -> void:
	var bridge = _bridge()
	var chunked: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\n"
			+ "Transfer-Encoding: chunked\r\n\r\n"
		).to_utf8_buffer()
	)
	assert_eq(chunked.get("state"), "error")
	assert_eq(chunked.get("status_code"), 400)

	var malformed_length: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\n"
			+ "Content-Length: +2\r\n\r\n{}"
		).to_utf8_buffer()
	)
	assert_eq(malformed_length.get("state"), "error")
	assert_eq(malformed_length.get("status_code"), 400)

	var duplicate_length: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\n"
			+ "Content-Length: 2\r\n"
			+ "Content-Length: 2\r\n\r\n{}"
		).to_utf8_buffer()
	)
	assert_eq(duplicate_length.get("state"), "error")
	assert_eq(duplicate_length.get("status_code"), 400)

	var trailing_bytes: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\n"
			+ "Content-Length: 1\r\n\r\n{}"
		).to_utf8_buffer()
	)
	assert_eq(trailing_bytes.get("state"), "error")
	assert_eq(trailing_bytes.get("status_code"), 400)

	var missing_length: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\n"
			+ "Content-Type: application/json\r\n\r\n"
		).to_utf8_buffer()
	)
	assert_eq(missing_length.get("state"), "error")
	assert_eq(missing_length.get("status_code"), 411)


func test_http_parser_enforces_header_and_body_limits() -> void:
	var bridge = _bridge()
	var oversized_headers := (
		"GET /status HTTP/1.1\r\nX-Fill: "
		+ "a".repeat(16 * 1024)
	).to_utf8_buffer()
	var header_result: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		oversized_headers
	)
	assert_eq(header_result.get("state"), "error")
	assert_eq(header_result.get("status_code"), 431)

	var oversized_body: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		(
			"POST /import HTTP/1.1\r\nContent-Length: %d\r\n\r\n"
			% (64 * 1024 + 1)
		).to_utf8_buffer()
	)
	assert_eq(oversized_body.get("state"), "error")
	assert_eq(oversized_body.get("status_code"), 413)


func test_http_response_uses_the_peer_captured_for_that_request() -> void:
	var bridge = _bridge()
	# A different global peer simulates a later accepted connection. Dispatch
	# must still write and close only the peer captured with this request.
	bridge.peerTCP = StreamPeerTCP.new()
	var request_peer := RecordingPeer.new()
	bridge._handle_http_request(request_peer, {
		"method": "GET",
		"path": "/status",
		"headers": {},
		"body_bytes": PackedByteArray(),
	})
	assert_true(request_peer.disconnected)
	assert_eq(request_peer.writes.size(), 1)
	assert_true(request_peer.response_text().begins_with("HTTP/1.1 200 OK\r\n"))
	assert_true(request_peer.response_text().contains("\"status\":\"ok\""))


func test_import_acceptance_is_truthful_and_traceable() -> void:
	var bridge = _bridge()
	var request_peer := RecordingPeer.new()
	bridge._send_import_accepted_response(request_peer, "meshy-fixture-1")
	var response := request_peer.response_text()
	assert_true(response.begins_with("HTTP/1.1 202 Accepted\r\n"))
	assert_true(response.contains("\"status\":\"accepted\""))
	assert_true(response.contains("\"import_id\":\"meshy-fixture-1\""))
	assert_true(response.contains("\"status_url\":\"/imports/meshy-fixture-1\""))
	assert_false(response.contains("imported successfully"))


func test_separate_connection_buffers_do_not_mix_fragments() -> void:
	var bridge = _bridge()
	var first_fragment: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		"GET /ping HTTP/1.1\r\nX-Fixture:".to_utf8_buffer()
	)
	assert_eq(first_fragment.get("state"), "waiting")

	# A newly accepted peer starts with an empty buffer and can complete without
	# inheriting bytes from the earlier peer.
	var second_peer: Dictionary = bridge._consume_http_fragment(
		PackedByteArray(),
		"GET /status HTTP/1.1\r\n\r\n".to_utf8_buffer()
	)
	assert_eq(second_peer.get("state"), "ready")
	assert_eq(second_peer.get("request", {}).get("path"), "/status")

	var first_complete: Dictionary = bridge._consume_http_fragment(
		first_fragment.get("buffer", PackedByteArray()),
		" one\r\n\r\n".to_utf8_buffer()
	)
	assert_eq(first_complete.get("state"), "ready")
	assert_eq(first_complete.get("request", {}).get("path"), "/ping")


func test_zip_entries_cannot_escape_the_model_directory() -> void:
	var bridge = _bridge()
	var root := "res://imported_models/Dragon"
	assert_eq(
		bridge._safe_zip_target(root, "textures/body.png"),
		"res://imported_models/Dragon/textures/body.png"
	)
	assert_eq(bridge._safe_zip_target(root, "../outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "nested/../../outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "C:\\outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "/absolute/outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "nested/.. /outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "nested/.../outside.gd"), "")
	assert_eq(bridge._safe_zip_target(root, "CON.txt"), "")
	assert_eq(bridge._safe_zip_target(root, "tool/installer.gd "), "")


func test_zip_content_cannot_install_active_godot_files() -> void:
	var bridge = _bridge()
	assert_true(bridge._is_safe_zip_content("textures/body.png"))
	assert_true(bridge._is_safe_zip_content("mesh/model.fbx"))
	assert_false(bridge._is_safe_zip_content("tool/installer.gd"))
	assert_false(bridge._is_safe_zip_content("scene/payload.tscn"))
	assert_false(bridge._is_safe_zip_content("model.glb.import"))


func test_model_directory_name_is_portable_and_bounded() -> void:
	var bridge = _bridge()
	assert_eq(bridge._sanitize_name("CON"), "Meshy_CON")
	assert_eq(bridge._sanitize_name("lpt9.model"), "Meshy_lpt9.model")
	assert_false(bridge._sanitize_name("nom\u0001modele").contains("\u0001"))
	assert_lte(bridge._sanitize_name("x".repeat(200)).length(), 96)
