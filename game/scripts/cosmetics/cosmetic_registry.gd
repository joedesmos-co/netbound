class_name CosmeticRegistry
extends RefCounted

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const CATEGORY_BALL := "ball"
const CATEGORY_TRAIL := "trail"
const CATEGORY_GOAL_EFFECT := "goal_effect"

const VALID_CATEGORIES := [
	CATEGORY_BALL,
	CATEGORY_TRAIL,
	CATEGORY_GOAL_EFFECT,
]

const REQUIREMENT_DEFAULT := "default"
const REQUIREMENT_LEVEL_COMPLETE := "level_complete"
const REQUIREMENT_TOTAL_STARS := "total_stars"
const REQUIREMENT_ENTITLEMENT := "entitlement"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"

const DEFINITIONS := [
	{
		"cosmetic_id": "ball_classic",
		"display_name": "Classic",
		"category": CATEGORY_BALL,
		"description": "Clean black-and-white match ball.",
		"unlock_requirement": {"type": REQUIREMENT_DEFAULT},
		"preview_color": Color(1.0, 1.0, 1.0, 1.0),
		"sort_order": 10,
		"is_default": true,
		"default_unlocked": true,
	},
	{
		"cosmetic_id": "ball_neon",
		"display_name": "Neon",
		"category": CATEGORY_BALL,
		"description": "Dark shell with bright cyan arcade panels.",
		"unlock_requirement": {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_02"},
		"preview_color": Color(0.0, 0.95, 1.0, 1.0),
		"sort_order": 20,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "ball_fire",
		"display_name": "Fire",
		"category": CATEGORY_BALL,
		"description": "Hot orange shell with ember accents.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 6},
		"preview_color": Color(1.0, 0.28, 0.05, 1.0),
		"sort_order": 30,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "ball_ice",
		"display_name": "Ice",
		"category": CATEGORY_BALL,
		"description": "Frosted blue-white finish.",
		"unlock_requirement": {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_06"},
		"preview_color": Color(0.72, 0.93, 1.0, 1.0),
		"sort_order": 40,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "ball_galaxy",
		"display_name": "Galaxy",
		"category": CATEGORY_BALL,
		"description": "Deep-space purple with star speckles.",
		"unlock_requirement": {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_10"},
		"preview_color": Color(0.38, 0.18, 0.9, 1.0),
		"sort_order": 50,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "ball_gold",
		"display_name": "Gold",
		"category": CATEGORY_BALL,
		"description": "Metallic finish for a perfect star sweep.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 30},
		"preview_color": Color(1.0, 0.76, 0.2, 1.0),
		"sort_order": 60,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "ball_supporter",
		"display_name": "Supporter",
		"category": CATEGORY_BALL,
		"description": "Premium teal-and-gold finish from the Starter Pack.",
		"unlock_requirement": {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK},
		"preview_color": Color(0.1, 0.92, 0.82, 1.0),
		"sort_order": 70,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "trail_none",
		"display_name": "None",
		"category": CATEGORY_TRAIL,
		"description": "No trail effect.",
		"unlock_requirement": {"type": REQUIREMENT_DEFAULT},
		"preview_color": Color(0.75, 0.8, 0.86, 1.0),
		"sort_order": 110,
		"is_default": true,
		"default_unlocked": true,
	},
	{
		"cosmetic_id": "trail_blue",
		"display_name": "Blue Streak",
		"category": CATEGORY_TRAIL,
		"description": "A clean cyan wake behind fast shots.",
		"unlock_requirement": {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_04"},
		"preview_color": Color(0.15, 0.72, 1.0, 1.0),
		"sort_order": 120,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "trail_flame",
		"display_name": "Flame",
		"category": CATEGORY_TRAIL,
		"description": "Short warm particles on powerful shots.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 12},
		"preview_color": Color(1.0, 0.42, 0.05, 1.0),
		"sort_order": 130,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "trail_spark",
		"display_name": "Spark",
		"category": CATEGORY_TRAIL,
		"description": "Small bright sparks during fast movement.",
		"unlock_requirement": {"type": REQUIREMENT_LEVEL_COMPLETE, "level_id": "level_08"},
		"preview_color": Color(1.0, 0.95, 0.35, 1.0),
		"sort_order": 140,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "trail_rainbow",
		"display_name": "Rainbow",
		"category": CATEGORY_TRAIL,
		"description": "Playful multi-color streak.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 24},
		"preview_color": Color(0.95, 0.25, 0.9, 1.0),
		"sort_order": 150,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "trail_supporter",
		"display_name": "Supporter Trail",
		"category": CATEGORY_TRAIL,
		"description": "A restrained teal-gold ribbon for supporters.",
		"unlock_requirement": {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK},
		"preview_color": Color(0.18, 1.0, 0.78, 1.0),
		"sort_order": 160,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "goal_classic",
		"display_name": "Classic Flash",
		"category": CATEGORY_GOAL_EFFECT,
		"description": "Lightweight goal flash and burst.",
		"unlock_requirement": {"type": REQUIREMENT_DEFAULT},
		"preview_color": Color(1.0, 0.94, 0.2, 1.0),
		"sort_order": 210,
		"is_default": true,
		"default_unlocked": true,
	},
	{
		"cosmetic_id": "goal_confetti",
		"display_name": "Confetti",
		"category": CATEGORY_GOAL_EFFECT,
		"description": "Short celebratory color burst.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 18},
		"preview_color": Color(0.3, 1.0, 0.55, 1.0),
		"sort_order": 220,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "goal_shockwave",
		"display_name": "Shockwave",
		"category": CATEGORY_GOAL_EFFECT,
		"description": "Purely visual pulse from the goal mouth.",
		"unlock_requirement": {"type": REQUIREMENT_TOTAL_STARS, "stars": 30},
		"preview_color": Color(0.3, 0.9, 1.0, 1.0),
		"sort_order": 230,
		"is_default": false,
		"default_unlocked": false,
	},
	{
		"cosmetic_id": "goal_supporter",
		"display_name": "Supporter Burst",
		"category": CATEGORY_GOAL_EFFECT,
		"description": "A teal-and-gold celebration for Starter Pack owners.",
		"unlock_requirement": {"type": REQUIREMENT_ENTITLEMENT, "entitlement_id": ENTITLEMENT_STARTER_PACK},
		"preview_color": Color(0.12, 0.95, 0.72, 1.0),
		"sort_order": 240,
		"is_default": false,
		"default_unlocked": false,
	},
]

const LEGACY_IDS := {
	"classic": "ball_classic",
	"neon": "ball_neon",
	"fire": "ball_fire",
	"ice": "ball_ice",
	"galaxy": "ball_galaxy",
	"gold": "ball_gold",
	"supporter": "ball_supporter",
	"none": "trail_none",
	"blue": "trail_blue",
	"flame": "trail_flame",
	"spark": "trail_spark",
	"rainbow": "trail_rainbow",
	"supporter_trail": "trail_supporter",
	"flash": "goal_classic",
	"confetti": "goal_confetti",
	"shockwave": "goal_shockwave",
	"supporter_goal": "goal_supporter",
	"ball:classic": "ball_classic",
	"ball:neon": "ball_neon",
	"ball:fire": "ball_fire",
	"ball:ice": "ball_ice",
	"ball:galaxy": "ball_galaxy",
	"ball:gold": "ball_gold",
	"ball:supporter": "ball_supporter",
	"trail:none": "trail_none",
	"trail:blue": "trail_blue",
	"trail:flame": "trail_flame",
	"trail:spark": "trail_spark",
	"trail:rainbow": "trail_rainbow",
	"trail:supporter": "trail_supporter",
	"goal_effect:classic": "goal_classic",
	"goal_effect:flash": "goal_classic",
	"goal_effect:confetti": "goal_confetti",
	"goal_effect:shockwave": "goal_shockwave",
	"goal_effect:supporter": "goal_supporter",
}


static func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in DEFINITIONS:
		result.append((definition as Dictionary).duplicate(true))
	result.sort_custom(_sort_by_order)
	return result


static func get_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in get_all():
		if String(definition.get("category", "")) == category:
			result.append(definition)
	return result


static func get_definition(cosmetic_id: String) -> Dictionary:
	var normalized := normalize_any_id(cosmetic_id)
	for definition in DEFINITIONS:
		if String((definition as Dictionary).get("cosmetic_id", "")) == normalized:
			return (definition as Dictionary).duplicate(true)
	return {}


static func has_cosmetic(cosmetic_id: String) -> bool:
	return not get_definition(cosmetic_id).is_empty()


static func get_display_name(cosmetic_id: String) -> String:
	var definition := get_definition(cosmetic_id)
	return String(definition.get("display_name", cosmetic_id))


static func get_category(cosmetic_id: String) -> String:
	var definition := get_definition(cosmetic_id)
	return String(definition.get("category", ""))


static func get_category_display_name(category: String) -> String:
	match category:
		CATEGORY_BALL:
			return "Ball"
		CATEGORY_TRAIL:
			return "Trail"
		CATEGORY_GOAL_EFFECT:
			return "Goal Effect"
		_:
			return category.capitalize()


static func get_category_plural_name(category: String) -> String:
	match category:
		CATEGORY_BALL:
			return "Balls"
		CATEGORY_TRAIL:
			return "Trails"
		CATEGORY_GOAL_EFFECT:
			return "Goal Effects"
		_:
			return category.capitalize()


static func get_selection_key(category: String) -> String:
	match category:
		CATEGORY_BALL:
			return "selected_ball"
		CATEGORY_TRAIL:
			return "selected_trail"
		CATEGORY_GOAL_EFFECT:
			return "selected_goal_effect"
		_:
			return ""


static func is_valid_category(category: String) -> bool:
	return VALID_CATEGORIES.has(category)


static func get_default_for_category(category: String) -> String:
	for definition in DEFINITIONS:
		var item := definition as Dictionary
		if String(item.get("category", "")) == category and bool(item.get("is_default", false)):
			return String(item.get("cosmetic_id", ""))
	return ""


static func get_default_ids() -> Array[String]:
	var ids: Array[String] = []
	for category in VALID_CATEGORIES:
		var default_id := get_default_for_category(String(category))
		if not default_id.is_empty():
			ids.append(default_id)
	return ids


static func normalize_any_id(value: String) -> String:
	var trimmed := value.strip_edges()
	if LEGACY_IDS.has(trimmed):
		return String(LEGACY_IDS[trimmed])
	return trimmed


static func normalize_id_for_category(category: String, value: String) -> String:
	var normalized := normalize_any_id(value)
	var definition := get_definition(normalized)
	if definition.is_empty() or String(definition.get("category", "")) != category:
		return get_default_for_category(category)
	return normalized


static func get_unlock_requirement_text(cosmetic_id: String) -> String:
	var definition := get_definition(cosmetic_id)
	var requirement: Dictionary = definition.get("unlock_requirement", {}) as Dictionary
	match String(requirement.get("type", "")):
		REQUIREMENT_DEFAULT:
			return "Available by default"
		REQUIREMENT_LEVEL_COMPLETE:
			return "Complete Level %02d" % _level_number(String(requirement.get("level_id", "")))
		REQUIREMENT_TOTAL_STARS:
			var stars := int(requirement.get("stars", 0))
			return "Earn %d total stars" % stars
		REQUIREMENT_ENTITLEMENT:
			return "Own the Starter Pack"
		_:
			return "Unlock requirement unavailable"


static func is_requirement_met(cosmetic_id: String, completed_levels: Array, total_stars: int) -> bool:
	var definition := get_definition(cosmetic_id)
	if definition.is_empty():
		return false
	var requirement: Dictionary = definition.get("unlock_requirement", {}) as Dictionary
	match String(requirement.get("type", "")):
		REQUIREMENT_DEFAULT:
			return true
		REQUIREMENT_LEVEL_COMPLETE:
			return _array_contains_string(completed_levels, String(requirement.get("level_id", "")))
		REQUIREMENT_TOTAL_STARS:
			return total_stars >= int(requirement.get("stars", 0))
		REQUIREMENT_ENTITLEMENT:
			return false
		_:
			return false


static func get_sorted_ids(ids: Array) -> Array[String]:
	var order := {}
	for definition in DEFINITIONS:
		var item := definition as Dictionary
		order[String(item.get("cosmetic_id", ""))] = int(item.get("sort_order", 0))
	var unique: Array[String] = []
	for raw_id in ids:
		var cosmetic_id := normalize_any_id(String(raw_id))
		if has_cosmetic(cosmetic_id) and not unique.has(cosmetic_id):
			unique.append(cosmetic_id)
	unique.sort_custom(func(a: String, b: String) -> bool: return int(order[a]) < int(order[b]))
	return unique


static func validate_registry() -> Dictionary:
	var errors: Array[String] = []
	var seen := {}
	var defaults_by_category := {}
	for category in VALID_CATEGORIES:
		defaults_by_category[String(category)] = 0

	for definition in DEFINITIONS:
		var item := definition as Dictionary
		var cosmetic_id := String(item.get("cosmetic_id", ""))
		var category := String(item.get("category", ""))
		var requirement: Dictionary = item.get("unlock_requirement", {}) as Dictionary
		if cosmetic_id.is_empty():
			errors.append("cosmetic has an empty id")
			continue
		if seen.has(cosmetic_id):
			errors.append("duplicate cosmetic id %s" % cosmetic_id)
		seen[cosmetic_id] = true
		if not is_valid_category(category):
			errors.append("invalid category for %s: %s" % [cosmetic_id, category])
		if bool(item.get("is_default", false)):
			defaults_by_category[category] = int(defaults_by_category.get(category, 0)) + 1
		if not _is_valid_requirement(requirement):
			errors.append("invalid unlock requirement for %s" % cosmetic_id)
		if not bool(item.get("default_unlocked", false)) and String(requirement.get("type", "")) == REQUIREMENT_DEFAULT:
			errors.append("default requirement must be default_unlocked for %s" % cosmetic_id)

	for category in VALID_CATEGORIES:
		if int(defaults_by_category.get(String(category), 0)) != 1:
			errors.append(
				"expected one default for %s, found %d" % [
					String(category),
					int(defaults_by_category.get(String(category), 0)),
				]
			)

	return {"ok": errors.is_empty(), "errors": errors}


static func _is_valid_requirement(requirement: Dictionary) -> bool:
	match String(requirement.get("type", "")):
		REQUIREMENT_DEFAULT:
			return true
		REQUIREMENT_LEVEL_COMPLETE:
			var level_id := String(requirement.get("level_id", ""))
			return LevelRegistryScript.has_level_id(level_id)
		REQUIREMENT_TOTAL_STARS:
			var stars := int(requirement.get("stars", -1))
			return stars > 0 and stars <= 30
		REQUIREMENT_ENTITLEMENT:
			return String(requirement.get("entitlement_id", "")) == ENTITLEMENT_STARTER_PACK
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
	return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
