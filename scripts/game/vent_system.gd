extends RefCounted

# VentSystem - 通风管配置（静态工具类）
# 定义 vent 位置、连通图、交互半径

class_name VentSystem

# Vent 位置（房间内）
const VENT_POSITIONS := {
	"medbay":     Vector2(320, 250),
	"electrical": Vector2(740, 250),
	"reactor":    Vector2(540, 470),
	"navigation": Vector2(960, 470),
}

# Vent 连通图（双向）：medbay-electrical-reactor-navigation 链式
const VENT_NETWORK := {
	"medbay":     ["electrical"],
	"electrical": ["medbay", "reactor"],
	"reactor":    ["electrical", "navigation"],
	"navigation": ["reactor"],
}

const VENT_RADIUS := 50.0      # 玩家距 vent 多近可使用
const VENT_COOLDOWN := 10.0    # vent 使用后冷却（秒）

const VENT_NAMES_ZH := {
	"medbay":     "🏥 医疗舱",
	"electrical": "⚡ 电气舱",
	"reactor":    "⚛ 反应堆",
	"navigation": "🧭 导航舱",
}

# === 静态查询函数 ===

static func get_vent_at_position(pos: Vector2) -> String:
	for vent_id in VENT_POSITIONS:
		if pos.distance_to(VENT_POSITIONS[vent_id]) <= VENT_RADIUS:
			return vent_id
	return ""

static func get_connected_vents(vent_id: String) -> Array:
	if VENT_NETWORK.has(vent_id):
		return VENT_NETWORK[vent_id]
	return []

static func get_vent_position(vent_id: String) -> Vector2:
	return VENT_POSITIONS.get(vent_id, Vector2.ZERO)

static func get_vent_name_zh(vent_id: String) -> String:
	return VENT_NAMES_ZH.get(vent_id, vent_id)

static func is_valid_vent(vent_id: String) -> bool:
	return VENT_POSITIONS.has(vent_id)
