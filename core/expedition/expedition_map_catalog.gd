class_name ExpeditionMapCatalog
extends RefCounted
## The Catabase map pool. First five resources are the unchanged historical rooms.
## Order is a catalogue index, never a mandatory route or difficulty level.

const ROOM_COUNT := 15
const ROOM_PATHS := [
	"res://data/rooms/odyssey/room_01.tres",
	"res://data/rooms/odyssey/room_02.tres",
	"res://data/rooms/odyssey/room_03.tres",
	"res://data/rooms/odyssey/room_04.tres",
	"res://data/rooms/odyssey/room_05.tres",
	"res://data/rooms/catabase_expansion/room_06_porteurs.tres",
	"res://data/rooms/catabase_expansion/room_07_citerne.tres",
	"res://data/rooms/catabase_expansion/room_08_braises.tres",
	"res://data/rooms/catabase_expansion/room_09_peristyle.tres",
	"res://data/rooms/catabase_expansion/room_10_digue.tres",
	"res://data/rooms/catabase_expansion/room_11_mesures.tres",
	"res://data/rooms/catabase_expansion/room_12_necropole.tres",
	"res://data/rooms/catabase_expansion/room_13_offrandes.tres",
	"res://data/rooms/catabase_expansion/room_14_escalier.tres",
	"res://data/rooms/catabase_expansion/room_15_moirai.tres",
]


static func get_room(index: int) -> RoomData:
	if index < 0 or index >= ROOM_COUNT:
		return null
	return load(ROOM_PATHS[index]) as RoomData


static func all_rooms() -> Array[RoomData]:
	var result: Array[RoomData] = []
	for index in ROOM_COUNT:
		result.append(get_room(index))
	return result
