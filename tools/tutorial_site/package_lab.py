"""Package the tutorial checkpoints; use the documented source files verbatim."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import argparse

ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ROOT / 'Guides/SceneKitToRealityKit.docc/Tutorials/Resources'


def checkpoints():
    files = {
        'ClosedWorldSceneView.swift': '00-view',
        'ClosedWorld.swift': '00-world',
        'ContentView.swift': '00-content',
    }
    for stage, changes in enumerate([
        {},
        {'AssetLoader.swift': '02-01', 'RoomBuilder.swift': '03-01', 'ClosedWorld.swift': '03-room'},
        {'PigPlacement.swift': '04-01', 'ClosedWorld.swift': '04-world'},
        {'FakeSofa.swift': '06-01', 'HideAction.swift': '06-02', 'ClosedWorld.swift': '03-02', 'ClosedWorldSceneView.swift': '01-01'},
        {'NodeInspector.swift': '05-01', 'ClosedWorldSceneView.swift': '05-view'},
    ], 1):
        files.update(changes)
        yield stage, {name: RESOURCES / f'01-ClosedWorld-{key}.swift' for name, key in files.items()}


def quick_checkpoints():
    for stage in range(1, 4):
        yield stage, {
            'SceneSupport.swift': RESOURCES / 'QuickStart-SceneSupport.swift',
            'ContentView.swift': RESOURCES / f'QuickStart-0{stage}-ContentView.swift',
        }


CHAPTER_LABS = {
    2: ('OpeningTheDoor-Lab', 'Door', ['SpatialSupport.swift', 'TutorialPig.swift']),
    3: ('RealHideAndSeek-Lab', 'Hide', ['SpatialSupport.swift', 'TutorialPig.swift']),
    4: ('Comparison-Lab', 'Compare', ['ECSSceneSupport.swift', 'TutorialPig.swift', 'PatrolSystem.swift', 'PatrolMotion.swift']),
}


def chapter_checkpoints(chapter):
    _, prefix, support = CHAPTER_LABS[chapter]
    for stage in range(1, 4):
        yield stage, {
            **{name: RESOURCES / name for name in support},
            'ContentView.swift': RESOURCES / f'{prefix}-0{stage}-ContentView.swift',
        }


def package_chapter(chapter, model):
    name, prefix, support = CHAPTER_LABS[chapter]
    if chapter in (2, 3):
        camera_note = '실물 AR 지원 iPhone·iPad가 필요합니다. 타깃 Info에 Privacy - Camera Usage Description (NSCameraUsageDescription)을 추가하고 카메라 사용 이유를 적으세요. 예: 실제 공간의 수평면에 돼지를 놓기 위해 카메라를 사용합니다. 실기기 실행에는 Signing의 Team과 Developer Mode 설정이 필요할 수 있습니다.'
    else:
        camera_note = 'iPhone 시뮬레이터에서 실행할 수 있습니다. 카메라 권한을 추가하지 않습니다.'
    if chapter == 3:
        camera_note += '\n메시 가려짐에는 LiDAR와 sceneReconstruction(.mesh) 지원이 필요합니다. 미지원 기기에서는 배치만 확인할 수 있습니다.'
    with ZipFile(RESOURCES / f'{name}.zip', 'w', ZIP_DEFLATED) as archive:
        for source in support:
            archive.write(RESOURCES/source, f'{name}/Starter/{source}')
        archive.write(model, f'{name}/Starter/Piggy.usdc')
        for stage, files in chapter_checkpoints(chapter):
            archive.write(files['ContentView.swift'], f'{name}/Answers/{stage}/ContentView.swift')
        archive.writestr(f'{name}/README.md', f'''# Chapter {chapter} 실습 자료

1. Xcode에서 새 iOS App을 만드세요. SwiftUI, Swift, Storage None을 선택합니다.
2. Starter 안의 파일들만 앱 타깃에 복사합니다. 폴더 전체 대신 파일들을 선택하세요.
3. 기존 ContentView.swift를 해당 단계의 Answers/1, 2, 3 안에 있는 파일 내용으로 교체합니다.
4. 단계마다 다시 빌드·실행하고 튜토리얼의 실행 확인과 비교하세요.

{camera_note}

Answers 전체를 Xcode에 넣으면 ContentView 중복 선언 오류가 생깁니다.
막혔을 때 해당 단계 파일의 내용만 복사해 기존 ContentView.swift를 교체하세요.
모델을 읽을 수 없으면 분홍 상자가 대신 나타납니다. Piggy.usdc의 앱 Target Membership과 Copy Bundle Resources를 확인하세요.
지원 파일은 튜토리얼의 준비 코드이며 기본 실습에서 수정하지 않습니다.
iOS 최소 버전은 17입니다. 카메라·실측 평면·메시 가려짐은 지원 실기기에서 별도 확인해야 합니다.
''')
    print(f'Packaged Chapter {chapter}: {name}.zip')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', required=True, type=Path)
    parser.add_argument('--chapter', action='append', type=int, choices=[1, 2, 3, 4])
    args = parser.parse_args()
    selected = args.chapter or [1, 2, 3, 4]
    if 1 in selected:
        with ZipFile(RESOURCES / 'ClosedWorld-Lab.zip', 'w', ZIP_DEFLATED) as archive:
            for stage, files in checkpoints():
                for name, source in files.items():
                    archive.write(source, f'ClosedWorld-Lab/Checkpoints/{stage}/{name}')
            archive.write(args.model, 'ClosedWorld-Lab/Models/Piggy.usdc')
            archive.writestr('ClosedWorld-Lab/README.md', '''# ClosedWorld 실습 자료

Xcode에서 iOS App을 만들고 Product Name ClosedWorldLab, SwiftUI, Swift를 선택하세요.
기본 ClosedWorldLabApp.swift는 그대로 둡니다.

- 튜토리얼을 처음부터 따라 할 때: Models/Piggy.usdc만 필요에 따라 추가합니다.
- 중간에 막혔을 때: Checkpoints/1~5 중 해당 구간의 Swift 파일만 사용하세요.
  같은 이름의 기존 파일은 내용을 교체하고 없는 파일만 새로 추가합니다.
  여러 Checkpoints 폴더를 한꺼번에 앱에 넣으면 중복 선언 오류가 발생합니다.
- 모델을 추가하지 않아도 분홍 상자로 모든 단계를 따라 할 수 있습니다.
- 각 구간 끝에서 시뮬레이터를 선택하고 ⌘R로 확인하세요.

1: 빈 화면 / 2: 방 / 3: 돼지 / 4: 탭 이동 / 5: 콘솔 관찰

이 자료는 튜토리얼용 축소 예제입니다. 본편 앱의 Tuist 프로젝트를 대체하지 않습니다.
''')
        with ZipFile(RESOURCES / 'ClosedWorld-QuickStart.zip', 'w', ZIP_DEFLATED) as archive:
            archive.write(RESOURCES / 'QuickStart-SceneSupport.swift', 'ClosedWorld-QuickStart/Starter/SceneSupport.swift')
            archive.write(args.model, 'ClosedWorld-QuickStart/Starter/Piggy.usdc')
            for stage, label in [(1, '01-Show'), (2, '02-Position'), (3, '03-Move')]:
                archive.write(RESOURCES / f'QuickStart-0{stage}-ContentView.swift', f'ClosedWorld-QuickStart/Answers/{label}/ContentView.swift')
            archive.writestr('ClosedWorld-QuickStart/README.md', """# 기본 실습

1. Xcode에서 ClosedWorldLab이라는 iOS App을 만듭니다. SwiftUI, Swift, Storage None을 선택합니다.
2. Starter 안의 SceneSupport.swift와 Piggy.usdc 두 파일만 앱에 추가합니다.
3. 기존 ContentView.swift를 튜토리얼의 첫 코드로 교체합니다.
4. 시뮬레이터를 선택하고 실행한 뒤 위치, 탭 이동을 차례로 바꿔 봅니다.

Answers는 막혔을 때 비교하는 전체 코드입니다. 폴더를 통째로 Xcode에 넣지 마세요.
해당 단계의 ContentView.swift 내용만 복사해 기존 파일을 교체합니다.

SceneSupport.swift는 기본 실습에서 수정하지 않습니다. 모델 파일이 빠져도 분홍 상자로 진행할 수 있습니다.
ClosedWorldLabApp.swift는 Xcode가 만든 상태로 둡니다.
""")
    for chapter in selected:
        if chapter in CHAPTER_LABS:
            package_chapter(chapter, args.model)
