class_name NetboundCurrencyProductRegistry
extends RefCounted

const PRODUCTS := {
	"netbound_tokens_100": {"token_amount": 100, "development_price_text": "DEV $0.99", "sort_order": 10},
	"netbound_tokens_275": {"token_amount": 275, "development_price_text": "DEV $1.99", "sort_order": 20},
	"netbound_tokens_600": {"token_amount": 600, "development_price_text": "DEV $3.99", "sort_order": 30},
	"netbound_tokens_1300": {"token_amount": 1300, "development_price_text": "DEV $6.99", "sort_order": 40},
	"netbound_tokens_3000": {"token_amount": 3000, "development_price_text": "DEV $12.99", "sort_order": 50},
}


static func get_product_ids() -> Array[String]:
	var ids: Array[String] = []
	for product_id in PRODUCTS.keys():
		ids.append(String(product_id))
	ids.sort_custom(func(a: String, b: String) -> bool: return get_sort_order(a) < get_sort_order(b))
	return ids


static func is_token_product(product_id: String) -> bool:
	return PRODUCTS.has(product_id)


static func get_token_amount(product_id: String) -> int:
	return int((PRODUCTS.get(product_id, {}) as Dictionary).get("token_amount", 0))


static func get_development_price_text(product_id: String) -> String:
	return String((PRODUCTS.get(product_id, {}) as Dictionary).get("development_price_text", "DEV --"))


static func get_sort_order(product_id: String) -> int:
	return int((PRODUCTS.get(product_id, {}) as Dictionary).get("sort_order", 0))


static func validate_registry() -> Dictionary:
	var errors: Array[String] = []
	for product_id in PRODUCTS.keys():
		if String(product_id).is_empty() or get_token_amount(String(product_id)) <= 0:
			errors.append("invalid token product %s" % String(product_id))
		if not get_development_price_text(String(product_id)).begins_with("DEV "):
			errors.append("token product price must be development-only: %s" % String(product_id))
	return {"ok": errors.is_empty(), "errors": errors}
