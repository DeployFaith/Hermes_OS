class_name HermesGatewayClient
extends RefCounted

signal response_received(payload: Dictionary)
signal error_received(message: String, details: Dictionary)
signal status_changed(status: Dictionary)

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8643
const DEFAULT_PATH := "/v1/chat/completions"
const DEFAULT_MODEL := "hermesos"
const DEFAULT_PROFILE_HINT := "hermesos"
const DEFAULT_API_KEY := ""
const DEFAULT_TIMEOUT_SECONDS := 120.0

var _shell: Node
var _request: HTTPRequest
var _host: String = DEFAULT_HOST
var _port: int = DEFAULT_PORT
var _path: String = DEFAULT_PATH
var _model: String = DEFAULT_MODEL
var _profile_hint: String = DEFAULT_PROFILE_HINT
var _api_key: String = DEFAULT_API_KEY
var _timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
var _busy: bool = false
var _last_error: Dictionary = {}
var _last_response: Dictionary = {}
var _last_latency_ms: int = 0
var _started_msec: int = 0
var _pending_prompt: String = ""
var _pending_context: Dictionary = {}

func gateway_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	configure(context.get("gateway", {}) if context.get("gateway", {}) is Dictionary else {})
	_ensure_request_node()
	_emit_status_changed()

func configure(config: Dictionary = {}) -> void:
	_host = str(config.get("gateway_host", _host)).strip_edges()
	if _host == "":
		_host = DEFAULT_HOST
	_port = int(config.get("gateway_port", _port))
	_path = str(config.get("gateway_path", _path)).strip_edges()
	if _path == "":
		_path = DEFAULT_PATH
	if not _path.begins_with("/"):
		_path = "/" + _path
	_model = str(config.get("gateway_model", _model)).strip_edges()
	if _model == "":
		_model = DEFAULT_MODEL
	_profile_hint = str(config.get("gateway_profile_hint", _profile_hint)).strip_edges()
	if _profile_hint == "":
		_profile_hint = DEFAULT_PROFILE_HINT
	_api_key = str(config.get("gateway_api_key", _api_key)).strip_edges()
	_timeout_seconds = float(config.get("gateway_timeout_seconds", _timeout_seconds))
	if _timeout_seconds <= 0.0:
		_timeout_seconds = DEFAULT_TIMEOUT_SECONDS
	if _request != null:
		_request.timeout = _timeout_seconds
	_emit_status_changed()

func get_status() -> Dictionary:
	return {
		"configured": _host != "" and _port > 0 and _path != "",
		"busy": _busy,
		"endpoint": _endpoint_url(),
		"host": _host,
		"port": _port,
		"path": _path,
		"model": _model,
		"profile_hint": _profile_hint,
		"auth_required": _api_key != "",
		"api_key_present": _api_key != "",
		"api_key_length": _api_key.length(),
		"last_latency_ms": _last_latency_ms,
		"last_error": _last_error.duplicate(true),
		"last_response": _last_response.duplicate(true)
	}

func send_message(prompt: String, options: Dictionary = {}) -> Dictionary:
	var clean_prompt := prompt.strip_edges()
	if clean_prompt == "":
		return _fail("MISSING_PROMPT", "Usage: hermes <prompt>")
	if _busy:
		return _fail("REQUEST_IN_PROGRESS", "Hermes Gateway request already in progress")
	if _ensure_request_node() == null:
		return _fail("REQUEST_UNAVAILABLE", "Hermes Gateway HTTP client is unavailable")
	if _api_key == "":
		return _fail("GATEWAY_API_KEY_MISSING", "Hermes Gateway API key is not configured.")

	_pending_prompt = clean_prompt
	_pending_context = options.duplicate(true)
	_last_error.clear()
	_last_response.clear()
	_last_latency_ms = 0
	_started_msec = Time.get_ticks_msec()
	_busy = true
	_emit_status_changed()

	var messages: Array = []
	var system_text := str(options.get("system", "")).strip_edges()
	if system_text != "":
		messages.append({"role": "system", "content": system_text})
	messages.append({"role": "user", "content": clean_prompt})
	var body := JSON.stringify({
		"model": _model,
		"messages": messages,
		"stream": false
	})
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if _api_key != "":
		headers.append("Authorization: " + "Bearer " + _api_key)
	var err := _request.request(_endpoint_url(), headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		return _fail("REQUEST_START_FAILED", "Could not start Hermes Gateway request", {"godot_error": err})
	return {"ok": true, "terminal_result": "Sent to Hermes Gateway: " + clean_prompt, "endpoint": _endpoint_url()}

func cancel() -> Dictionary:
	if not _busy:
		return {"ok": true, "cancelled": false}
	if _request != null:
		_request.cancel_request()
	_busy = false
	var details := {"code": "REQUEST_CANCELLED", "endpoint": _endpoint_url()}
	_last_error = details.duplicate(true)
	_last_error["message"] = "Hermes Gateway request cancelled"
	error_received.emit("Hermes Gateway request cancelled", _last_error.duplicate(true))
	_emit_status_changed()
	return {"ok": true, "cancelled": true}

func _ensure_request_node() -> HTTPRequest:
	if _request != null and is_instance_valid(_request):
		return _request
	if _shell == null or not is_instance_valid(_shell):
		return null
	_request = HTTPRequest.new()
	_request.name = "HermesGatewayHTTPRequest"
	_request.timeout = _timeout_seconds
	_request.use_threads = true
	_shell.add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	return _request

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	_last_latency_ms = Time.get_ticks_msec() - _started_msec if _started_msec > 0 else 0
	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_request_error("GATEWAY_UNAVAILABLE", "Hermes Gateway unavailable: " + _endpoint_url(), {"result": result, "response_code": response_code, "body": body_text})
		return
	if response_code == 401:
		_emit_request_error("GATEWAY_UNAUTHORIZED", "Hermes Gateway unauthorized. Check gateway_api_key / HERMES_GATEWAY_API_KEY.", {"response_code": response_code, "body": body_text, "auth_required": _api_key != ""})
		return
	if response_code < 200 or response_code >= 300:
		_emit_request_error("HTTP_" + str(response_code), "Hermes Gateway returned HTTP " + str(response_code), {"response_code": response_code, "body": body_text})
		return
	var parsed: Variant = JSON.parse_string(body_text)
	if not (parsed is Dictionary):
		_emit_request_error("INVALID_JSON", "Hermes Gateway returned invalid JSON", {"body": body_text})
		return
	var data: Dictionary = parsed
	var assistant_text := _extract_assistant_text(data)
	_last_response = {
		"ok": true,
		"assistant_text": assistant_text,
		"raw": data.duplicate(true),
		"endpoint": _endpoint_url(),
		"latency_ms": _last_latency_ms,
		"prompt": _pending_prompt,
		"context": _pending_context.duplicate(true)
	}
	response_received.emit(_last_response.duplicate(true))
	_emit_status_changed()

func _extract_assistant_text(data: Dictionary) -> String:
	var choices: Array = data.get("choices", []) if data.get("choices", []) is Array else []
	if choices.is_empty():
		return ""
	var first: Dictionary = choices[0] if choices[0] is Dictionary else {}
	var message: Dictionary = first.get("message", {}) if first.get("message", {}) is Dictionary else {}
	var content: Variant = message.get("content", "")
	if content is String:
		return (content as String).strip_edges()
	return str(content).strip_edges()

func _emit_request_error(code: String, message: String, details: Dictionary = {}) -> void:
	_last_error = details.duplicate(true)
	_last_error["code"] = code
	_last_error["message"] = message
	_last_error["endpoint"] = _endpoint_url()
	_last_error["latency_ms"] = _last_latency_ms
	error_received.emit(message, _last_error.duplicate(true))
	_emit_status_changed()

func _fail(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var error := details.duplicate(true)
	error["code"] = code
	error["message"] = message
	error["endpoint"] = _endpoint_url()
	_last_error = error.duplicate(true)
	_emit_status_changed()
	return {"ok": false, "terminal_result": message, "error": error}

func _endpoint_url() -> String:
	return "http://" + _host + ":" + str(_port) + _path

func _emit_status_changed() -> void:
	status_changed.emit(get_status())
