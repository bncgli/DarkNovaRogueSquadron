class_name FluxEconomyManagerSingleton
extends Node

## Manager per l'Economia Freemium-punk a FLUX, Baratto Titoli di Debito/Credito e Rating Creditizio
## per Dark Nova: Rogue Squadron.
## Gestisce la liquidità di conio FLUX, il portafoglio titoli (debito passivo e credito attivo),
## le transazioni a baratto rateale, il credit score dinamico (0-1000), sconti/sovraccosti portuali,
## canoni ricorrenti, disattivazione remota OS per insolvenza, rischio sequestro e hack S-Net.

# --- SEGNALI ECONOMICI FLUX & BARATTO ---
signal flux_balance_changed(net_flux: int, liquid_flux: int, total_debt: int)
signal debt_tranche_added(modifier: ShipFluxModifier)
signal debt_tranche_settled(owner: String, amount: int)
signal barter_transaction_completed(summary: Dictionary)
signal flux_score_changed(new_score: float, rating_letter: String, delta: float, reason: String)

# --- SEGNALI CANONI & SANZIONI ---
signal subscription_paid(sub_id: String, amount: int)
signal subscription_overdue(sub_id: String, amount: int)
signal penalty_issued(penalty_type: String, penalty_data: Dictionary)
signal os_feature_disabled(feature_name: String)
signal os_feature_restored(feature_name: String)
signal impound_warning_issued(timer_sec: float, debt_amount: float)
signal impound_warning_cleared()
signal impound_executed()
signal snet_ice_breached(disk_item: Dictionary, intel_data: Dictionary)
signal snet_ice_hack_failed(disk_item: Dictionary, reason: String)

# --- SEGNALE LEGACY COMPATIBILITA ---
signal credits_changed(new_credits: int, delta: int)

# --- STATO CREDITIZIO E RATING ---
@export var flux_score: float = 720.0 # Rating B iniziale (Buono)

# --- PARAMETRI DEBITO & IMPOUND ---
@export var total_debt: float = 0.0
@export var impound_time_limit_sec: float = 120.0
var impound_countdown: float = 120.0
var is_impound_warning_active: bool = false
var is_corvette_impounded: bool = false

# --- BLUEPRINT ATTIVO & FALLBACK INTERNO ---
var active_blueprint: ShipBlueprint = null
var _internal_flux: int = 5000
var _internal_modifiers: Array = []

# --- FUNZIONALITA OS DISABILITATE PER INSOLVENZA ---
var disabled_os_features: Array[String] = []

const INSOLVENCY_FEATURES: Array[String] = [
	"Autopilot & Cruise Assist",
	"Weapons Subsystem Overclock",
	"Deep-Space Sensor Relay",
	"Subspace Comms Decryption",
	"Market Insider Feeds"
]

# --- CANONI DI ABBONAMENTO ---
var subscriptions: Array[Dictionary] = [
	{
		"id": "snet_bandwidth_relay",
		"name": "Canone Banda S-Net Subspazio",
		"cost": 250,
		"period_sec": 60.0,
		"time_left": 60.0,
		"is_overdue": false,
		"auto_pay": true
	},
	{
		"id": "port_license_aegis",
		"name": "Licenza di Attracco e Transito Portuale",
		"cost": 180,
		"period_sec": 90.0,
		"time_left": 90.0,
		"is_overdue": false,
		"auto_pay": true
	},
	{
		"id": "corvette_insurance",
		"name": "Polizza Assicurativa Rogue Hull Protection",
		"cost": 320,
		"period_sec": 120.0,
		"time_left": 120.0,
		"is_overdue": false,
		"auto_pay": true
	}
]

# --- STORICO TRANSAZIONI ---
var transaction_history: Array[Dictionary] = []

# ==============================================================================
# BRIDGE LEGACY PER COMPATIBILITA (PROPERTY CREDITS)
# ==============================================================================
var credits: int:
	get:
		return get_liquid_flux()
	set(val):
		var cur := get_liquid_flux()
		var diff := val - cur
		if diff > 0:
			add_liquid_flux(diff)
		elif diff < 0:
			spend_liquid_flux(-diff)

func _ready() -> void:
	add_to_group("flux_managers")
	_init_blueprint_link()
	_sync_accounting()
	_update_rating_state()

func _process(delta: float) -> void:
	process_subscriptions(delta)
	_process_impound_risk(delta)

# ==============================================================================
# SINCRONIZZAZIONE CON SHIPBLUEPRINT
# ==============================================================================

func _init_blueprint_link() -> void:
	var bp := _get_blueprint()
	if bp and not bp.blueprint_changed.is_connected(_on_blueprint_changed):
		bp.blueprint_changed.connect(_on_blueprint_changed)

func set_active_blueprint(bp: ShipBlueprint) -> void:
	if active_blueprint and active_blueprint.blueprint_changed.is_connected(_on_blueprint_changed):
		active_blueprint.blueprint_changed.disconnect(_on_blueprint_changed)
	active_blueprint = bp
	if active_blueprint:
		if not active_blueprint.blueprint_changed.is_connected(_on_blueprint_changed):
			active_blueprint.blueprint_changed.connect(_on_blueprint_changed)
	_sync_accounting()

func get_active_blueprint() -> ShipBlueprint:
	return _get_blueprint()

func _get_blueprint() -> ShipBlueprint:
	if active_blueprint != null:
		return active_blueprint
	if SpaceWorldManager:
		var ship: Spaceship = SpaceWorldManager.get_spaceship() if SpaceWorldManager.has_method("get_spaceship") else null
		if ship != null and "ship_blueprint" in ship and ship.ship_blueprint != null:
			return ship.ship_blueprint
		if "current_blueprint" in SpaceWorldManager and SpaceWorldManager.current_blueprint != null:
			return SpaceWorldManager.current_blueprint
	return null

func _get_modifiers() -> Array:
	var bp := _get_blueprint()
	if bp != null:
		return bp.flux_modifiers
	return _internal_modifiers

func _on_blueprint_changed() -> void:
	_sync_accounting()

# ==============================================================================
# CONTABILITA FLUX NETTO, LIQUIDO E TITOLI
# ==============================================================================

## Restituisce la liquidità di conio FLUX disponibile
func get_liquid_flux() -> int:
	var bp := _get_blueprint()
	if bp != null:
		return bp.flux
	return _internal_flux

## Restituisce la somma di tutti i debiti e passività (modificatori negativi) in FLUX
func get_total_debt() -> int:
	var sum_debt: int = 0
	var mods := _get_modifiers()
	for mod in mods:
		if mod is ShipFluxModifier and mod.value < 0:
			sum_debt += absi(mod.value)
		elif mod is Dictionary and int(mod.get("value", 0)) < 0:
			sum_debt += absi(int(mod.get("value", 0)))
	return sum_debt

## Restituisce la somma dei titoli di credito attivi (modificatori positivi)
func get_total_credit_titles() -> int:
	var sum_credit: int = 0
	var mods := _get_modifiers()
	for mod in mods:
		if mod is ShipFluxModifier and mod.value > 0:
			sum_credit += mod.value
		elif mod is Dictionary and int(mod.get("value", 0)) > 0:
			sum_credit += int(mod.get("value", 0))
	return sum_credit

## Calcola il saldo netto contabile: Net FLUX = Liquid + Sum(Modifiers)
func get_net_flux() -> int:
	var net: int = get_liquid_flux()
	var mods := _get_modifiers()
	for mod in mods:
		if mod is ShipFluxModifier:
			net += mod.value
		elif mod is Dictionary:
			net += int(mod.get("value", 0))
	return net

## Restituisce tutte le tranche di debito passivo
func get_debt_tranches() -> Array[ShipFluxModifier]:
	var result: Array[ShipFluxModifier] = []
	var mods := _get_modifiers()
	for mod in mods:
		if mod is ShipFluxModifier and mod.value < 0:
			result.append(mod)
	return result

## Restituisce tutti i titoli di credito commerciale attivi
func get_credit_titles() -> Array[ShipFluxModifier]:
	var result: Array[ShipFluxModifier] = []
	var mods := _get_modifiers()
	for mod in mods:
		if mod is ShipFluxModifier and mod.value > 0:
			result.append(mod)
	return result

## Tetto massimo di indebitamento concesso in base al rating creditizio
func get_max_allowed_debt() -> int:
	match get_rating_letter():
		"S": return 2500
		"A": return 1800
		"B": return 1200
		"C": return 800
		"D": return 0 # Nessuna nuova linea di credito
		"F": return 0 # Insolvente
		_: return 800

## Verifica se la nave può sostenere un costo (in liquidità pura o con accollo debito consentito)
func can_afford(cost: int, allow_debt: bool = false) -> bool:
	if cost <= 0:
		return true
	var liquid := get_liquid_flux()
	if liquid >= cost:
		return true
	if not allow_debt:
		return false
	if is_insolvent():
		return false
	var needed_debt := cost - liquid
	var max_debt := get_max_allowed_debt()
	var cur_debt := get_total_debt()
	return (cur_debt + needed_debt) <= max_debt

## Detrae conio FLUX liquido
func spend_liquid_flux(amount: int) -> bool:
	if amount <= 0:
		return true
	var liquid := get_liquid_flux()
	if liquid < amount:
		return false
	var bp := _get_blueprint()
	if bp != null:
		bp.flux -= amount
		bp.emit_changed()
	else:
		_internal_flux -= amount
	_sync_accounting(-amount)
	return true

## Incrementa conio FLUX liquido
func add_liquid_flux(amount: int) -> void:
	if amount <= 0:
		return
	var bp := _get_blueprint()
	if bp != null:
		bp.flux += amount
		bp.emit_changed()
	else:
		_internal_flux += amount
	_sync_accounting(amount)

# Legacy alias
func add_credits(amount: int, desc: String = "") -> void:
	add_liquid_flux(amount)
	if not desc.is_empty():
		add_transaction(float(amount), true, true, desc)

func spend_credits(amount: int) -> bool:
	return spend_liquid_flux(amount)

# ==============================================================================
# GESTIONE TRANCHE DI DEBITO E TITOLI DI CREDITO
# ==============================================================================

## Emette una nuova rata/tranche di debito passivo
func issue_debt_tranche(owner: String, reason: String, amount: int) -> ShipFluxModifier:
	var abs_amount: int = absi(amount)
	if abs_amount == 0:
		return null
	var mod := ShipFluxModifier.new(-abs_amount, owner, reason)
	var mods := _get_modifiers()
	mods.append(mod)
	var bp := _get_blueprint()
	if bp != null:
		bp.emit_changed()
	total_debt = float(get_total_debt())
	debt_tranche_added.emit(mod)
	adjust_flux_score(-float(abs_amount) * 0.04, "Emissione debito: " + owner)
	_sync_accounting()
	return mod

## Emette o acquisisce un nuovo titolo di credito commerciale attivo
func issue_credit_title(owner: String, reason: String, amount: int) -> ShipFluxModifier:
	var abs_amount: int = absi(amount)
	if abs_amount == 0:
		return null
	var mod := ShipFluxModifier.new(abs_amount, owner, reason)
	var mods := _get_modifiers()
	mods.append(mod)
	var bp := _get_blueprint()
	if bp != null:
		bp.emit_changed()
	adjust_flux_score(float(abs_amount) * 0.05, "Acquisizione titolo di credito: " + owner)
	_sync_accounting()
	return mod

## Rimborsa una tranche passiva usando FLUX liquido
func repay_debt(owner: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var mods := _get_modifiers()
	var target_debt: int = 0
	for m in mods:
		if m is ShipFluxModifier and m.value < 0:
			if owner.is_empty() or owner == "ALL" or m.owner == owner:
				target_debt += absi(m.value)
	if target_debt == 0:
		return 0

	var liquid := get_liquid_flux()
	var to_repay: int = mini(amount, mini(liquid, target_debt))
	if to_repay <= 0:
		return 0

	# Detrae da liquid FLUX
	spend_liquid_flux(to_repay)

	var remaining: int = to_repay
	var mods_to_remove: Array = []
	for m in mods:
		if m is ShipFluxModifier and m.value < 0:
			if owner.is_empty() or owner == "ALL" or m.owner == owner:
				var d_val: int = absi(m.value)
				if d_val <= remaining:
					remaining -= d_val
					m.value = 0
					mods_to_remove.append(m)
				else:
					m.value += remaining
					remaining = 0
					break

	for rm in mods_to_remove:
		mods.erase(rm)

	var bp := _get_blueprint()
	if bp != null:
		bp.emit_changed()

	total_debt = float(get_total_debt())
	debt_tranche_settled.emit(owner, to_repay)
	adjust_flux_score(float(to_repay) * 0.08, "Rimborso debito: " + owner)
	_sync_accounting()
	return to_repay

## Alias diegetico per il rimborso di una tranche di debito
func repay_debt_tranche(debt_owner: String, amount: int) -> int:
	return repay_debt(debt_owner, amount)

## Applica uno sgravio di debito diretto (da liquidazione merci o contratti) senza decurtare liquid FLUX
func apply_debt_relief(debt_owner: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var mods := _get_modifiers()
	var to_relieve: int = amount
	var relief_applied: int = 0
	var mods_to_remove: Array = []
	for m in mods:
		if m is ShipFluxModifier and m.value < 0:
			if debt_owner.is_empty() or debt_owner == "ALL" or m.owner == debt_owner:
				var d_val: int = absi(m.value)
				if d_val <= to_relieve:
					to_relieve -= d_val
					relief_applied += d_val
					m.value = 0
					mods_to_remove.append(m)
				else:
					m.value += to_relieve
					relief_applied += to_relieve
					to_relieve = 0
					break
	for rm in mods_to_remove:
		mods.erase(rm)

	var bp := _get_blueprint()
	if bp != null:
		bp.emit_changed()

	if relief_applied > 0:
		total_debt = float(get_total_debt())
		debt_tranche_settled.emit(debt_owner, relief_applied)
		adjust_flux_score(float(relief_applied) * 0.1, "Sgravio debito: " + debt_owner)
		_sync_accounting()
	return relief_applied

# ==============================================================================
# TRANSAZIONI E BARATTO
# ==============================================================================

## Esegue un pagamento FLUX con eventuale emissione di debito se autorizzato
func pay_with_flux(amount: int, allow_debt_issuance: bool = false, creditor: String = "Station Port Authority", reason: String = "Spesa di stazione") -> Dictionary:
	if amount <= 0:
		return {"success": true, "paid_liquid": 0, "debt_issued": 0, "status": "FREE"}

	var liquid := get_liquid_flux()
	if liquid >= amount:
		spend_liquid_flux(amount)
		add_transaction(float(amount), false, true, reason)
		return {"success": true, "paid_liquid": amount, "debt_issued": 0, "status": "PAID_IN_FULL"}
	elif allow_debt_issuance and can_afford(amount, true):
		var debt_needed := amount - liquid
		spend_liquid_flux(liquid)
		var mod := issue_debt_tranche(creditor, reason, debt_needed)
		add_transaction(float(amount), false, true, reason + " (Debito: %d FLUX)" % debt_needed)
		return {"success": true, "paid_liquid": liquid, "debt_issued": debt_needed, "modifier": mod, "status": "PAID_WITH_DEBT"}
	else:
		return {"success": false, "paid_liquid": 0, "debt_issued": 0, "reason": "Fondi insufficienti o rating non idoneo a nuovo debito"}

## Risolve uno scambio complesso a baratto: offerta liquida + cessione titoli + accollo debiti
func transact_barter(required_cost: int, offered_liquid: int, transferred_titles: Array, accepted_debts: Array) -> Dictionary:
	var avail_liquid := get_liquid_flux()
	var actual_liquid: int = mini(maxi(0, offered_liquid), avail_liquid)
	
	# Calcola valore titoli di credito ceduti
	var titles_value: int = 0
	for t in transferred_titles:
		if t is ShipFluxModifier and t.value > 0:
			titles_value += t.value
		elif t is Dictionary:
			titles_value += maxi(0, int(t.get("value", 0)))
			
	# Calcola valore debiti passivi accollati
	var debts_value: int = 0
	for d in accepted_debts:
		if d is Dictionary:
			debts_value += maxi(0, int(d.get("amount", 0)))
		elif d is ShipFluxModifier and d.value < 0:
			debts_value += absi(d.value)

	# Se si accollano nuovi debiti, verifica insolvenza
	if debts_value > 0 and is_insolvent():
		return {
			"success": false,
			"reason": "Rating insolvente (F): emissione di nuovo debito respinta",
			"required_cost": required_cost
		}

	var total_offered: int = actual_liquid + titles_value + debts_value
	if total_offered < required_cost:
		return {
			"success": false,
			"reason": "Valore di baratto insufficiente (%d su %d FLUX richiesti)" % [total_offered, required_cost],
			"required_cost": required_cost,
			"total_offered": total_offered
		}

	# Esecuzione transazione
	if actual_liquid > 0:
		spend_liquid_flux(actual_liquid)

	var mods := _get_modifiers()
	for t in transferred_titles:
		if t is ShipFluxModifier:
			mods.erase(t)
		elif t is String:
			for m in mods:
				if m is ShipFluxModifier and (m.owner == t or m.reason == t) and m.value > 0:
					mods.erase(m)
					break

	for d in accepted_debts:
		if d is Dictionary:
			var d_owner: String = str(d.get("owner", "Port Authority"))
			var d_reason: String = str(d.get("reason", "Transazione a baratto"))
			var d_amt: int = int(d.get("amount", 0))
			if d_amt > 0:
				issue_debt_tranche(d_owner, d_reason, d_amt)
		elif d is ShipFluxModifier and d.value < 0:
			issue_debt_tranche(d.owner, d.reason, absi(d.value))

	# Se c'è eccedenza, rimborso in FLUX liquido
	var excess: int = total_offered - required_cost
	if excess > 0:
		add_liquid_flux(excess)

	var bp := _get_blueprint()
	if bp != null:
		bp.emit_changed()

	_sync_accounting()

	var summary := {
		"success": true,
		"required_cost": required_cost,
		"paid_liquid": actual_liquid,
		"titles_value": titles_value,
		"debts_issued": debts_value,
		"excess_refunded": excess,
		"net_flux": get_net_flux()
	}
	barter_transaction_completed.emit(summary)
	return summary

## Helper comodo per baratto con calcolo automatico debito se richiesto
func barter_transaction(cost: int, offered_liquid: int, transferred_titles: Array, issue_debt_if_needed: bool = false, creditor: String = "Station Port Authority") -> Dictionary:
	var avail_liquid := get_liquid_flux()
	var act_liquid: int = mini(maxi(0, offered_liquid), avail_liquid)
	var titles_val: int = 0
	for t in transferred_titles:
		if t is ShipFluxModifier and t.value > 0:
			titles_val += t.value

	var shortfall: int = cost - (act_liquid + titles_val)
	if shortfall <= 0:
		return transact_barter(cost, act_liquid, transferred_titles, [])
	
	if issue_debt_if_needed:
		if is_insolvent():
			return {
				"success": false,
				"reason": "Insolvente: emissione nuovo debito non consentita"
			}
		var debts := [
			{
				"owner": creditor,
				"reason": "Baratto fornitura stazione",
				"amount": shortfall
			}
		]
		return transact_barter(cost, act_liquid, transferred_titles, debts)
	else:
		return {
			"success": false,
			"reason": "Fondi e titoli insufficienti per coprire il costo",
			"shortfall": shortfall
		}

## Riscossione di una ricompensa mista: FLUX liquido + sgravio di debiti attivi
func receive_flux_reward(liquid_amount: int, debt_relief_target: String = "", debt_relief_amount: int = 0) -> Dictionary:
	if liquid_amount > 0:
		add_liquid_flux(liquid_amount)
		add_transaction(float(liquid_amount), true, true, "Ricompensa missione FLUX")

	var relief_applied: int = 0
	if debt_relief_amount > 0:
		var mods := _get_modifiers()
		var to_relieve: int = debt_relief_amount
		var mods_to_remove: Array = []
		for m in mods:
			if m is ShipFluxModifier and m.value < 0:
				if debt_relief_target.is_empty() or debt_relief_target == "ALL" or m.owner == debt_relief_target:
					var d_val: int = absi(m.value)
					if d_val <= to_relieve:
						to_relieve -= d_val
						relief_applied += d_val
						m.value = 0
						mods_to_remove.append(m)
					else:
						m.value += to_relieve
						relief_applied += to_relieve
						to_relieve = 0
						break
		for rm in mods_to_remove:
			mods.erase(rm)

		var bp := _get_blueprint()
		if bp != null:
			bp.emit_changed()

		if relief_applied > 0:
			debt_tranche_settled.emit(debt_relief_target, relief_applied)
			adjust_flux_score(float(relief_applied) * 0.1, "Sgravio debito: " + debt_relief_target)

	_sync_accounting()
	return {
		"liquid_reward": liquid_amount,
		"debt_relief_applied": relief_applied,
		"net_flux": get_net_flux()
	}

## Riscossione contratto Fixer compatibile con il modello a ricompensa FLUX
func receive_contract_reward(contract: Dictionary) -> Dictionary:
	var liquid: int = int(contract.get("reward_liquid_flux", contract.get("reward_flux", contract.get("reward_credits", 0))))
	var relief_amt: int = int(contract.get("reward_debt_relief", 0))
	var target_creditor: String = str(contract.get("creditor_relief_target", ""))
	return receive_flux_reward(liquid, target_creditor, relief_amt)

# ==============================================================================
# CANONI, RATING CREDITIZIO E IMPOUND
# ==============================================================================

func process_subscriptions(delta: float) -> void:
	for sub in subscriptions:
		sub["time_left"] = float(sub.get("time_left")) - delta
		if float(sub.get("time_left")) <= 0.0:
			var cost: int = int(sub.get("cost"))
			var auto: bool = bool(sub.get("auto_pay"))
			var sub_id: String = str(sub.get("id"))
			
			if auto and get_liquid_flux() >= cost:
				spend_liquid_flux(cost)
				sub["time_left"] = float(sub.get("period_sec"))
				sub["is_overdue"] = false
				subscription_paid.emit(sub_id, cost)
				add_transaction(float(cost), false, true, "Pagamento automatico canone: " + str(sub.get("name")))
				adjust_flux_score(6.0, "Puntualità canone " + sub_id)
			else:
				if not bool(sub.get("is_overdue")):
					sub["is_overdue"] = true
					issue_debt_tranche("Aegis Port Authority", "Canone insoluto: " + str(sub.get("name")), cost)
					subscription_overdue.emit(sub_id, cost)
					adjust_flux_score(-45.0, "Mancato pagamento canone: " + sub_id)
					emit_penalty("OVERDUE_SUBSCRIPTION", {
						"sub_id": sub_id,
						"debt": cost,
						"message": "Canone scaduto! Emissione debito e sanzione rating FLUX."
					})
				sub["time_left"] = float(sub.get("period_sec"))

func _process_impound_risk(delta: float) -> void:
	total_debt = float(get_total_debt())
	if is_insolvent() or total_debt > 0.0:
		if not is_impound_warning_active:
			is_impound_warning_active = true
			impound_countdown = impound_time_limit_sec
			impound_warning_issued.emit(impound_countdown, total_debt)
		else:
			impound_countdown = maxf(0.0, impound_countdown - delta)
			if impound_countdown <= 0.0 and not is_corvette_impounded:
				is_corvette_impounded = true
				impound_executed.emit()
				emit_penalty("CORVETTE_IMPOUNDED", {
					"debt": total_debt,
					"reason": "Mancata estinzione del debito entro i termini. Sequestro forzato della nave."
				})
	else:
		if is_impound_warning_active:
			is_impound_warning_active = false
			impound_countdown = impound_time_limit_sec
			impound_warning_cleared.emit()

func get_rating_letter() -> String:
	if flux_score >= 900.0:
		return "S"
	elif flux_score >= 750.0:
		return "A"
	elif flux_score >= 600.0:
		return "B"
	elif flux_score >= 450.0:
		return "C"
	elif flux_score >= 300.0:
		return "D"
	else:
		return "F"

func is_insolvent() -> bool:
	return flux_score < 300.0 or get_rating_letter() == "F"

func get_port_discount_multiplier() -> float:
	match get_rating_letter():
		"S": return 0.80 # -20%
		"A": return 0.90 # -10%
		"B": return 1.00
		"C": return 1.00
		"D": return 1.15 # +15% Sovraccosto
		"F": return 1.35 # +35% Sovraccosto
		_: return 1.00

func calculate_market_price(base_price: float, is_player_buying: bool) -> float:
	var mult := get_port_discount_multiplier()
	if is_player_buying:
		return base_price * mult
	else:
		var sell_mult := 1.20 if get_rating_letter() == "S" else (1.10 if get_rating_letter() == "A" else 1.0)
		return base_price * sell_mult

func adjust_flux_score(delta: float, reason: String = "") -> void:
	flux_score = clampf(flux_score + delta, 0.0, 1000.0)
	var new_rating := get_rating_letter()
	flux_score_changed.emit(flux_score, new_rating, delta, reason)
	_update_rating_state()

func add_transaction(amount: float, is_income: bool, is_punctual: bool = true, desc: String = "") -> void:
	var entry := {
		"timestamp": Time.get_unix_time_from_system(),
		"amount": amount,
		"is_income": is_income,
		"is_punctual": is_punctual,
		"description": desc,
		"score_at_time": flux_score
	}
	transaction_history.append(entry)
	var volume_bonus := clampf(amount / 500.0, 1.0, 15.0)
	if is_punctual:
		adjust_flux_score(volume_bonus, "Volume e puntualità transazione: " + desc)
	else:
		adjust_flux_score(-15.0, "Transazione irregolare: " + desc)

func emit_penalty(penalty_type: String, penalty_data: Dictionary) -> void:
	penalty_issued.emit(penalty_type, penalty_data)

func _update_rating_state() -> void:
	if is_insolvent():
		for feat in INSOLVENCY_FEATURES:
			if not disabled_os_features.has(feat):
				disabled_os_features.append(feat)
				os_feature_disabled.emit(feat)
				emit_penalty("REMOTE_FEATURE_LOCKOUT", {
					"feature": feat,
					"message": "Funzionalità '%s' sospesa da remoto per insolvenza creditizia (FLUX F)." % feat
				})
	else:
		if not disabled_os_features.is_empty():
			for feat in disabled_os_features:
				os_feature_restored.emit(feat)
			disabled_os_features.clear()

func pay_subscription_manually(sub_id: String) -> bool:
	for sub in subscriptions:
		if sub.get("id") == sub_id:
			var cost: int = int(sub.get("cost"))
			if spend_liquid_flux(cost):
				sub["is_overdue"] = false
				sub["time_left"] = float(sub.get("period_sec"))
				subscription_paid.emit(sub_id, cost)
				adjust_flux_score(25.0, "Saldo manuale canone: " + sub_id)
				return true
	return false

func pay_all_debts() -> bool:
	var debt := get_total_debt()
	if debt <= 0:
		return true
	var paid := repay_debt("ALL", debt)
	if paid >= debt:
		if is_impound_warning_active:
			is_impound_warning_active = false
			impound_warning_cleared.emit()
		return true
	return false

func _sync_accounting(delta_liquid: int = 0) -> void:
	total_debt = float(get_total_debt())
	var net := get_net_flux()
	var liquid := get_liquid_flux()
	flux_balance_changed.emit(net, liquid, int(total_debt))
	credits_changed.emit(liquid, delta_liquid)

# ==============================================================================
# HACK SNAPSHOT S-NET
# ==============================================================================

func hack_snet_disk(disk_item: Dictionary, hacker_skill: float = 1.0) -> Dictionary:
	var metadata: Dictionary = disk_item.get("metadata", {})
	var is_snet: bool = bool(disk_item.get("is_snet_disk")) or str(disk_item.get("category")) == "SNET_DISK"
	
	if not is_snet:
		snet_ice_hack_failed.emit(disk_item, "L'oggetto specificato non è un supporto dati S-Net crittografato.")
		return { "success": false, "reason": "Not an S-Net disk" }
	
	if bool(metadata.get("ice_broken")):
		return {
			"success": true,
			"already_decrypted": true,
			"financial_snapshot": metadata.get("financial_snapshot"),
			"market_intel": metadata.get("market_intel")
		}
	
	var ice_strength: int = int(metadata.get("ice_strength", 1))
	var hack_chance := clampf(0.5 + (hacker_skill * 0.3) - (float(ice_strength) * 0.1), 0.1, 0.95)
	
	var roll := randf()
	if roll <= hack_chance or hacker_skill >= 3.0:
		metadata["ice_broken"] = true
		metadata["ice_strength"] = 0
		disk_item["metadata"] = metadata
		
		var reward_flux: int = int(metadata.get("financial_snapshot", 0))
		add_liquid_flux(reward_flux)
		
		var intel_data: Dictionary = {
			"success": true,
			"disk_id": disk_item.get("id"),
			"decrypted_credits": reward_flux,
			"decrypted_flux": reward_flux,
			"market_intel": metadata.get("market_intel"),
			"sector": metadata.get("sector"),
			"access_codes": ["ICE-OVERRIDE-ALPHA", "FLUX-BYPASS-09"]
		}
		
		adjust_flux_score(35.0, "Intercettazione e iniezione snapshot finanziario S-Net")
		snet_ice_breached.emit(disk_item, intel_data)
		return intel_data
	else:
		var fail_reason := "Contromisura ICE attiva: Barriera di crittografia квантовая impenetrabile. Traccia rilevata."
		adjust_flux_score(-15.0, "Tracciamento ICE fallito su snapshot S-Net")
		snet_ice_hack_failed.emit(disk_item, fail_reason)
		emit_penalty("ICE_HACK_DETECTED", {
			"disk_id": disk_item.get("id"),
			"reason": fail_reason
		})
		return {
			"success": false,
			"reason": fail_reason
		}
