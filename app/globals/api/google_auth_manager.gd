extends Node

signal server_stopped(success: bool)

var server := TCPServer.new()
var port := Config.GOOGLE_AUTH_SERVER_PORT
var running := false
var state: String = ""
var on_complete: Callable;

var timeout_timer: Timer
var redirect_url := Config.API_HOST + Config.API_DIR + Config.GOOGLE_LOGIN_PATH;
var login_url := redirect_url + "?client_redirect=http://127.0.0.1:" + str(port) + "/callback&state=%s"

func _process(_delta: float) -> void:
	if server.is_listening() and server.is_connection_available():
		var connection := server.take_connection()
		connection.poll()
		
		var available = connection.get_available_bytes()
		if available > 0:
			var raw: String = connection.get_utf8_string(available)
			if(raw.begins_with('GET /callback')):
				# parsing da resposta
				var url = raw.split(" ")[1]
				var query = url.split("?")[1]
				var params = query.split("&")
				var params_dict: Dictionary = {}
				
				for p in params:
					var splitted = p.split("=", true, 1)
					params_dict[splitted[0]] = splitted[1].uri_decode()
				
				# validação
				if params_dict.state == state:
					# pego o código e faço uma requisição pro aplicativo
					var code: String = params_dict['code']
					await _exchange_credentials(code)
					_stop_server(true)
				else:
					_stop_server(false)
				
			
			var response := "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
			response += "<html><body><h1>Você pode já pode fechar esta aba e voltar para o app.</h1></body></html>"
			connection.put_data(response.to_utf8_buffer())
			connection.disconnect_from_host()
	
	if !server.is_listening() and running:
		_stop_server(false)

func begin_authentication(callback: Callable = func(): return null) -> void:
	if(running):
		return
	
	running = true
	server.listen(port)
	state = Crypto.new().generate_random_bytes(32).hex_encode()
	on_complete = callback
	OS.shell_open(login_url % [state])

func _stop_server(success: bool) -> void:
	running = false
	server.stop()
	state = ""
	on_complete = func(): return null
	
	server_stopped.emit(success)

func _start_timer() -> void:
	timeout_timer = Timer.new()
	timeout_timer.wait_time = 120 # dois minutes
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_stop_server)
	add_child(timeout_timer)
	timeout_timer.start()

func _exchange_credentials(code: String):
	var response = await ApiClient.request(
		HTTPClient.METHOD_POST,
		Config.GOOGLE_EXCHANGE_PATH,
		JSON.stringify({
			'code': code
		})
	)
	
	# salvando credenciais
	_write_credentials(response.data.accessToken, response.data.refreshToken)

func _write_credentials(access_token: String, refresh_token: String) -> void:
	State.access_token = access_token
	
	var file = FileAccess.open_encrypted_with_pass('user://auth.dat', FileAccess.WRITE, Config.APP_KEY)
	file.store_string(JSON.stringify({ "refresh_token": refresh_token }))
	file.close()
