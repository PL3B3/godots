extends Object

class_name Network

const PORT = 33425
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 20
const SERVER_UNIQUE_ID = 1

enum MessageType {
	PLAYER_STATE,
	PUPPET_STATE,
	RESIZE
}
