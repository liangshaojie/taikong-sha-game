extends RefCounted

# Role - 角色枚举和常量
class_name Role

enum Kind {
	UNKNOWN = 0,
	CREWMATE = 1,
	IMPOSTOR = 2,
	GHOST = 3,  # 死亡后变成鬼魂（保留身份但不可操作）
}

const COLOR_BY_ROLE := {
	Kind.CREWMATE: Color(0.30, 0.80, 0.40),   # 绿色
	Kind.IMPOSTOR: Color(1.00, 0.30, 0.30),   # 红色
	Kind.GHOST:    Color(0.50, 0.50, 0.50, 0.5),  # 半透明灰
}

static func get_color(role: int) -> Color:
	return COLOR_BY_ROLE.get(role, Color.WHITE)

static func name_zh(role: int) -> String:
	match role:
		Kind.CREWMATE: return "船员"
		Kind.IMPOSTOR: return "内鬼"
		Kind.GHOST: return "鬼魂"
		_: return "未知"
