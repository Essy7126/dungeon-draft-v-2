class_name RunNodeData
extends Resource

enum NodeType { COMBAT, ELITE, TREASURE, REST, MERCHANT, EVENT, BOSS }

@export var node_name: String = "Noeud"
@export var node_type: NodeType = NodeType.COMBAT
@export_multiline var description: String = ""
@export var room: RoomData = null
@export var event_data: Resource = null
@export var guaranteed_reward: Resource = null
@export var icon_color: Color = Color(1, 1, 1, 1)
@export var risk_level: int = 1
@export var connects_to: Array[String] = []