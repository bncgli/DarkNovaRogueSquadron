class_name FluxEconomyManagerSingleton
extends Node

## Manager per l'Economia Freemium-punk a FLUX, Rating Creditizio, Canoni e Snapshot S-Net
## per Dark Nova: Rogue Squadron.
## Gestisce il credit score dinamico FLUX (da 0 a 1000), sconti portuali, canoni ricorrenti,
## disattivazione remota OS per insolvenza, rischio sequestro (impound) e violazione ICE S-Net.

signal flux_score_changed(new_score: float, rating_letter: String, delta: float, reason: String)
signal credits_changed(new_credits: int, delta: int)
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

# Punteggio di credito FLUX (0.0 - 1000.0)
@export var flux_score: float = 720.0 # Rating B iniziale (Buono)
@export var credits: int = 5000

# Parametri debito & sequestro (Impound)
@export var total_debt: float = 0.0
@export var impound_time_limit_sec: float = 120.0
var impound_countdown: float = 120.0
var is_impound_warning_active: bool = false
var is_corvette_impounded: bool = false

# Funzionalità OS disabilitate da remoto per insolvenza
var disabled_os_features: Array[String] = []

# Tutte le possibili feature OS sacrificabili per insolvenza
const INSOLVENCY_FEATURES: Array[String] = [
	"Autopilot & Cruise Assist",
	"Weapons Subsystem Overclock",
	"Deep-Space Sensor Relay",
	"Subspace Comms Decryption",
	"Market Insider Feeds"
]

# Canoni di abbonamento e microtransazioni ricorrenti
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

# Storico transazioni
var transaction_history: Array[Dictionary] = []

func _ready() -> void:
	_update_rating_state()

func _process(delta: float) -> void:
	process_subscriptions(delta)
	_process_impound_risk(delta)

## Processa il ciclo di vita dei canoni di abbonamento
func process_subscriptions(delta: float) -> void:
	for sub in subscriptions:
		sub["time_left"] = float(sub.get("time_left")) - delta
		if float(sub.get("time_left")) <= 0.0:
			var cost: int = int(sub.get("cost"))
			var auto: bool = bool(sub.get("auto_pay"))
			var sub_id: String = str(sub.get("id"))
			
			if auto and credits >= cost:
				# Pagamento automatico puntuale
				credits -= cost
				sub["time_left"] = float(sub.get("period_sec"))
				sub["is_overdue"] = false
				credits_changed.emit(credits, -cost)
				subscription_paid.emit(sub_id, cost)
				add_transaction(cost, false, true, "Pagamento automatico canone: " + str(sub.get("name")))
				adjust_flux_score(6.0, "Puntualità canone " + sub_id)
			else:
				# Mancato pagamento -> Debito e rating giù
				if not bool(sub.get("is_overdue")):
					sub["is_overdue"] = true
					total_debt += float(cost)
					subscription_overdue.emit(sub_id, cost)
					adjust_flux_score(-45.0, "Mancato pagamento canone: " + sub_id)
					emit_penalty("OVERDUE_SUBSCRIPTION", {
						"sub_id": sub_id,
						"debt": cost,
						"message": "Canone scaduto! Sanzione applicata al rating FLUX."
					})
				sub["time_left"] = float(sub.get("period_sec"))

## Gestione del rischio di sequestro (Impound) della Corvetta
func _process_impound_risk(delta: float) -> void:
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

## Restituisce il rating alfabetico (S, A, B, C, D, F)
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

## Verifica se lo stato è insolvente / default finanziario (Rating F)
func is_insolvent() -> bool:
	return flux_score < 300.0 or get_rating_letter() == "F"

## Moltiplicatore di prezzo per sconti/sovraccosti portuali
func get_port_discount_multiplier() -> float:
	match get_rating_letter():
		"S": return 0.80 # -20% Sconto Prestigioso
		"A": return 0.90 # -10% Sconto Ottimo
		"B": return 1.00 # Tariffa Standard
		"C": return 1.00 # Tariffa Standard
		"D": return 1.15 # +15% Sovraccosto Rischio
		"F": return 1.35 # +35% Sovraccosto Insolvente
		_: return 1.00

## Calcola il prezzo effettivo di mercato tenendo conto del rating FLUX
func calculate_market_price(base_price: float, is_player_buying: bool) -> float:
	var mult := get_port_discount_multiplier()
	if is_player_buying:
		# Quando compri, sconti abbassano il costo, malus lo alzano
		return base_price * mult
	else:
		# Quando vendi, rating alto garantisce premium +15% o +10%
		var sell_mult := 1.20 if get_rating_letter() == "S" else (1.10 if get_rating_letter() == "A" else 1.0)
		return base_price * sell_mult

## Modifica dinamica del punteggio FLUX
func adjust_flux_score(delta: float, reason: String = "") -> void:
	var prev_score := flux_score
	flux_score = clampf(flux_score + delta, 0.0, 1000.0)
	var new_rating := get_rating_letter()
	
	flux_score_changed.emit(flux_score, new_rating, delta, reason)
	_update_rating_state()

## Registra una transazione nel sistema
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
	
	# Calcolo dinamico del punteggio basato su volume e puntualità
	var volume_bonus := clampf(amount / 500.0, 1.0, 15.0)
	if is_punctual:
		adjust_flux_score(volume_bonus, "Volume e puntualità transazione: " + desc)
	else:
		adjust_flux_score(-15.0, "Transazione irregolare o in ritardo: " + desc)

## Emette un evento di penalità
func emit_penalty(penalty_type: String, penalty_data: Dictionary) -> void:
	penalty_issued.emit(penalty_type, penalty_data)

## Aggiorna lo stato delle funzionalità in base al rating FLUX
func _update_rating_state() -> void:
	if is_insolvent():
		# Disattiva feature OS da remoto se non già disattivate
		for feat in INSOLVENCY_FEATURES:
			if not disabled_os_features.has(feat):
				disabled_os_features.append(feat)
				os_feature_disabled.emit(feat)
				emit_penalty("REMOTE_FEATURE_LOCKOUT", {
					"feature": feat,
					"message": "Funzionalità '%s' sospesa da remoto per rating creditizio insolvente (FLUX F)." % feat
				})
	else:
		# Ripristina feature
		if not disabled_os_features.is_empty():
			for feat in disabled_os_features:
				os_feature_restored.emit(feat)
			disabled_os_features.clear()

## Salda un abbonamento o debito specifico
func pay_subscription_manually(sub_id: String) -> bool:
	for sub in subscriptions:
		if sub.get("id") == sub_id:
			var cost: int = int(sub.get("cost"))
			if credits >= cost:
				credits -= cost
				if bool(sub.get("is_overdue")):
					total_debt = maxf(0.0, total_debt - float(cost))
				sub["is_overdue"] = false
				sub["time_left"] = float(sub.get("period_sec"))
				credits_changed.emit(credits, -cost)
				subscription_paid.emit(sub_id, cost)
				adjust_flux_score(25.0, "Saldo debito/canone manuale: " + sub_id)
				return true
	return false

## Salda tutti i debiti accumulati
func pay_all_debts() -> bool:
	var req_credits := int(total_debt)
	if req_credits <= 0:
		return true
	
	if credits >= req_credits:
		credits -= req_credits
		total_debt = 0.0
		for sub in subscriptions:
			sub["is_overdue"] = false
		credits_changed.emit(credits, -req_credits)
		adjust_flux_score(50.0, "Estinzione totale debiti accumulati")
		if is_impound_warning_active:
			is_impound_warning_active = false
			impound_warning_cleared.emit()
		return true
	return false

# ==============================================================================
# S-NET SNAPSHOT & MECCANICA HACKER ICE BREACH
# ==============================================================================

## Viola le barriere ICE di un disco Snapshot S-Net
func hack_snet_disk(disk_item: Dictionary, hacker_skill: float = 1.0) -> Dictionary:
	var metadata: Dictionary = disk_item.get("metadata")
	var is_snet: bool = bool(disk_item.get("is_snet_disk")) or str(disk_item.get("category")) == "SNET_DISK"
	
	if not is_snet:
		snet_ice_hack_failed.emit(disk_item, "L'oggetto specificato non è un supporto dati S-Net crittografato.")
		return { "success": false, "reason": "Not an S-Net disk" }
	
	if bool(metadata.get("ice_broken")):
		# Già violato in precedenza
		return {
			"success": true,
			"already_decrypted": true,
			"financial_snapshot": metadata.get("financial_snapshot"),
			"market_intel": metadata.get("market_intel")
		}
	
	var ice_strength: int = int(metadata.get("ice_strength"))
	var hack_chance := clampf(0.5 + (hacker_skill * 0.3) - (float(ice_strength) * 0.1), 0.1, 0.95)
	
	# Verifica riuscita hack
	var roll := randf()
	if roll <= hack_chance or hacker_skill >= 3.0:
		# Successo: sblocca dati finanziari segreti e crediti
		metadata["ice_broken"] = true
		metadata["ice_strength"] = 0
		disk_item["metadata"] = metadata
		
		var reward_credits: int = int(metadata.get("financial_snapshot"))
		credits += reward_credits
		credits_changed.emit(credits, reward_credits)
		
		var intel_data: Dictionary = {
			"success": true,
			"disk_id": disk_item.get("id"),
			"decrypted_credits": reward_credits,
			"market_intel": metadata.get("market_intel"),
			"sector": metadata.get("sector"),
			"access_codes": ["ICE-OVERRIDE-ALPHA", "FLUX-BYPASS-09"]
		}
		
		# Bonus al rating FLUX per iniezione di capitali e liquidità
		adjust_flux_score(35.0, "Intercettazione e iniezione snapshot finanziario S-Net")
		snet_ice_breached.emit(disk_item, intel_data)
		return intel_data
	else:
		# Fallimento: allarme ICE e tracciamento
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
