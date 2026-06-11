# 쓰러짐(downed) 타이머·구출 판정 — 노드 비의존 순수 로직.
# 상태: {"time_left": float, "rescue_progress": float}
# 규칙: 제한 시간이 다 되면 이탈(lost). 무녀가 구출 반경 안(경계 포함)에 머무르면
# 진행도가 쌓여 rescue_time 도달 시 구출(rescued). 반경을 벗어나면 진행도 초기화.
# 같은 틱에 구출과 시간 만료가 겹치면 구출이 우선한다.
extends RefCounted


static func initial_state(down_time: float) -> Dictionary:
	return {"time_left": down_time, "rescue_progress": 0.0}


# 한 틱 진행. 입력 상태는 변경하지 않고 새 상태를 돌려준다.
# 반환: {"time_left", "rescue_progress", "status"("downed"|"rescued"|"lost")}
static func step(
	state: Dictionary, munyeo_distance: float, delta: float,
	rescue_radius: float, rescue_time: float,
) -> Dictionary:
	var time_left: float = state["time_left"] - delta
	var progress: float = state["rescue_progress"]
	if munyeo_distance <= rescue_radius:
		progress += delta
	else:
		progress = 0.0  # 근접 "유지"가 조건 — 떨어지면 처음부터
	var status := "downed"
	if progress >= rescue_time:
		status = "rescued"
	elif time_left <= 0.0:
		status = "lost"
	return {
		"time_left": maxf(time_left, 0.0),
		"rescue_progress": progress,
		"status": status,
	}
