extends RefCounted
## Local game resources; no network access at runtime.
const TRACKS := [
	{
		"id": "passage",
		"title": "Passage of Time",
		"author": "Scott Buckley",
		"source": "https://www.scottbuckley.com.au/library/passage-of-time/",
	},
	{
		"id": "stone",
		"title": "Memories Of Stone",
		"author": "Scott Buckley",
		"source": "https://www.scottbuckley.com.au/library/memories-of-stone/",
	},
	{
		"id": "dawn",
		"title": "Nomadic Dawn",
		"author": "Alexander Nakarada",
		"source": "https://creatorchords.com/music/nomadic-dawn/",
	},
	{
		"id": "manes",
		"title": "Temple of the Manes",
		"author": "Kevin MacLeod",
		"source": "https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100053",
	},
	{
		"id": "hiraeth",
		"title": "Hiraeth",
		"author": "Scott Buckley",
		"source": "https://www.scottbuckley.com.au/library/hiraeth/",
	},
	{
		"id": "winter",
		"title": "Winter Night",
		"author": "Alexander Nakarada",
		"source": "https://creatorchords.com/music/winter-night/",
	},
	{
		"id": "titan",
		"title": "Titan",
		"author": "Scott Buckley",
		"source": "https://www.scottbuckley.com.au/library/titan/",
	},
	{
		"id": "summoning",
		"title": "The Summoning",
		"author": "Scott Buckley",
		"source": "https://www.scottbuckley.com.au/library/the-summoning/",
	},
]


static func resource_path(index: int) -> String:
	return "res://assets/audio/title/%s.ogg" % TRACKS[index].id
