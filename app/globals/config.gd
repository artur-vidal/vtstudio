extends Node

const APP_KEY: String = "chavesecreta"

const API_HOST: String = "http://localhost"
const API_PORT: int = 8500
const API_DIR: String = ""

const GOOGLE_AUTH_SERVER_PORT: int = 11060
const GOOGLE_LOGIN_PATH: String = "/auth/google/redirect"
const GOOGLE_EXCHANGE_PATH: String = "/auth/google/exchange"

func get_api_url() -> String:
	return API_HOST + ':' + str(API_PORT) + API_DIR
