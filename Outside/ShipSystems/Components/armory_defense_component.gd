class_name ArmoryDefenseComponent
extends ShipPhysicalComponent

## Modello del sistema di alimentazione armeria e torrette (armory_defense).
## Alimenta i condensatori laser, i solenoidi cinetici, i servomotori di puntamento e il vano missili.
## Se disalimentato o offline, laser scarico, torretta bloccata e sparo inibito.

signal laser_charge_updated(current: float, max_charge: float)
signal weapon_discharged(weapon_type: String, heat_generated: float)
signal emergency_venting_triggered()

@export var laser_capacitor_max: float = 250.0
@export var laser_capacitor_current: float = 250.0
@export var laser_charge_rate: float = 50.0 # MW/s
@export var turret_azimuth: float = 0.0
@export var turret_elevation: float = 0.0
@export var heavy_mg_ammo: int = 500
@export var heavy_cannon_ammo: int = 12
@export var torpedo_ammo: int = 4
@export var probes_count: int = 2
@export var venting_cooldown: float = 0.0

var _is_charging_laser: bool = true

func _init(p_device_id: String = "armory_defense", p_room_id: String = "armamenti", p_category: String = "tactical") -> void:
	super._init(p_device_id, p_room_id, p_category)
	power_draw_nominal = 30.0

func initialize_registers() -> void:
	super.initialize_registers()
	registers["laser_charge"] = laser_capacitor_current
	registers["laser_max"] = laser_capacitor_max
	registers["turret_azimuth"] = turret_azimuth
	registers["turret_elevation"] = turret_elevation
	registers["heavy_mg_ammo"] = heavy_mg_ammo
	registers["heavy_cannon_ammo"] = heavy_cannon_ammo
	registers["torpedo_ammo"] = torpedo_ammo
	registers["probes_count"] = probes_count
	registers["can_fire"] = can_fire_weapons()
	registers["venting_ready"] = (venting_cooldown <= 0.0)
	
	if not readonly_registers.has("laser_charge"):
		readonly_registers.append("laser_charge")
	if not readonly_registers.has("laser_max"):
		readonly_registers.append("laser_max")
	if not readonly_registers.has("can_fire"):
		readonly_registers.append("can_fire")
	if not readonly_registers.has("venting_ready"):
		readonly_registers.append("venting_ready")

func read_register(reg_name: String) -> Variant:
	match reg_name:
		"laser_charge":
			return laser_capacitor_current
		"laser_max":
			return laser_capacitor_max
		"turret_azimuth":
			return turret_azimuth
		"turret_elevation":
			return turret_elevation
		"heavy_mg_ammo":
			return heavy_mg_ammo
		"heavy_cannon_ammo":
			return heavy_cannon_ammo
		"torpedo_ammo":
			return torpedo_ammo
		"probes_count":
			return probes_count
		"can_fire":
			return can_fire_weapons()
		"venting_ready":
			return venting_cooldown <= 0.0 and is_online and power_ratio >= 0.5
		_:
			return super.read_register(reg_name)

func _on_register_written(reg_name: String, value: Variant) -> void:
	super._on_register_written(reg_name, value)
	match reg_name:
		"turret_azimuth":
			turret_azimuth = fposmod(float(value), 360.0)
			registers["turret_azimuth"] = turret_azimuth
		"turret_elevation":
			turret_elevation = clampf(float(value), -20.0, 90.0)
			registers["turret_elevation"] = turret_elevation
		"heavy_mg_ammo":
			heavy_mg_ammo = maxi(0, int(value))
			registers["heavy_mg_ammo"] = heavy_mg_ammo
		"heavy_cannon_ammo":
			heavy_cannon_ammo = maxi(0, int(value))
			registers["heavy_cannon_ammo"] = heavy_cannon_ammo
		"torpedo_ammo":
			torpedo_ammo = maxi(0, int(value))
			registers["torpedo_ammo"] = torpedo_ammo
		"probes_count":
			probes_count = maxi(0, int(value))
			registers["probes_count"] = probes_count

func can_fire_weapons() -> bool:
	return is_online and power_ratio >= 0.4 and (health_percent > 10.0)

func fire_weapon(weapon_type: String) -> bool:
	if not can_fire_weapons():
		return false
	
	match weapon_type:
		"laser":
			if laser_capacitor_current < 50.0:
				return false
			laser_capacitor_current -= 50.0
			heat_current += 15.0
			weapon_discharged.emit("laser", 15.0)
			return true
		"heavy_mg":
			if heavy_mg_ammo <= 0:
				return false
			heavy_mg_ammo -= 1
			heat_current += 1.0
			registers["heavy_mg_ammo"] = heavy_mg_ammo
			weapon_discharged.emit("heavy_mg", 1.0)
			return true
		"heavy_cannon":
			if heavy_cannon_ammo <= 0:
				return false
			heavy_cannon_ammo -= 1
			heat_current += 8.0
			registers["heavy_cannon_ammo"] = heavy_cannon_ammo
			weapon_discharged.emit("heavy_cannon", 8.0)
			return true
		"torpedo":
			if torpedo_ammo <= 0:
				return false
			torpedo_ammo -= 1
			heat_current += 5.0
			registers["torpedo_ammo"] = torpedo_ammo
			weapon_discharged.emit("torpedo", 5.0)
			return true
		"probe":
			if probes_count <= 0:
				return false
			probes_count -= 1
			registers["probes_count"] = probes_count
			weapon_discharged.emit("probe", 0.0)
			return true
	return false

func trigger_emergency_venting() -> bool:
	if not is_online or power_ratio < 0.5 or venting_cooldown > 0.0:
		return false
	heat_current = maxf(ambient_temp, heat_current - 80.0)
	venting_cooldown = 15.0
	emergency_venting_triggered.emit()
	return true

func step(delta: float) -> void:
	if not is_online:
		power_draw_current = 0.0
		# Condensatori decadono se offline
		laser_capacitor_current = maxf(0.0, laser_capacitor_current - 10.0 * delta)
		_sync_armory_registers()
		super.step(delta)
		return

	# Potenza richiesta: 30 MW base + assorbimento ricarica condensatori se non al max
	var needs_charge := laser_capacitor_current < laser_capacitor_max
	var draw := power_draw_nominal + (70.0 if needs_charge else 0.0)
	power_draw_current = draw
	
	if power_draw_current > 0.0:
		power_ratio = clampf(power_supplied / power_draw_current, 0.0, 1.0)
	else:
		power_ratio = 1.0

	var health_factor := health_percent / 100.0
	
	if needs_charge and power_ratio > 0.2:
		var charge_gain := laser_charge_rate * power_ratio * health_factor * delta
		laser_capacitor_current = minf(laser_capacitor_max, laser_capacitor_current + charge_gain)
		laser_charge_updated.emit(laser_capacitor_current, laser_capacitor_max)

	if venting_cooldown > 0.0:
		venting_cooldown = maxf(0.0, venting_cooldown - delta)

	_sync_armory_registers()
	super.step(delta)

func _sync_armory_registers() -> void:
	registers["laser_charge"] = laser_capacitor_current
	registers["laser_max"] = laser_capacitor_max
	registers["turret_azimuth"] = turret_azimuth
	registers["turret_elevation"] = turret_elevation
	registers["heavy_mg_ammo"] = heavy_mg_ammo
	registers["heavy_cannon_ammo"] = heavy_cannon_ammo
	registers["torpedo_ammo"] = torpedo_ammo
	registers["probes_count"] = probes_count
	registers["can_fire"] = can_fire_weapons()
	registers["venting_ready"] = (venting_cooldown <= 0.0)

func get_telemetry() -> Dictionary:
	var telem := super.get_telemetry()
	telem["laser_charge"] = laser_capacitor_current
	telem["laser_max"] = laser_capacitor_max
	telem["turret_azimuth"] = turret_azimuth
	telem["turret_elevation"] = turret_elevation
	telem["heavy_mg_ammo"] = heavy_mg_ammo
	telem["heavy_cannon_ammo"] = heavy_cannon_ammo
	telem["torpedo_ammo"] = torpedo_ammo
	telem["probes_count"] = probes_count
	telem["can_fire"] = can_fire_weapons()
	telem["venting_ready"] = (venting_cooldown <= 0.0)
	return telem
