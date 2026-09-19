"""Build an isolated Xcode rehearsal from a chapter's actual download.

Usage: python3 tools/tutorial_site/prepare_rehearsal.py /tmp/lesson --chapter 4 --stage 3
Then run tuist generate --no-open in that directory. Generated projects stay untracked.
"""
from pathlib import Path
from zipfile import ZipFile
import argparse
from package_lab import RESOURCES, CHAPTER_LABS

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('--chapter', type=int, choices=[1, 2, 3, 4], default=1)
parser.add_argument('--stage', type=int, choices=[1, 2, 3], default=1)
args = parser.parse_args()
root = args.root
root.mkdir(parents=True, exist_ok=True)
marker = root / '.chapter'
if marker.exists() and marker.read_text() != str(args.chapter):
    raise SystemExit('Use a separate directory for each chapter; keep source sets isolated.')
marker.write_text(str(args.chapter))
for name in ['Tuist', 'Sources', 'Resources', 'Answers']:
    (root/name).mkdir(exist_ok=True)
archive_name = 'ClosedWorld-QuickStart' if args.chapter == 1 else CHAPTER_LABS[args.chapter][0]
with ZipFile(RESOURCES / f'{archive_name}.zip') as archive:
    base = archive_name + '/'
    for name in archive.namelist():
        if name.startswith(base+'Starter/'):
            target = root / ('Sources' if name.endswith('.swift') else 'Resources') / Path(name).name
            target.write_bytes(archive.read(name))
    for i in range(1, 4):
        label = {1:'01-Show',2:'02-Position',3:'03-Move'}[i] if args.chapter == 1 else str(i)
        (root/f'Answers/{i}.swift').write_bytes(archive.read(base+f'Answers/{label}/ContentView.swift'))
(root/'Sources/ContentView.swift').write_bytes((root/f'Answers/{args.stage}.swift').read_bytes())
app = {1:'ClosedWorldLab',2:'OpeningTheDoorLab',3:'RealHideAndSeekLab',4:'ComparisonLab'}[args.chapter]
app_filename = 'ClosedWorldLabApp.swift' if args.chapter == 1 else 'LessonApp.swift'
(root/'Sources'/app_filename).write_text(f'''import SwiftUI
@main
struct {app}App: App {{
    var body: some Scene {{
        WindowGroup {{ ContentView() }}
    }}
}}
''')
camera = ', "NSCameraUsageDescription": "실제 공간의 수평면에 돼지를 놓기 위해 카메라를 사용합니다."' if args.chapter in (2, 3) else ''
(root/'Project.swift').write_text(f'''import ProjectDescription
let project = Project(
    name: "{app}",
    targets: [
        .target(
            name: "{app}",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.techmap.chapter{args.chapter}.rehearsal",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]{camera}]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
                "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
                "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
                "TARGETED_DEVICE_FAMILY": "1,2"
            ])
        )
    ]
)
''')
print(root)
