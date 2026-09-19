"""Verify runnable checkpoints, actual downloads and all readable chapter pages."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
import json
import subprocess
import sys
import zipfile
import argparse
from package_lab import checkpoints, quick_checkpoints, chapter_checkpoints, CHAPTER_LABS, RESOURCES

parser = argparse.ArgumentParser()
parser.add_argument('public', type=Path)
parser.add_argument('--base-path', default='')
parser.add_argument('--docc-subdirectory', default='')
args = parser.parse_args()
base_path = args.base_path.rstrip('/')
public = args.public
docc = public / args.docc_subdirectory


def typecheck(files, sdk_name='iphonesimulator', swift6=False):
    sdk = subprocess.check_output(['xcrun', '--sdk', sdk_name, '--show-sdk-path'], text=True).strip()
    target = 'arm64-apple-ios17.0' + ('-simulator' if sdk_name == 'iphonesimulator' else '')
    command = ['xcrun', 'swiftc', '-typecheck', '-target', target, '-sdk', sdk,
               '-module-cache-path', '/tmp/techmap-module-cache']
    if swift6:
        # Match the installed Xcode 26 App template's isolation/import defaults,
        # while checking in the stricter Swift 6 language mode.
        command += ['-swift-version', '6', '-default-isolation', 'MainActor',
                    '-enable-upcoming-feature', 'NonisolatedNonsendingByDefault',
                    '-enable-upcoming-feature', 'MemberImportVisibility']
    subprocess.run(command + list(map(str, files.values())), check=True)


for stage, files in checkpoints():
    typecheck(files)
    with zipfile.ZipFile(RESOURCES / 'ClosedWorld-Lab.zip') as archive:
        for name, path in files.items():
            assert archive.read(f'ClosedWorld-Lab/Checkpoints/{stage}/{name}') == path.read_bytes(), f'Stale download: {stage}/{name}'
    print(f'Chapter 1 detailed checkpoint {stage}: PASS', flush=True)
for stage, files in quick_checkpoints():
    typecheck(files, swift6=True)
    label = {1: '01-Show', 2: '02-Position', 3: '03-Move'}[stage]
    with zipfile.ZipFile(RESOURCES / 'ClosedWorld-QuickStart.zip') as archive:
        assert archive.read('ClosedWorld-QuickStart/Starter/SceneSupport.swift') == files['SceneSupport.swift'].read_bytes()
        assert archive.read(f'ClosedWorld-QuickStart/Answers/{label}/ContentView.swift') == files['ContentView.swift'].read_bytes()
        model_bytes = archive.read('ClosedWorld-QuickStart/Starter/Piggy.usdc')
    print(f'Chapter 1 quick checkpoint {stage}: PASS', flush=True)
for chapter, (name, _, _) in CHAPTER_LABS.items():
    for stage, files in chapter_checkpoints(chapter):
        for sdk_name in ['iphonesimulator', 'iphoneos']:
            typecheck(files, sdk_name, swift6=True)
        with zipfile.ZipFile(RESOURCES / f'{name}.zip') as archive:
            for filename, path in files.items():
                folder = f'Answers/{stage}' if filename == 'ContentView.swift' else 'Starter'
                assert archive.read(f'{name}/{folder}/{filename}') == path.read_bytes(), f'Stale Chapter {chapter} download: {filename}'
            assert archive.read(f'{name}/Starter/Piggy.usdc') == model_bytes, f'Chapter {chapter}: model differs'
        print(f'Chapter {chapter} checkpoint {stage}: Swift 6 simulator + device SDK, ZIP PASS', flush=True)

subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-module-cache-path', '/tmp/techmap-module-cache',
                str(RESOURCES/'PatrolMotion.swift'), str(Path(__file__).parent/'tests/PatrolMotionTests.swift'),
                '-o', '/tmp/techmap-patrol-tests'], check=True)
subprocess.run(['/tmp/techmap-patrol-tests'], check=True)


class Reader(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.codes = [], [], {}
        self.active_code = None
        self.prose = ''
        self.copy_ids = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs: self.ids.append(attrs['id'])
        if 'data-copy' in attrs: self.copy_ids.append(attrs['data-copy'])
        if tag in ('a', 'link', 'img', 'script'):
            self.links.append(attrs.get('href', attrs.get('src', '')))
        if tag == 'code' and attrs.get('id', '').startswith('code-'):
            self.active_code = attrs['id']
            self.codes[self.active_code] = ''
    def handle_endtag(self, tag):
        if tag == 'code': self.active_code = None
    def handle_data(self, text):
        if self.active_code: self.codes[self.active_code] += text
        else: self.prose += text


archives = ['ClosedWorld-QuickStart', 'ClosedWorld-Lab'] + [entry[0] for entry in CHAPTER_LABS.values()]
for name in archives:
    assert (docc/'downloads/com.techmap.scenekittorealitykit'/f'{name}.zip').read_bytes() == (RESOURCES/f'{name}.zip').read_bytes(), f'Stale site download: {name}'
for chapter, slug in enumerate(['01-closedworld','02-openingthedoor','03-realhideandseek','04-comparison'], 1):
    page = public / ('' if chapter == 1 else f'chapters/{chapter}') / 'index.html'
    reader = Reader()
    reader.feed(page.read_text())
    assert len(reader.ids) == len(set(reader.ids)), f'Chapter {chapter}: duplicate anchor'
    assert '**' not in reader.prose, f'Chapter {chapter}: unparsed Markdown emphasis'
    for link in reader.links:
        parsed = urlsplit(link)
        if parsed.scheme: continue
        if parsed.path:
            local_path = parsed.path
            if local_path.startswith('/'):
                assert local_path.startswith(base_path + '/'), f'Chapter {chapter}: URL escapes hosting path: {link}'
                local_path = local_path[len(base_path):]
            target = public / unquote(local_path.lstrip('/')) if local_path.startswith('/') else page.parent / unquote(local_path)
            assert target.is_file() or (target / 'index.html').is_file(), f'Chapter {chapter}: missing local asset {link}'
        elif parsed.fragment:
            assert unquote(parsed.fragment) in reader.ids, f'Chapter {chapter}: missing anchor {link}'
    render = json.loads(next((docc/'data/tutorials').rglob(f'{slug}.json')).read_text())
    steps = [step for section in render['sections'] if section['kind'] == 'tasks' for task in section['tasks'] for step in task['stepsSection']]
    expected_count = 0
    for i, step in enumerate(steps, 1):
        if step.get('code'):
            expected_count += 1
            expected = '\n'.join(render['references'][step['code']]['content']) + '\n'
            assert reader.codes[f'code-{i}'] == expected, f'Chapter {chapter}: code copy mismatch in step {i}'
            editable = '읽기 전용' not in render['references'][step['code']]['fileName']
            assert (f'code-{i}' in reader.copy_ids) == editable, f'Chapter {chapter}: wrong copy control in step {i}'
    assert len(reader.codes) == expected_count
    assert len(reader.copy_ids) == len(set(reader.copy_ids))
    assert set(reader.copy_ids) <= reader.codes.keys()
    for route in ['/', '/chapters/2/', '/chapters/3/', '/chapters/4/']:
        assert base_path + route in reader.links, f'Chapter {chapter}: missing navigation to {route}'
    print(f'Chapter {chapter} reader: {len(reader.codes)} exact code blocks, links and downloads PASS', flush=True)
