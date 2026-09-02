extends Node
class_name GlobalValuesSingleton

## Global values that are useful for many classes to see.
## There isn't much here but I still wanted this to be separate from DefaultValues

enum AlarmLevel {
	NORMAL,
	YELLOW_ALERT,
	RED_ALERT
}

enum Quadrant {
	FORE,
	AFT,
	PORT,
	STARBOARD
}

enum ShipClass {
	CORVETTE,
	FRIGATE,
	DESTROYER,
	CRUISER,
	FREIGHTER,
	SCIENCE_VESSEL,
	SCOUT,
	CARRIER,
	STATION
}

enum DeviceCategory {
	COMMAND,
	PROPULSION,
	LIFE_SUPPORT,
	ENGINEERING,
	TACTICAL,
	SENSORS,
	COMMS,
	MAINFRAME,
	DEFENSE,
	CARGO,
	SERVICE,
	UTILITY
}

enum FileType {
	FOLDER,
	TEXT_FILE,
	IMAGE
}

const SHIP_CLASSES = ["Corvette", "Frigate", "Destroyer", "Cruiser", "Freighter", "Science Vessel", "Scout", "Carrier", "Station"]
const DEVICE_CATEGORIES = ["command", "propulsion", "life_support", "engineering", "tactical", "sensors", "comms", "mainframe", "defense", "cargo", "service", "utility"]

## The current selected window
static var selected_window: Node
