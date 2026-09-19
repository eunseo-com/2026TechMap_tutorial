"""Connect previously shared Pages URLs to the current guided lessons."""
import html
import json
from pathlib import Path
import sys
import shutil

public = Path(sys.argv[1])
base = '/2026TechMap_tutorial'
tools = Path(__file__).parent
shutil.copy2(tools / 'legacy-navigation.js', public / 'legacy-navigation.js')
shutil.copy2(tools / 'docc-guide.css', public / 'guide/docc-guide.css')
for page in (public / 'documentation').rglob('*.html'):
    source = page.read_text()
    if 'legacy-navigation.js' not in source:
        source = source.replace('</body>', f'<script defer src="{base}/legacy-navigation.js"></script></body>')
    page.write_text(source)
legacy = 'tutorials/scenekittorealitykit'
destinations = {
    legacy: '/',
    f'{legacy}/01-closedworld': '/',
    f'{legacy}/02-openingthedoor': '/chapters/2/',
    f'{legacy}/03-realhideandseek': '/chapters/3/',
    f'{legacy}/04-comparison': '/chapters/4/',
    'guide': '/guide/tutorials/scenekittorealitykit/',
}
for route, target in destinations.items():
    url = base + target
    page = public / route / 'index.html'
    page.parent.mkdir(parents=True, exist_ok=True)
    page.write_text(f'''<!doctype html>
<html lang="ko-KR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>튜토리얼로 이동</title><link rel="canonical" href="{html.escape(url)}">
<meta http-equiv="refresh" content="0; url={html.escape(url)}">
</head><body><main><p><a href="{html.escape(url)}">튜토리얼 계속 읽기</a></p></main>
<script>location.replace({json.dumps(url)});</script></body></html>''')

# Apply the existing DocC accessibility fixes to the separate guide archive too.
for page in (public / 'guide').rglob('*.html'):
    source = page.read_text().replace('<html lang="en-US"', '<html lang="ko-KR"')
    if 'docc-guide.css' not in source:
        source = source.replace('</head>', f'<link rel="stylesheet" href="{base}/guide/docc-guide.css"></head>')
    if 'docc-accessibility-fixes.js' not in source:
        source = source.replace('</body>', f'<script defer src="{base}/js/docc-accessibility-fixes.js"></script></body>')
    page.write_text(source)
for script in (public / 'guide/js').glob('index.*.js'):
    source = script.read_text().replace('VUE_APP_DEFAULT_LOCALE??"en-US"', 'VUE_APP_DEFAULT_LOCALE??"ko-KR"')
    source = source.replace('minute | minutes | {count} minutes', 'minutes').replace('분 | 분 | {count}분', '분')
    source = source.replace('"current":"현재 {thing}"', '"current":"현재 섹션"')
    script.write_text(source)
for data in (public / 'guide/data/tutorials').rglob('*.json'):
    source = data.read_text().replace('"Get started"', '"시작하기"').replace('"View more"', '"더 보기"')
    data.write_text(source)
(public / 'guide/theme-settings.json').write_text('{}\n')
