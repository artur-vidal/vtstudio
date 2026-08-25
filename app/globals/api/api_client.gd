extends Node

class PendingRequest extends RefCounted:
	var data: Dictionary = {}
	var completed: bool = false
	
	var response: PackedByteArray
	var response_headers: Dictionary
	
	func _init(_data: Dictionary) -> void:
		self.data = _data

var http: HTTPClient = HTTPClient.new()
var queue: Array[PendingRequest] = []

var current: PendingRequest
var response_body: PackedByteArray = PackedByteArray()
var connected: bool = false

func _ready() -> void:
	http.connect_to_host(Config.API_HOST)

func _process(_delta: float) -> void:
	http.poll()
	
	match http.get_status():
		HTTPClient.Status.STATUS_CONNECTED:
			if current != null:
				current.completed = true
				current.response_headers = http.get_response_headers_as_dictionary()
				current = null
			elif queue.size() > 0:
				current = queue.pop_front()
				response_body.clear()
				http.request(
					current.data.method,
					current.data.path,
					current.data.headers,
					current.data.body
				)
		
		HTTPClient.Status.STATUS_BODY:
			var chunk = http.read_response_body_chunk()
			if chunk.size() > 0:
				current.response.append_array(chunk)

func request(method: HTTPClient.Method, path: String, body: String = "", headers: PackedStringArray = []) -> Variant:
	# temporario, depois crio alguma maneira de fazer requests mais flexíveis
	headers.append_array(["Accept: application/json", "Content-Type: application/json"])
	
	var item = PendingRequest.new({
		"method": method,
		"path": Config.API_DIR + path,
		"body": body,
		"headers": headers,
	})
	
	queue.append(item)
	
	while !item.completed:
		await get_tree().process_frame
	
	var data = JSON.parse_string(item.response.get_string_from_utf8()) if !item.response.is_empty() else {}
	
	return { 
		"data": data,
		"response_headers": item.response_headers,
		"code": http.get_response_code(),
		"ok": str(http.get_response_code()).begins_with('2') # código 2XX
	}
