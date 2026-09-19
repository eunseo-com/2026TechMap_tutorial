# Chapter 1–4 읽기 페이지

콘텐츠의 원본은 `Guides/SceneKitToRealityKit.docc`다.
`render.py`는 DocC가 생성한 JSON을 읽어 목차, 단계별 본문, 전체 코드, 복사 버튼을 가진 네 페이지를 만든다. 경로는 1장 `/`, 2–4장 `/chapters/2/`·`/chapters/3/`·`/chapters/4/`이며 전체 장 탐색과 이전·다음 장으로 연결한다. 기존 `/tutorials/` DocC 주소도 유지한다.

## GitHub Pages 갱신

저장소 루트에서 실행합니다. 기존 앱 해설을 먼저 생성·검증한 뒤 읽기 페이지를 합칩니다.

```sh
bash scripts/verify-docc-content.sh
bash scripts/build-docc-site.sh /tmp/techmap-pages
bash scripts/verify-docc-site.sh /tmp/techmap-pages
bash scripts/build-readable-guide.sh /tmp/techmap-pages
python3 tools/tutorial_site/verify.py /tmp/techmap-pages --base-path /2026TechMap_tutorial --docc-subdirectory guide
node --check tools/tutorial_site/reader.js
npm run verify:docc-browser -- /tmp/techmap-pages tools/tutorial_site/browser-routes.json
```

공개 주소는 `https://eunseo-com.github.io/2026TechMap_tutorial/`입니다. `main` 변경 시 기존 Pages workflow가 배포합니다. 별도 호스팅용 `docc-site/` 저장소는 GitHub Pages에 사용하지 않습니다.

`render.py`의 `--base-path`는 읽기 페이지의 링크와 자산 주소에 저장소 경로를 붙입니다. `--docc-subdirectory guide`는 실습의 DocC 원문·이미지·다운로드를 기존 앱 해설과 충돌하지 않게 둡니다. 코드 블록 안의 문자열은 바꾸지 않습니다. 기존 튜토리얼 주소 다섯 개는 새 읽기 페이지로 이동하고 심화 문서 주소는 유지합니다.

Swift 예제를 바꿀 때만 아래 명령으로 다운로드를 다시 묶습니다.

```sh
python3 tools/tutorial_site/package_lab.py --model /path/to/Piggy.usdc
# 특정 장만 변경했다면 --chapter 2처럼 지정합니다.
```

생성된 DocC 아카이브·빌드·검증용 앱은 원문 저장소에 커밋하지 않는다.
실습 ZIP은 사용자가 내려받는 문서 자산이다. 기본 실습의 `ClosedWorld-QuickStart.zip`은 준비 파일 두 개와 세 단계의 정답을, 선택 학습의 `ClosedWorld-Lab.zip`은 다섯 구간의 코드를 포함한다. 두 자료 모두 승인된 원본 돼지 모델을 포함한다.

2–4장은 `OpeningTheDoor-Lab.zip`, `RealHideAndSeek-Lab.zip`, `Comparison-Lab.zip`을 사용한다. 각각 `Starter`에 준비 코드와 모델, `Answers/1`–`3`에 `ContentView.swift`를 포함한다. 2·3장은 AR 지원 실물 기기, 3장의 메시 가려짐은 LiDAR 및 메시 재구성 지원이 필요하다. 4장은 카메라 없는 장면으로 시뮬레이터에서 진행한다.

1장 기본 실습은 8개 단계이며 독자는 `ContentView.swift` 하나만 수정한다. `QuickStart-SceneSupport.swift`는 선택 학습의 화면 연결·모델 로딩·방·돼지·소파 코드를 합친 준비 파일이다. 해당 코드를 변경하면 준비 파일에도 반영하고 두 실습 자료를 다시 묶는다. 이전 단계와 달라진 줄은 DocC 코드 원문을 비교해 표시하며, 복사 문자열에는 강조용 표시를 넣지 않는다.

## 확인 범위

`verify.py`는 1장 기본 실습 3개·선택 학습 5개 구간과 2–4장 각 3개 구간을 그 시점까지 소개된 파일만으로 타입 검사한다. 기본 12개 구간은 새 Xcode 앱의 MainActor·모듈 가시성 설정으로 검사한다. 2–4장의 9개 구간은 시뮬레이터와 기기 SDK 모두 검사하며, 왕복 이동 계산은 호스트에서 실행한다.
다운로드 코드와 원본 스니펫이 같은지, HTML 코드에 복사 시 공백·태그가 섞이지 않는지,
네 페이지의 목차 앵커·장 이동·로컬 자산 경로가 존재하는지 확인한다. 기본 페이지의 전체 코드 블록은 3·3·3·4개다. 4장의 마지막 하나는 읽기 전용 시스템 코드다.

화면 확인은 데스크톱과 390px 모바일 폭에서 수행한다. 본문·목차·코드 펼침은 JavaScript 없이도 사용할 수 있다.
복사는 Clipboard API와 선택 기반 대안을 사용하며 실패하면 직접 복사 안내를 표시한다.
브라우저의 글자 크기와 간격을 강제로 고정하지 않는다.

## 다운로드 자료로 실행 재현하기

아래 절차는 유지보수자의 실행 검증용이다. 독자는 튜토리얼의 Xcode 새 앱 절차를 따른다.

```sh
python3 tools/tutorial_site/prepare_rehearsal.py /tmp/closedworld-rehearsal
cd /tmp/closedworld-rehearsal
tuist generate --no-open
```

생성된 `ClosedWorldLab.xcodeproj`의 `ClosedWorldLab` 스킴을 iPhone 시뮬레이터에서 실행한다. `Answers/1.swift`, `2.swift`, `3.swift`를 차례로 `Sources/ContentView.swift`에 복사하고 각 단계마다 다시 빌드·실행한다. 마지막 단계는 화면을 눌러 이동까지 확인한다. 준비 파일과 모델은 ZIP에서 직접 추출하므로 원문 저장소의 다른 앱 소스에 의존하지 않는다.

새 장의 최종 단계를 재현하려면 장마다 별도 디렉터리를 사용한다.

```sh
python3 tools/tutorial_site/prepare_rehearsal.py /tmp/techmap-chapter4 --chapter 4 --stage 3
cd /tmp/techmap-chapter4
tuist generate --no-open
```

스킴 이름은 2장 `OpeningTheDoorLab`, 3장 `RealHideAndSeekLab`, 4장 `ComparisonLab`이다. `--stage 1`·`2`·`3`으로 실행할 정답을 고른다. 앱 생성기는 2·3장의 카메라 설명 키도 추가한다. 시뮬레이터에서는 2·3장의 실물 기기 필요 안내만 검증할 수 있다. 실측 AR를 확인하려면 튜토리얼의 지원 조건과 서명을 설정하고 실물 기기에서 실행한다.

실행 검증은 초보자의 사용성 검증과 구분한다. 확인한 결과와 남은 절차는 [1장 피드백 대응 기록](../../docs/tutorial-feedback-validation.md)과 [2–4장 검증 기록](../../docs/chapters-2-4-validation.md)에 있다.

문장·준비 과정의 최신 편집 기준은 [초보 독자 편집 기록](../../docs/beginner-tutorial-editing.md)을 따른다. 오류 도움말은 HTML details로 접고, 모바일 목차는 화면 폭에 따라 초기 상태를 정한다. 실행 확인과 기본 코드는 바로 읽을 수 있다.
