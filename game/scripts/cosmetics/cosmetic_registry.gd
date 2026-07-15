class_name CosmeticRegistry
extends RefCounted

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const CATEGORY_BALL := "ball"
const CATEGORY_TRAIL := "trail"
const CATEGORY_GOAL_EFFECT := "goal_effect"
const VALID_CATEGORIES := [CATEGORY_BALL, CATEGORY_TRAIL, CATEGORY_GOAL_EFFECT]

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"
const VALID_RARITIES := [RARITY_COMMON, RARITY_RARE, RARITY_EPIC, RARITY_LEGENDARY]

const ACQUISITION_DEFAULT := "default"
const ACQUISITION_GAMEPLAY := "gameplay_unlock"
const ACQUISITION_COIN_PURCHASE := "coin_purchase"
const ACQUISITION_TOKEN_PURCHASE := "token_purchase"
const ACQUISITION_ACHIEVEMENT := "achievement"
const ACQUISITION_SUPPORTER := "supporter_entitlement"
const ACQUISITION_FUTURE := "limited_future"
const VALID_ACQUISITIONS := [
	ACQUISITION_DEFAULT,
	ACQUISITION_GAMEPLAY,
	ACQUISITION_COIN_PURCHASE,
	ACQUISITION_TOKEN_PURCHASE,
	ACQUISITION_ACHIEVEMENT,
	ACQUISITION_SUPPORTER,
	ACQUISITION_FUTURE,
]

const REQUIREMENT_DEFAULT := "default"
const REQUIREMENT_LEVEL_COMPLETE := "level_complete"
const REQUIREMENT_TOTAL_STARS := "total_stars"
const REQUIREMENT_ENTITLEMENT := "entitlement"
const REQUIREMENT_COIN_PURCHASE := "coin_purchase"
const REQUIREMENT_TOKEN_PURCHASE := "token_purchase"
const REQUIREMENT_FUTURE := "future"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"

const PREVIEW_RESOURCE := "res://scripts/cosmetics/cosmetic_preview.gd"
const GAMEPLAY_VISUAL_RESOURCE := "res://scripts/cosmetics/cosmetic_visuals.gd"

# Compact catalog rows keep hundreds of definitions practical while get_all() exposes
# a full explicit schema to save, shop, preview, and gameplay systems.
# id, name, category, rarity, description, acquisition, coin, token, requirement,
# color, sort, is_default, featured
const CATALOG_ROWS := [
	["ball_classic", "Classic", CATEGORY_BALL, RARITY_COMMON, "Clean black-and-white match ball.", ACQUISITION_DEFAULT, 0, 0, {"type": REQUIREMENT_DEFAULT}, Color.WHITE, 10, true, false],
	["ball_neon", "Neon", CATEGORY_BALL, RARITY_RARE, "Dark shell with bright cyan arcade panels.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_02"}, Color("20e7f0"), 20, false, false],
	["ball_fire", "Fire", CATEGORY_BALL, RARITY_RARE, "Hot orange shell with ember accents.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 6}, Color("ff5a18"), 30, false, false],
	["ball_ice", "Ice", CATEGORY_BALL, RARITY_RARE, "Frosted blue-white finish.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_06"}, Color("b8ecff"), 40, false, false],
	["ball_galaxy", "Galaxy", CATEGORY_BALL, RARITY_EPIC, "Deep-space shell with bright star panels.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_10"}, Color("7547e8"), 50, false, true],
	["ball_champion", "Champion", CATEGORY_BALL, RARITY_EPIC, "Victory blue with a crisp trophy-gold band.", ACQUISITION_ACHIEVEMENT, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 27}, Color("2774d8"), 55, false, false],
	["ball_gold", "Gold", CATEGORY_BALL, RARITY_LEGENDARY, "Metallic finish for a perfect star sweep.", ACQUISITION_ACHIEVEMENT, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 30}, Color("f3b72a"), 60, false, true],
	["ball_supporter", "Supporter", CATEGORY_BALL, RARITY_EPIC, "Teal-and-gold finish from the Starter Pack.", ACQUISITION_SUPPORTER, 0, 0, {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK}, Color("1de2bd"), 70, false, true],
	["ball_candy", "Candy Stripe", CATEGORY_BALL, RARITY_COMMON, "A cherry-and-cream playground favorite.", ACQUISITION_COIN_PURCHASE, 1000, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("ff5f74"), 80, false, true],
	["ball_mint", "Mint Chip", CATEGORY_BALL, RARITY_COMMON, "Cool mint shell with chocolate-dark panels.", ACQUISITION_COIN_PURCHASE, 1800, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("8ce7c2"), 90, false, false],
	["ball_watermelon", "Watermelon", CATEGORY_BALL, RARITY_COMMON, "Juicy pink center wrapped in a green rind.", ACQUISITION_COIN_PURCHASE, 2200, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("ff657f"), 100, false, false],
	["ball_sunset", "Sunset Pop", CATEGORY_BALL, RARITY_RARE, "Warm coral and violet for late-arena shots.", ACQUISITION_COIN_PURCHASE, 4000, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("ff7752"), 110, false, false],
	["ball_checker", "Checkerboard", CATEGORY_BALL, RARITY_RARE, "High-contrast race-day checks built for spin.", ACQUISITION_COIN_PURCHASE, 5500, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("f4f0d9"), 120, false, false],
	["ball_cloud", "Cloud Nine", CATEGORY_BALL, RARITY_EPIC, "Soft sky blue with a bright silver lining.", ACQUISITION_COIN_PURCHASE, 9000, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("9bdcff"), 130, false, false],
	["ball_comet", "Comet", CATEGORY_BALL, RARITY_RARE, "Midnight shell with a sharp white-hot strike band.", ACQUISITION_TOKEN_PURCHASE, 0, 50, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("304a78"), 140, false, true],
	["ball_lava", "Lava Core", CATEGORY_BALL, RARITY_RARE, "Cracked charcoal wrapped around a molten core.", ACQUISITION_TOKEN_PURCHASE, 0, 80, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("ff6a19"), 150, false, false],
	["ball_prism", "Prism", CATEGORY_BALL, RARITY_EPIC, "Pearl shell with a clean spectrum accent.", ACQUISITION_TOKEN_PURCHASE, 0, 150, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("a7f4ff"), 160, false, true],
	["ball_void", "The Void", CATEGORY_BALL, RARITY_LEGENDARY, "Ink-black finish with a single impossible horizon.", ACQUISITION_TOKEN_PURCHASE, 0, 320, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("151323"), 170, false, true],

	["trail_none", "None", CATEGORY_TRAIL, RARITY_COMMON, "No trail effect.", ACQUISITION_DEFAULT, 0, 0, {"type": REQUIREMENT_DEFAULT}, Color("bdcbd0"), 210, true, false],
	["trail_blue", "Blue Streak", CATEGORY_TRAIL, RARITY_RARE, "A clean cyan wake behind fast shots.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_04"}, Color("31b9ff"), 220, false, false],
	["trail_flame", "Flame", CATEGORY_TRAIL, RARITY_RARE, "Short warm particles on powerful shots.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 12}, Color("ff7414"), 230, false, false],
	["trail_spark", "Spark", CATEGORY_TRAIL, RARITY_RARE, "Small bright sparks during fast movement.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_08"}, Color("ffe94d"), 240, false, false],
	["trail_rainbow", "Rainbow", CATEGORY_TRAIL, RARITY_EPIC, "A playful multi-color ribbon.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 24}, Color("f052dc"), 250, false, true],
	["trail_supporter", "Supporter Trail", CATEGORY_TRAIL, RARITY_EPIC, "A restrained teal-gold ribbon for supporters.", ACQUISITION_SUPPORTER, 0, 0, {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK}, Color("33f0bd"), 260, false, true],
	["trail_chalk", "Chalk Line", CATEGORY_TRAIL, RARITY_COMMON, "A dusty white training-line trace.", ACQUISITION_COIN_PURCHASE, 1200, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("f5f0da"), 270, false, true],
	["trail_bubble", "Bubbles", CATEGORY_TRAIL, RARITY_COMMON, "Round aqua pops that vanish quickly.", ACQUISITION_COIN_PURCHASE, 2000, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("7ce8ef"), 280, false, false],
	["trail_streamers", "Paper Streamers", CATEGORY_TRAIL, RARITY_RARE, "Short coral and yellow paper dashes.", ACQUISITION_COIN_PURCHASE, 4500, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("ff7069"), 290, false, false],
	["trail_comet", "Comet Tail", CATEGORY_TRAIL, RARITY_RARE, "A compact silver-blue speed taper.", ACQUISITION_TOKEN_PURCHASE, 0, 60, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("bdeaff"), 300, false, true],
	["trail_pixel", "Pixel Dash", CATEGORY_TRAIL, RARITY_EPIC, "Chunky arcade squares in a crisp violet lane.", ACQUISITION_TOKEN_PURCHASE, 0, 140, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("ae75ff"), 310, false, false],
	["trail_starfall", "Starfall", CATEGORY_TRAIL, RARITY_LEGENDARY, "Gold star beats with a deep-blue finish.", ACQUISITION_TOKEN_PURCHASE, 0, 300, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("ffd54e"), 320, false, true],

	["goal_classic", "Classic Flash", CATEGORY_GOAL_EFFECT, RARITY_COMMON, "Lightweight yellow goal flash and burst.", ACQUISITION_DEFAULT, 0, 0, {"type": REQUIREMENT_DEFAULT}, Color("ffe348"), 410, true, false],
	["goal_confetti", "Confetti", CATEGORY_GOAL_EFFECT, RARITY_RARE, "Short celebratory color burst.", ACQUISITION_GAMEPLAY, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 18}, Color("52ea8e"), 420, false, false],
	["goal_shockwave", "Shockwave", CATEGORY_GOAL_EFFECT, RARITY_LEGENDARY, "A clean expanding pulse from the goal mouth.", ACQUISITION_ACHIEVEMENT, 0, 0, {"type": REQUIREMENT_TOTAL_STARS, "stars": 30}, Color("45d8ff"), 430, false, true],
	["goal_supporter", "Supporter Burst", CATEGORY_GOAL_EFFECT, RARITY_EPIC, "A teal-and-gold celebration for Starter Pack owners.", ACQUISITION_SUPPORTER, 0, 0, {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK}, Color("2aefb5"), 440, false, true],
	["goal_ribbons", "Victory Ribbons", CATEGORY_GOAL_EFFECT, RARITY_COMMON, "Bold paper ribbons snap across the goal mouth.", ACQUISITION_COIN_PURCHASE, 1800, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("ff6d63"), 450, false, true],
	["goal_splash", "Color Splash", CATEGORY_GOAL_EFFECT, RARITY_RARE, "A compact paint-like burst with no debris.", ACQUISITION_COIN_PURCHASE, 5000, 0, {"type": REQUIREMENT_COIN_PURCHASE}, Color("3ad7c5"), 460, false, false],
	["goal_fireworks", "Pocket Fireworks", CATEGORY_GOAL_EFFECT, RARITY_EPIC, "Two quick starbursts above the white frame.", ACQUISITION_TOKEN_PURCHASE, 0, 150, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("ffb52e"), 470, false, true],
	["goal_portal", "Goal Portal", CATEGORY_GOAL_EFFECT, RARITY_LEGENDARY, "Twin violet rings fold through the target.", ACQUISITION_TOKEN_PURCHASE, 0, 350, {"type": REQUIREMENT_TOKEN_PURCHASE}, Color("9367ff"), 480, false, true],
]

const LEGACY_IDS := {
	"classic": "ball_classic", "neon": "ball_neon", "fire": "ball_fire",
	"ice": "ball_ice", "galaxy": "ball_galaxy", "gold": "ball_gold",
	"supporter": "ball_supporter", "none": "trail_none", "blue": "trail_blue",
	"flame": "trail_flame", "spark": "trail_spark", "rainbow": "trail_rainbow",
	"supporter_trail": "trail_supporter", "flash": "goal_classic",
	"confetti": "goal_confetti", "shockwave": "goal_shockwave",
	"supporter_goal": "goal_supporter", "ball:classic": "ball_classic",
	"ball:neon": "ball_neon", "ball:fire": "ball_fire", "ball:ice": "ball_ice",
	"ball:galaxy": "ball_galaxy", "ball:gold": "ball_gold",
	"ball:supporter": "ball_supporter", "trail:none": "trail_none",
	"trail:blue": "trail_blue", "trail:flame": "trail_flame",
	"trail:spark": "trail_spark", "trail:rainbow": "trail_rainbow",
	"trail:supporter": "trail_supporter", "goal_effect:classic": "goal_classic",
	"goal_effect:flash": "goal_classic", "goal_effect:confetti": "goal_confetti",
	"goal_effect:shockwave": "goal_shockwave", "goal_effect:supporter": "goal_supporter",
}


static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in CATALOG_ROWS:
		result.append(_definition_from_row(row as Array))
	result.sort_custom(_sort_by_order)
	return result


static func get_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in get_all():
		if String(definition.category) == category and not bool(definition.hidden):
			result.append(definition)
	return result


static func get_definition(cosmetic_id: String) -> Dictionary:
	var normalized := normalize_any_id(cosmetic_id)
	for definition in get_all():
		if String(definition.cosmetic_id) == normalized:
			return definition
	return {}


static func has_cosmetic(cosmetic_id: String) -> bool:
	return not get_definition(cosmetic_id).is_empty()


static func get_display_name(cosmetic_id: String) -> String:
	return String(get_definition(cosmetic_id).get("display_name", cosmetic_id))


static func get_category(cosmetic_id: String) -> String:
	return String(get_definition(cosmetic_id).get("category", ""))


static func get_category_display_name(category: String) -> String:
	match category:
		CATEGORY_BALL: return "Ball"
		CATEGORY_TRAIL: return "Trail"
		CATEGORY_GOAL_EFFECT: return "Goal Effect"
		_: return category.capitalize()


static func get_category_plural_name(category: String) -> String:
	match category:
		CATEGORY_BALL: return "Balls"
		CATEGORY_TRAIL: return "Trails"
		CATEGORY_GOAL_EFFECT: return "Goal Effects"
		_: return category.capitalize()


static func get_selection_key(category: String) -> String:
	match category:
		CATEGORY_BALL: return "selected_ball"
		CATEGORY_TRAIL: return "selected_trail"
		CATEGORY_GOAL_EFFECT: return "selected_goal_effect"
		_: return ""


static func is_valid_category(category: String) -> bool:
	return VALID_CATEGORIES.has(category)


static func get_default_for_category(category: String) -> String:
	for definition in get_all():
		if String(definition.category) == category and bool(definition.is_default):
			return String(definition.cosmetic_id)
	return ""


static func get_default_ids() -> Array[String]:
	var ids: Array[String] = []
	for category in VALID_CATEGORIES:
		ids.append(get_default_for_category(String(category)))
	return ids


static func normalize_any_id(value: String) -> String:
	var trimmed := value.strip_edges()
	return String(LEGACY_IDS[trimmed]) if LEGACY_IDS.has(trimmed) else trimmed


static func normalize_id_for_category(category: String, value: String) -> String:
	var normalized := normalize_any_id(value)
	var definition := get_definition(normalized)
	if definition.is_empty() or String(definition.category) != category:
		return get_default_for_category(category)
	return normalized


static func get_unlock_requirement_text(cosmetic_id: String) -> String:
	var definition := get_definition(cosmetic_id)
	if definition.is_empty():
		return "Unavailable"
	match String(definition.acquisition_method):
		ACQUISITION_DEFAULT:
			return "Starter item"
		ACQUISITION_COIN_PURCHASE:
			return "%s Arcade Coins" % _format_number(int(definition.coin_price))
		ACQUISITION_TOKEN_PURCHASE:
			return "%s Net Tokens" % _format_number(int(definition.token_price))
		ACQUISITION_SUPPORTER:
			return "Own the Starter Pack"
		ACQUISITION_FUTURE:
			return "Coming in a future event"
		_:
			var requirement := definition.unlock_requirement as Dictionary
			if String(requirement.get("type", "")) == REQUIREMENT_LEVEL_COMPLETE:
				return "Complete Level %02d" % _level_number(String(requirement.get("level_id", "")))
			if String(requirement.get("type", "")) == REQUIREMENT_TOTAL_STARS:
				return "Earn %d stars" % int(requirement.get("stars", 0))
	return "Unavailable"


static func get_price_text(cosmetic_id: String) -> String:
	var definition := get_definition(cosmetic_id)
	if definition.is_empty():
		return ""
	if String(definition.acquisition_method) == ACQUISITION_COIN_PURCHASE:
		return "%s COINS" % _format_number(int(definition.coin_price))
	if String(definition.acquisition_method) == ACQUISITION_TOKEN_PURCHASE:
		return "%s TOKENS" % _format_number(int(definition.token_price))
	return ""


static func is_currency_purchase(cosmetic_id: String) -> bool:
	var acquisition := String(get_definition(cosmetic_id).get("acquisition_method", ""))
	return acquisition in [ACQUISITION_COIN_PURCHASE, ACQUISITION_TOKEN_PURCHASE]


static func is_requirement_met(cosmetic_id: String, completed_levels: Array, total_stars: int) -> bool:
	var definition := get_definition(cosmetic_id)
	if definition.is_empty():
		return false
	var acquisition := String(definition.acquisition_method)
	if acquisition == ACQUISITION_DEFAULT:
		return true
	if acquisition not in [ACQUISITION_GAMEPLAY, ACQUISITION_ACHIEVEMENT]:
		return false
	var requirement := definition.unlock_requirement as Dictionary
	match String(requirement.get("type", "")):
		REQUIREMENT_LEVEL_COMPLETE:
			return _array_contains_string(completed_levels, String(requirement.get("level_id", "")))
		REQUIREMENT_TOTAL_STARS:
			return total_stars >= int(requirement.get("stars", 0))
		_:
			return false


static func get_sorted_ids(ids: Array) -> Array[String]:
	var order := {}
	for definition in get_all():
		order[String(definition.cosmetic_id)] = int(definition.sort_order)
	var unique: Array[String] = []
	for raw_id in ids:
		var cosmetic_id := normalize_any_id(String(raw_id))
		if order.has(cosmetic_id) and not unique.has(cosmetic_id):
			unique.append(cosmetic_id)
	unique.sort_custom(func(a: String, b: String) -> bool: return int(order[a]) < int(order[b]))
	return unique


static func validate_registry() -> Dictionary:
	var errors: Array[String] = []
	var seen := {}
	var defaults_by_category := {}
	for category in VALID_CATEGORIES:
		defaults_by_category[String(category)] = 0
	for definition in get_all():
		var cosmetic_id := String(definition.cosmetic_id)
		var category := String(definition.category)
		var acquisition := String(definition.acquisition_method)
		if cosmetic_id.is_empty() or seen.has(cosmetic_id):
			errors.append("empty or duplicate cosmetic id %s" % cosmetic_id)
		seen[cosmetic_id] = true
		if not VALID_CATEGORIES.has(category):
			errors.append("invalid category for %s" % cosmetic_id)
		if not VALID_RARITIES.has(String(definition.rarity)):
			errors.append("invalid rarity for %s" % cosmetic_id)
		if not VALID_ACQUISITIONS.has(acquisition):
			errors.append("invalid acquisition for %s" % cosmetic_id)
		if bool(definition.is_default):
			defaults_by_category[category] = int(defaults_by_category.get(category, 0)) + 1
		if not _valid_acquisition_fields(definition):
			errors.append("invalid acquisition fields for %s" % cosmetic_id)
		if not ResourceLoader.exists(String(definition.preview_resource)):
			errors.append("missing preview resource for %s" % cosmetic_id)
		if not ResourceLoader.exists(String(definition.gameplay_visual_resource)):
			errors.append("missing gameplay resource for %s" % cosmetic_id)
	for category in VALID_CATEGORIES:
		if int(defaults_by_category.get(String(category), 0)) != 1:
			errors.append("expected one default for %s" % String(category))
	return {"ok": errors.is_empty(), "errors": errors}


static func _definition_from_row(row: Array) -> Dictionary:
	var requirement := (row[8] as Dictionary).duplicate(true)
	var acquisition := String(row[5])
	return {
		"cosmetic_id": String(row[0]),
		"display_name": String(row[1]),
		"category": String(row[2]),
		"rarity": String(row[3]),
		"description": String(row[4]),
		"acquisition_method": acquisition,
		"coin_price": int(row[6]),
		"token_price": int(row[7]),
		"unlock_requirement": requirement,
		"level_requirement": String(requirement.get("level_id", "")),
		"star_requirement": int(requirement.get("stars", 0)),
		"achievement_requirement": "all_stars" if acquisition == ACQUISITION_ACHIEVEMENT else "",
		"starter_pack_requirement": acquisition == ACQUISITION_SUPPORTER,
		"direct_purchase_requirement": acquisition in [ACQUISITION_COIN_PURCHASE, ACQUISITION_TOKEN_PURCHASE],
		"preview_resource": PREVIEW_RESOURCE,
		"gameplay_visual_resource": GAMEPLAY_VISUAL_RESOURCE,
		"visual_style": String(row[0]),
		"preview_color": row[9] as Color,
		"sort_order": int(row[10]),
		"is_default": bool(row[11]),
		"default_unlocked": acquisition == ACQUISITION_DEFAULT,
		"hidden": false,
		"featured": bool(row[12]),
	}


static func _valid_acquisition_fields(definition: Dictionary) -> bool:
	var acquisition := String(definition.acquisition_method)
	var coins := int(definition.coin_price)
	var tokens := int(definition.token_price)
	var requirement := definition.unlock_requirement as Dictionary
	match acquisition:
		ACQUISITION_DEFAULT:
			return bool(definition.is_default) and coins == 0 and tokens == 0 and String(requirement.get("type", "")) == REQUIREMENT_DEFAULT
		ACQUISITION_COIN_PURCHASE:
			return coins > 0 and tokens == 0 and String(requirement.get("type", "")) == REQUIREMENT_COIN_PURCHASE
		ACQUISITION_TOKEN_PURCHASE:
			return tokens > 0 and coins == 0 and String(requirement.get("type", "")) == REQUIREMENT_TOKEN_PURCHASE
		ACQUISITION_SUPPORTER:
			return String(requirement.get("entitlement_id", "")) == ENTITLEMENT_STARTER_PACK
		ACQUISITION_GAMEPLAY, ACQUISITION_ACHIEVEMENT:
			return _is_valid_progress_requirement(requirement) and coins == 0 and tokens == 0
		ACQUISITION_FUTURE:
			return String(requirement.get("type", "")) == REQUIREMENT_FUTURE
		_:
			return false


static func _is_valid_progress_requirement(requirement: Dictionary) -> bool:
	match String(requirement.get("type", "")):
		REQUIREMENT_LEVEL_COMPLETE:
			return LevelRegistryScript.has_level_id(String(requirement.get("level_id", "")))
		REQUIREMENT_TOTAL_STARS:
			return int(requirement.get("stars", -1)) in range(1, 31)
		_:
			return false


static func _level_number(level_id: String) -> int:
	var parts := level_id.split("_")
	return int(parts[1]) if parts.size() == 2 else 0


static func _array_contains_string(values: Array, needle: String) -> bool:
	for value in values:
		if String(value) == needle:
			return true
	return false


static func _sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	return int(a.sort_order) < int(b.sort_order)


static func _format_number(value: int) -> String:
	var text := str(maxi(value, 0))
	var result := ""
	while text.length() > 3:
		result = ",%s%s" % [text.right(3), result]
		text = text.left(text.length() - 3)
	return "%s%s" % [text, result]
