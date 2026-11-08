class_name GameDatabase
extends Node
## Infrastructure: the game's link to the local SpacetimeDB database `database-narrator` (task-048). Talks the plain
## HTTP API: POST /v1/identity for a token, POST /v1/database/<db>/sql to read tables, POST .../call/<reducer> to write.
## Starts from the bundled seed (DbConfig.seed_path) so the game works with the server offline, then replaces the
## tables with the server's copy. Polls `config_version`; when the god tool bumps it, every table is read again.
## Speaks upward only through its signals; writers (PlayerRecord, NarrationLibrary) call `call_reducer`.

## The lookup tables changed (seed loaded, server read, or reloaded). `tables`: table name -> Array of row Dictionaries.
signal tables_loaded(tables: Dictionary)
## The server became reachable (true) or unreachable (false).
signal connection_changed(online: bool)

const ROUTE_IDENTITY: String = "/v1/identity"
const ROUTE_DATABASE: String = "/v1/database/"
const VERSION_TABLE: String = "config_version"

@export var config: DbConfig

## Current copy of the lookup tables (table name -> Array[Dictionary]).
var tables: Dictionary = {}
var online: bool = false
## Complete table reads from the server so far: 1 = the first (startup) read, more = reloads after a config_version
## bump (the god tool changed something). Listeners use it to tell god's edits from the startup state.
var server_loads: int = 0

var _token: String = ""
var _version: int = -1
var _query_http: HTTPRequest
var _call_http: HTTPRequest
## Pending SQL reads: Array of [sql, Callable(rows: Array, ok: bool)].
var _queries: Array = []
var _query_busy: bool = false
## Pending reducer calls: Array of [reducer, args].
var _calls: Array = []
var _call_busy: bool = false
var _token_busy: bool = false
var _poll_timer: float = 0.0
## Tables of the reload in progress (filled table by table, published when all arrived).
var _loading: Dictionary = {}


func _ready() -> void:
	if config == null:
		config = DbConfig.new()
	_query_http = _make_http("QueryHttp")
	_call_http = _make_http("CallHttp")
	_load_seed()
	if config.enabled:
		_poll_timer = config.poll_seconds
		_request_token()


func _process(delta: float) -> void:
	if not config.enabled:
		return
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = config.poll_seconds
	if _token == "":
		_request_token()
	elif not _query_busy and _queries.is_empty():
		_poll_version()


## Rows of a table in the current copy (empty when unknown).
func rows(table: String) -> Array:
	return tables.get(table, [])


## Calls a reducer with positional arguments (JSON-encoded). Queued; kept (bounded) while offline.
func call_reducer(reducer: String, args: Array = []) -> void:
	if not config.enabled:
		return
	_calls.append([reducer, args])
	while _calls.size() > config.max_pending_calls:
		_calls.pop_front()
	_pump_calls()


## Reads every configured table again from the server.
func reload() -> void:
	if not config.enabled or _token == "":
		return
	_loading = {}
	for table in config.tables:
		var name: String = table
		_query("SELECT * FROM %s" % name, func(result: Array, ok: bool) -> void: _on_table_read(name, result, ok))


## Parses the SQL HTTP answer (one entry per statement, each {schema: {elements: [{name}]}, rows: [[...]]}) into
## row Dictionaries keyed by column name. Static so tests and tools can use it.
static func parse_sql_result(body: Variant) -> Array:
	var out: Array = []
	if not body is Array or (body as Array).is_empty():
		return out
	var statement: Variant = (body as Array)[0]
	if not statement is Dictionary:
		return out
	var names: PackedStringArray = []
	var schema: Variant = (statement as Dictionary).get("schema", {})
	var elements: Variant = (schema as Dictionary).get("elements", []) if schema is Dictionary else []
	for element: Variant in elements:
		names.append(_column_name(element))
	for raw: Variant in (statement as Dictionary).get("rows", []):
		if not raw is Array:
			continue
		var row: Dictionary = {}
		for i in mini(names.size(), (raw as Array).size()):
			row[names[i]] = _plain((raw as Array)[i])
		out.append(row)
	return out


static func _column_name(element: Variant) -> String:
	if not element is Dictionary:
		return ""
	var name: Variant = (element as Dictionary).get("name", "")
	if name is Dictionary:
		return str((name as Dictionary).get("some", ""))
	return str(name)


## Unwraps the special encodings (Timestamp, Option) into plain values.
static func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var d: Dictionary = value
		if d.size() == 1:
			var key: String = str(d.keys()[0])
			if key == "some" or key.begins_with("__"):
				return _plain(d[key])
			if key == "none":
				return null
	if value is Array and (value as Array).size() == 1 and not ((value as Array)[0] is Array):
		return (value as Array)[0]
	return value


func _make_http(node_name: String) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.name = node_name
	http.timeout = config.request_timeout
	add_child(http)
	return http


func _load_seed() -> void:
	if config.seed_path == "" or not FileAccess.file_exists(config.seed_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config.seed_path))
	if not parsed is Dictionary:
		push_warning("GameDatabase: bad seed at %s" % config.seed_path)
		return
	for table: Variant in parsed:
		if (parsed as Dictionary)[table] is Array:
			tables[str(table)] = (parsed as Dictionary)[table]
	tables_loaded.emit.call_deferred(tables)


func _set_online(value: bool) -> void:
	if value == online:
		return
	online = value
	connection_changed.emit(value)
	if not value:
		_token = ""


func _request_token() -> void:
	if _token_busy:
		return
	_token_busy = true
	var http := HTTPRequest.new()
	http.timeout = config.request_timeout
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		_token_busy = false
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			_set_online(false)
			return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary or str((parsed as Dictionary).get("token", "")) == "":
			_set_online(false)
			return
		_token = str((parsed as Dictionary)["token"])
		_set_online(true)
		reload()
		_pump_calls())
	if http.request(config.base_url + ROUTE_IDENTITY, PackedStringArray(), HTTPClient.METHOD_POST, "") != OK:
		http.queue_free()
		_token_busy = false


func _headers(content_type: String) -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + _token, "Content-Type: " + content_type])


func _query(sql: String, done: Callable) -> void:
	_queries.append([sql, done])
	_pump_queries()


func _pump_queries() -> void:
	if _query_busy or _queries.is_empty() or _token == "":
		return
	var entry: Array = _queries.pop_front()
	var done: Callable = entry[1]
	_query_busy = true
	var url: String = config.base_url + ROUTE_DATABASE + config.database + "/sql"
	var on_done := func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		_query_busy = false
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		if result != HTTPRequest.RESULT_SUCCESS:
			_set_online(false)
			_queries.clear()
		done.call(parse_sql_result(JSON.parse_string(body.get_string_from_utf8())) if ok else [], ok)
		_pump_queries()
	_query_http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	if _query_http.request(url, _headers("text/plain"), HTTPClient.METHOD_POST, entry[0]) != OK:
		_query_http.request_completed.disconnect(on_done)
		_query_busy = false


func _pump_calls() -> void:
	if _call_busy or _calls.is_empty() or _token == "":
		return
	var entry: Array = _calls.front()
	_call_busy = true
	var url: String = config.base_url + ROUTE_DATABASE + config.database + "/call/" + str(entry[0])
	var on_done := func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		_call_busy = false
		if result != HTTPRequest.RESULT_SUCCESS:
			_set_online(false)
			return
		_calls.pop_front()
		if code < 200 or code >= 300:
			push_warning("GameDatabase: reducer %s failed (%d): %s" % [entry[0], code, body.get_string_from_utf8()])
		_pump_calls()
	_call_http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	if _call_http.request(url, _headers("application/json"), HTTPClient.METHOD_POST, JSON.stringify(entry[1])) != OK:
		_call_http.request_completed.disconnect(on_done)
		_call_busy = false


func _poll_version() -> void:
	_query("SELECT * FROM %s" % VERSION_TABLE, func(result: Array, ok: bool) -> void:
		if not ok or result.is_empty():
			return
		var version: int = int((result[0] as Dictionary).get("version", 0))
		if version != _version:
			reload())


func _on_table_read(table: String, result: Array, ok: bool) -> void:
	if not ok:
		return
	_loading[table] = result
	if _loading.size() < config.tables.size():
		return
	for name: String in _loading:
		tables[name] = _loading[name]
	_loading = {}
	var version_rows: Array = tables.get(VERSION_TABLE, [])
	if not version_rows.is_empty():
		_version = int((version_rows[0] as Dictionary).get("version", 0))
	server_loads += 1
	tables_loaded.emit(tables)
