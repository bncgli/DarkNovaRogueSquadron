class_name BatteryComponent
extends ShipPhysicalComponent

## Modello di batteria/accumulatore elettrochimico di riserva.
## Assorbe l'energia in eccesso dalla rete ed eroga potenza nei picchi di consumo o blackout.

@export var capacity_max: float = 1000.0 # MJ o unita' energetiche
@export var charge_current: float = 1000.0
@export var charge_rate_max: float = 100.0 # MW max di assorbimento in ricarica
@export var discharge_rate_max: float = 200.0 # MW max di erogazione in scarica

func _init(p_device_id: String = "", p_room_id: String = "", p_category: String = "engineering") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 0.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["capacity_max"] = capacity_max
	registers["charge_current"] = charge_current
	registers["charge_percent"] = get_charge_percent()
	registers["charge_rate_max"] = charge_rate_max
	registers["discharge_rate_max"] = discharge_rate_max
	if not readonly_registers.has("capacity_max"):
		readonly_registers.append("capacity_max")
	if not readonly_registers.has("charge_current"):
		readonly_registers.append("charge_current")
	if not readonly_registers.has("charge_percent"):
		readonly_registers.append("charge_percent")

func get_charge_percent() -> float:
	if capacity_max <= 0.0:
		return 0.0
	return (charge_current / capacity_max) * 100.0

## Ricarica l'accumulatore con potenza erogata. Ritorna la potenza effettivamente assorbita (in MW).
func charge(available_power_mw: float, delta: float) -> float:
	if not is_online or available_power_mw <= 0.0 or delta <= 0.0:
		return 0.0
	
	var max_intake_mw := minf(available_power_mw, charge_rate_max)
	var max_intake_energy := max_intake_mw * delta
	var space_available := maxf(0.0, capacity_max - charge_current)
	
	var energy_charged := minf(max_intake_energy, space_available)
	charge_current += energy_charged
	var power_absorbed_mw := energy_charged / delta
	
	# Riscaldamento leggero dovuto all'efficienza di carica (5% di perdita come calore)
	heat_current += (power_absorbed_mw * 0.05) * 0.1 * delta
	return power_absorbed_mw

## Eroga potenza dalla batteria verso la rete. Ritorna la potenza effettivamente fornita (in MW).
func discharge(demanded_power_mw: float, delta: float) -> float:
	if not is_online or demanded_power_mw <= 0.0 or delta <= 0.0 or charge_current <= 0.0:
		return 0.0
	
	var max_output_mw := minf(demanded_power_mw, discharge_rate_max) * (health_percent / 100.0)
	var max_output_energy := max_output_mw * delta
	
	var energy_discharged := minf(max_output_energy, charge_current)
	charge_current -= energy_discharged
	var power_delivered_mw := energy_discharged / delta
	
	# Riscaldamento da scarica
	heat_current += (power_delivered_mw * 0.04) * 0.1 * delta
	return power_delivered_mw

func step(delta: float) -> void:
	registers["charge_current"] = charge_current
	registers["charge_percent"] = get_charge_percent()
	super.step(delta)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["capacity_max"] = capacity_max
	telem["charge_current"] = charge_current
	telem["charge_percent"] = get_charge_percent()
	return telem
