# SceneKit에서 RealityKit으로

@Metadata {
    @TechnologyRoot
}

한 마리 돼지의 이동을 따라 SceneKit의 닫힌 세계와 RealityKit·ARKit의 현실 연결을 비교합니다.

## Overview

네 챕터의 앱 계약을 바탕으로 장면 그래프, 현실 공간 관찰, 실기기 진단, 마이그레이션 판단 기준을 함께 살펴봅니다. 단계별 체험은 튜토리얼에서 진행하고, 아래 문서에서는 구현 근거와 실패 복구 경계를 더 깊게 확인할 수 있습니다.

검증 경계: 독립 예제 type-check와 generic iPhoneOS build는 완료했습니다. 최신 XCTest assertion은 **실행 검증 대기**, 실제 mesh·가림·재발견은 **LiDAR 실기기 대기**입니다.

## Topics

### 구현 근거와 진단

- <doc:SceneGraphDeepDive>
- <doc:RealityKitECS>
- <doc:DeviceCameraDiagnostics>
- <doc:MigrationWorksheet>
