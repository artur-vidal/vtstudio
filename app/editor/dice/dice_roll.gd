extends RefCounted
## Pure dice rules. Visual animation never changes an already sampled result.

const SIDES := [4, 6, 8, 10, 12, 20]
const MAX_PER_GROUP := 50
const MAX_DICE := 100


static func validate(groups: Array) -> String:
	var count_total := 0
	for entry in groups:
		if not entry is Dictionary:
			return "Conjunto de dados inválido."
		if not entry.has_all(["sides", "count", "mode"]):
			return "Informe tipo, quantidade e modo de cada conjunto."
		if not entry.sides is int or not entry.sides in SIDES:
			return "Escolha d4, d6, d8, d10, d12 ou d20."
		if not entry.count is int or entry.count < 0 or entry.count > MAX_PER_GROUP:
			return "Cada conjunto deve ter de 0 a %d dados." % MAX_PER_GROUP
		if not entry.mode is String or not entry.mode in ["sum", "highest"]:
			return "Escolha o modo Soma ou Maior."
		count_total += entry.count
		if count_total > MAX_DICE:
			return "Role no máximo %d dados de uma vez." % MAX_DICE
	if count_total == 0:
		return "Adicione pelo menos um dado para rolar."
	return ""


static func roll(groups: Array, rng: RandomNumberGenerator) -> Dictionary:
	var error := validate(groups)
	if not error.is_empty():
		return _failure(error)
	if rng == null:
		return _failure("Gerador aleatório indisponível.")
	var samples: Array = []
	for group in groups:
		var values: Array[int] = []
		for index in group.count:
			values.append(rng.randi_range(1, group.sides))
		samples.append(values)
	return evaluate(groups, samples)


## Samples align with INPUT groups, including an empty array for zero counts.
## The returned groups contain only active groups and never alias caller arrays.
static func evaluate(groups: Array, values_by_group: Array) -> Dictionary:
	var error := validate(groups)
	if not error.is_empty():
		return _failure(error)
	if values_by_group.size() != groups.size():
		return _failure("Resultados incompatíveis com os conjuntos.")
	var results: Array = []
	var total := 0
	var special := false
	for index in groups.size():
		var group: Dictionary = groups[index]
		var values = values_by_group[index]
		if not values is Array or values.size() != group.count:
			return _failure("Quantidade de resultados incompatível com o conjunto.")
		var subtotal := 0
		for value in values:
			if not value is int or value < 1 or value > group.sides:
				return _failure("Resultado fora das faces do dado.")
			if group.mode == "sum":
				subtotal += value
			else:
				subtotal = maxi(subtotal, value)
		if group.count == 0:
			continue
		# Integer arithmetic keeps the strict >80% boundary exact.
		var exceptional: bool = subtotal * 5 > group.count * group.sides * 4 if group.mode == "sum" else subtotal == group.sides
		results.append({"sides": group.sides, "count": group.count,
			"mode": group.mode, "values": values.duplicate(),
			"total": subtotal, "special": exceptional})
		total += subtotal
		special = special or exceptional
	return {"error": "", "groups": results, "total": total, "special": special}


static func _failure(message: String) -> Dictionary:
	return {"error": message, "groups": [], "total": 0, "special": false}
