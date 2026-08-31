extends Node

signal server_stopped(success: bool)

var server := TCPServer.new()
var port := Config.GOOGLE_AUTH_SERVER_PORT

var running := false
var expired := false
var state: String = ""
var on_complete: Callable;

var expire_timer: Timer
var server_timer: Timer

var expire_seconds := Config.GOOGLE_AUTH_SERVER_EXPIRE_TIME
var server_ttl := Config.GOOGLE_AUTH_SERVER_TIME_TO_LIVE

@onready var redirect_url := Config.get_api_url() + Config.GOOGLE_LOGIN_PATH
@onready var login_url := redirect_url + "?client_redirect=http://127.0.0.1:" + str(port) + "/callback?state=%s"

func _process(_delta: float) -> void:
	if server.is_listening() and server.is_connection_available():
		var connection := server.take_connection()
		connection.poll()
		
		var available = connection.get_available_bytes()
		if available > 0:
			var authenticated = false
			
			var raw: String = connection.get_utf8_string(available)
			if(raw.begins_with('GET /callback')):
				# parsing da resposta
				var url = raw.split(" ")[1]
				var query = url.split("?")[1] if url.split("?").size() > 1 else ''
				var params = query.split("&")
				var params_dict: Dictionary = {}
				
				for p in params:
					var splitted = p.split("=", true, 1)
					params_dict[splitted[0]] = splitted[1].uri_decode()
				
				# validação
				if params_dict.state == state:
					# pego o código e faço uma requisição pro aplicativo
					var code = params_dict.get('code')
					if(code):
						authenticated = await _exchange_credentials(code)
			
			_stop_server(authenticated)
			
			var response = ""
			if(expired):
				response += "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
				response += FileAccess.get_file_as_string('res://globals/api/auth_pages/expired.html')
			elif(authenticated):
				response += "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
				FileAccess.get_file_as_string('res://globals/api/auth_pages/success.html')
			else:
				response += "HTTP/1.1 401 Unauthorized\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
				response += FileAccess.get_file_as_string('res://globals/api/auth_pages/generic-error.html')
			
			connection.put_data(response.to_utf8_buffer())
			connection.disconnect_from_host()
	
	if !server.is_listening() and running:
		_stop_server(false)

func begin_authentication(callback: Callable = func(): return null) -> void:
	if(running):
		return
	
	var err = server.listen(port)
	if(err == OK):
		print('Auth Server open.')
		
		running = true
		state = Crypto.new().generate_random_bytes(32).hex_encode()
		on_complete = callback
		OS.shell_open(login_url % [state])
		_start_timers()
	else:
		print('Auth Server couldn\'t be open. Status: %d' % err)

func _expired() -> void:
	expired = true
	print('Auth Server time expired.')

func _stop_server(success: bool) -> void:
	running = false
	server.stop()
	state = ""
	on_complete = func(): return null
	if(server_timer):
		server_timer.queue_free()
	
	server_stopped.emit(success)
	print('Auth Server stopped.')

func _start_timers() -> void:
	# timer de expiração
	if(expire_timer):
		expire_timer.queue_free()
	expire_timer = Timer.new()
	expire_timer.wait_time = expire_seconds
	expire_timer.one_shot = true
	expire_timer.timeout.connect(_expired)
	add_child(expire_timer)
	
	# timer do servidor
	if(server_timer):
		server_timer.queue_free()
	server_timer = Timer.new()
	server_timer.wait_time = server_ttl
	server_timer.one_shot = true
	server_timer.timeout.connect(_stop_server.bind(false))
	add_child(server_timer)
	
	# iniciando ambos juntos
	expire_timer.start()
	server_timer.start()

func _exchange_credentials(code: String) -> bool:
	var response = await ApiClient.request(
		HTTPClient.METHOD_POST,
		Config.GOOGLE_EXCHANGE_PATH,
		JSON.stringify({
			'code': code
		})
	)
	
	if(!response.ok):
		return false
	
	# salvando credenciais
	_write_credentials(response.data.accessToken, response.data.refreshToken)
	return true

func _write_credentials(access_token: String, refresh_token: String) -> void:
	State.access_token = access_token
	
	var file = FileAccess.open_encrypted_with_pass('user://auth.dat', FileAccess.WRITE, Config.APP_KEY)
	file.store_string(JSON.stringify({ "refresh_token": refresh_token }))
	file.close()
