# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트

"무녀: 밤을 부르는 자" — Godot 4.6 / GDScript로 만드는 동료 지휘형 호드 서바이벌 액션 로그라이트의 **그레이박스 프로토타입**(아트 없음, 도형만). 컨셉 전문은 `무녀 - 게임 컨셉 & 시나리오 초안.md`.

## 명령

```sh
# 단위 테스트 전체 (GUT 비의존 자체 러너 — 실패 시 exit 1)
godot --headless --script test/test_runner.gd

# 게임플레이 스모크 1개 실행 (s2~s7) — --fixed-fps 60 필수(없으면 델타가 실시간이라 시뮬레이션이 짧아짐)
godot --headless --fixed-fps 60 --script test/smoke_s4.gd

# 게임 실행
godot scenes/main.tscn
```

단일 테스트 파일만 실행하는 방법은 없다 — 러너가 `test/test_*.gd`를 전부 수집한다. 특정 테스트만 보려면 임시로 다른 파일을 보지 말고 전체를 돌려라(현재 수백 ms 수준).

## 절대 어기면 안 되는 설계 불변식 (`.forge/adr/`)

- **무녀(플레이어)는 직접 공격하지 않는다** (ADR-0003). 어떤 입력·상태에서도 무녀발 피해 경로를 만들지 마라. 밀쳐내기는 비살상 위치 이동만. 무녀 드래프트 풀은 서포트 전용. 장르 관례(VS류)에 안 맞아 보여도 플레이 검증으로 내린 의도적 결정이다 — "고치지" 마라.
- **혼불은 전달형**: 수집 → 보유(stock) → 근접 동료에게 전달(무녀 몫 소멸) / 동료 부재 시 지연(3s) 후 무녀 흡수. 한 혼불이 무녀와 동료 양쪽을 성장시키는 경로(복제)를 만들면 안 된다.
- **드래프트는 무녀·동료 각자** 레벨업에 발생, 일시정지 + 큐 일괄 선택 (ADR-0002).
- 용어는 `.forge/CONTEXT.md`가 기준 (동료≠신장·펫, 명령≠스탠스, 밤≠스테이지 등). 코드 명명 매핑: 무녀=Munyeo, 혼불=Soulfire, 잡귀=Japgwi, 창귀=Changgwi, 탈 쓴 퇴마사=exorcist, 쓰러짐=downed.

## 아키텍처

- **씬은 `scenes/main.tscn` 하나뿐.** 모든 엔티티(무녀·동료·적·혼불·투사체)는 .tscn 없이 스크립트 `.new()`로 생성되고 각자 `_draw()`로 도형을 그린다. 물리 엔진 없이 거리 기반 판정(`distance_to`).
- **순수 결정로직은 전부 `scripts/logic/`의 노드 비의존 정적 클래스**(targeting, experience, aura, mp, command, companion_ai, soulfire_share, draft_pool, draft_queue, downed, changgwi_ai, night, spawn_curve). 씬 코드는 이를 호출만 한다. **게임 규칙을 바꿀 때는 logic 클래스를 바꾸고 테스트를 먼저 갱신하라(TDD가 이 레포의 관례).** 밸런스 기준선 상수(스폰 곡선 등)도 logic 클래스에 있어 테스트가 직접 단언한다.
- **그룹 시스템이 조회의 중심**: 적은 공통 `"enemy"` + 종족 그룹(`"japgwi"`, `"changgwi"`), 아군은 `"companion"`(+화랑만 `"hwarang"` — 잡귀 어그로 대상), `"soulfire"`. 새 적/아군은 반드시 해당 그룹에 넣어야 피격·타깃팅·분배에 잡힌다. 쓰러진(downed) 동료는 전투 그룹에서 빠졌다가 구출 시 재가입한다.
- **입력은 InputMap이 아니라 물리 키 폴링**(`Input.is_physical_key_pressed` — WASD/방향키, Space 밀쳐내기, 1~4 명령). 명령 상태는 무녀가 보유(`munyeo.command`)하고 동료가 매 프레임 읽는다.
- 드래프트 정지는 `get_tree().paused` + UI만 `PROCESS_MODE_ALWAYS`. 밤 타이머는 정지 중 흐르지 않는다.

## 테스트 작성 규약

- 단위 테스트: `test/test_<이름>.gd`, `extends "res://test/test_case.gd"`(class_name 아닌 경로 상속 — 헤드리스 --script 실행 제약), `test_`로 시작하는 메서드. 단언: `assert_true/false/eq/ne/almost_eq`.
- 스모크(`test/smoke_*.gd`): SceneTree 직접 확장 + 키 이벤트 주입 자동 조종. 작성 규칙 — ① 모니터 노드는 `PROCESS_MODE_ALWAYS`(정지에 갇힘 방지), ② MAX_FRAMES 검사를 pause 분기보다 앞에, ③ **검증 대상과 직교하는 조건(생존 등)은 고정**하고, ④ 드문 사건은 수동 대기 대신 상황을 조성해 관찰하라(예: 무녀 정지로 동료 원거리 교전 유도). 행동을 바꾸는 변경은 스모크 전제를 깨뜨린다 — 영향받는 스모크 목록을 먼저 점검하라.
- 비결정 요소(스폰 배치) 때문에 **스모크 변경 후엔 5회 이상 반복 실행으로 플레이크를 확인**하라.

## Godot 헤드리스 주의사항

- 새 `.gd` 추가/삭제 후 `godot --headless --import`로 `.uid` 동기화 — `.uid` 파일은 커밋 대상.
- 헤드리스 실행이 `project.godot`을 재저장해 더럽힐 수 있다 — 커밋 전 `git status` 확인, 의도치 않은 변경이면 복원.
- 테스트 러너는 `script.can_instantiate()` 가드로 파스 에러 스크립트의 행(hang)을 막는다(TDD red 단계에 필수) — 러너 수정 시 이 가드를 유지하라.

## 개발 루프 (forge)

이 레포는 forge 루프(fg-ask 그릴링 → fg-run 실행 → fg-learn 회고 → fg-done 봉인)로 개발한다. 영구 문서는 `.forge/CONTEXT.md`(용어집), `.forge/adr/`(설계 결정), `.forge/retro/`(회고 — 스모크 노하우 등 실전 교훈이 여기 쌓인다)이며 git 추적 대상이다. 작업 단위 상태(plan/run/STATUS/backlog/done)는 gitignore된 휘발 상태로, 직접 수정하지 말고 해당 스킬을 통해서만 다뤄라.
