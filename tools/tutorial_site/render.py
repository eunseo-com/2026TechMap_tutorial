"""Build a readable, progressively enhanced page from DocC's render JSON.

Usage: python3 tools/tutorial_site/render.py ARCHIVE PUBLIC_DIRECTORY
DocC remains the single content source. No Markdown is duplicated here.
"""
import argparse
import difflib
import html
import json
import re
import shutil
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('archive', type=Path)
parser.add_argument('public', type=Path)
parser.add_argument('--base-path', default='', help='Project path, such as /2026TechMap_tutorial')
parser.add_argument('--docc-subdirectory', default='', help='Keep the guide archive apart from existing reference documentation')
args = parser.parse_args()
base_path = args.base_path.rstrip('/')
docc_subdirectory = args.docc_subdirectory.strip('/')
if base_path and (not base_path.startswith('/') or '..' in base_path.split('/')):
    parser.error('--base-path must be an absolute URL path without parent traversal')
if docc_subdirectory and (len(Path(docc_subdirectory).parts) != 1 or docc_subdirectory in ('.', '..')):
    parser.error('--docc-subdirectory must be one directory name')
esc = html.escape
CHAPTERS = (
    (1, '01-closedworld.json', '/', '갇힌 세계', 'SCENEKIT · 따라 하며 배우기', '시뮬레이터'),
    (2, '02-openingthedoor.json', '/chapters/2/', '문 열기', 'REALITYKIT · 현실의 바닥 읽기', 'AR 지원 실기기'),
    (3, '03-realhideandseek.json', '/chapters/3/', '현실 숨바꼭질', 'REALITYKIT · 메시 가려짐', 'LiDAR 지원 실기기'),
    (4, '04-comparison.json', '/chapters/4/', '두 세계 비교', 'SCENEKIT × REALITYKIT · ECS', '시뮬레이터'),
)
ROUTES = {name.removesuffix('.json'): route for _, name, route, *_ in CHAPTERS}
refs = {}


def docc_url(url):
    return ('/' + docc_subdirectory + url) if docc_subdirectory and url.startswith('/') else url


def inline(items):
    result = []
    for item in items:
        kind = item['type']
        if kind == 'text': result.append(esc(item['text']))
        elif kind == 'codeVoice': result.append('<code>' + esc(item['code']) + '</code>')
        elif kind in ('strong', 'emphasis'):
            tag = 'strong' if kind == 'strong' else 'em'
            result.append(f'<{tag}>' + inline(item['inlineContent']) + f'</{tag}>')
        elif kind == 'reference':
            ref = refs.get(item['identifier'], {})
            url = ref.get('url', '#')
            slug = url.split('#', 1)[0].rstrip('/').rsplit('/', 1)[-1]
            if slug in ROUTES: url = ROUTES[slug] + (('#' + url.split('#', 1)[1]) if '#' in url else '')
            else: url = docc_url(url)
            result.append(f'<a href="{esc(url, quote=True)}">' + inline(item.get('overridingTitleInlineContent', [{'type': 'text', 'text': ref.get('title', item['identifier'])}])) + '</a>')
        else: raise ValueError(f'Unsupported inline content: {kind}')
    return ''.join(result)


def paragraphs(blocks, instruction=False):
    result = []
    for block in blocks:
        if block['type'] != 'paragraph': raise ValueError(f'Unsupported block: {block["type"]}')
        # DocC can merge separate caption lines into one paragraph. Only known
        # caption labels begin a new callout; ordinary bold text stays inline.
        groups = []
        for item in block['inlineContent']:
            label = ''.join(part.get('text', '') for part in item.get('inlineContent', [])) if item['type'] == 'strong' else ''
            is_caption_label = label.startswith(('실행 확인', '완료 확인', '확인', '막혔나요', '실행 대상', '검증 범위', '더 알고 싶다면'))
            if not groups or (item['type'] == 'strong' and is_caption_label): groups.append([])
            groups[-1].append(item)
        for group in groups:
            leading_strong = group[0]['type'] == 'strong'
            leading_text = ''.join(part.get('text', '') for part in group[0].get('inlineContent', [])) if leading_strong else ''
            labeled = leading_strong and (instruction or leading_text.startswith(('실행 확인', '완료 확인', '확인', '막혔나요', '실행 대상', '검증 범위', '더 알고 싶다면')))
            label = inline(group[:1]) if labeled else ''
            content = inline(group[1:] if label else group).strip()
            plain = re.sub('<[^>]+>', '', label)
            if label and instruction:
                result.append(f'<h3>{label}</h3><p>{content}</p>')
            elif label:
                tone = 'check' if plain.startswith(('실행 확인', '확인', '완료 확인')) else 'help' if plain.startswith('막혔나요') else 'note'
                if tone == 'help':
                    result.append(f'<details class="help-disclosure"><summary>잘 안 되면 확인하세요</summary><div><p>{content}</p></div></details>')
                else:
                    result.append(f'<div class="callout {tone}"><p class="callout-label">{label}</p><p>{content}</p></div>')
            else: result.append(f'<p>{content}</p>')
    return ''.join(result)


def content_blocks(blocks, instruction=False):
    rendered = []
    for block in blocks:
        if block['type'] == 'paragraph':
            rendered.append(paragraphs([block], instruction=instruction))
        elif block['type'] == 'table':
            if block.get('header') != 'row':
                raise ValueError(f'Unsupported table header: {block.get("header")}')
            rows = block['rows']
            if not rows: continue
            width = len(rows[0])
            if any(len(row) != width for row in rows):
                raise ValueError('Table rows have different column counts')

            def cell_content(cell):
                if any(part['type'] != 'paragraph' for part in cell):
                    raise ValueError('Unsupported table cell content')
                return ''.join(f'<p>{inline(part["inlineContent"])}</p>' for part in cell)

            header = ''.join(f'<th scope="col">{cell_content(cell)}</th>' for cell in rows[0])
            body = ''.join('<tr>' + ''.join(
                f'<th scope="row">{cell_content(cell)}</th>' if index == 0 else f'<td>{cell_content(cell)}</td>'
                for index, cell in enumerate(row)) + '</tr>' for row in rows[1:])
            rendered.append(f'<div class="table-scroll columns-{width}" role="region" aria-label="{width}열 표" tabindex="0"><table><thead><tr>{header}</tr></thead><tbody>{body}</tbody></table></div>')
            if width > 2:
                rendered.append('<p class="table-hint">표가 잘리면 좌우로 밀어 보세요.</p>')
        else:
            raise ValueError(f'Unsupported block: {block["type"]}')
    return ''.join(rendered)


def highlighted(code):
    pattern = r'//[^\n]*|"(?:\\.|[^"\\])*"|\b(?:import|struct|class|final|enum|let|var|func|static|private|return|guard|else|if|for|in|nil|true|false|init|some)\b|@[A-Za-z]+'
    parts, last = [], 0
    for match in re.finditer(pattern, code):
        parts.append(esc(code[last:match.start()]))
        token = match.group()
        kind = 'comment' if token.startswith('//') else 'string' if token.startswith('"') else 'keyword'
        parts.append(f'<span class="syntax-{kind}">{esc(token)}</span>')
        last = match.end()
    parts.append(esc(code[last:]))
    return ''.join(parts)


previous_codes = {}

def codeblock(identifier, index):
    ref = refs[identifier]
    lines = len(ref['content'])
    opened = ' open' if lines <= 35 else ''
    changed = set()
    previous = previous_codes.get(ref['fileName'])
    if previous is not None:
        matcher = difflib.SequenceMatcher(a=previous, b=ref['content'])
        for kind, _, _, start, end in matcher.get_opcodes():
            if kind in ('replace', 'insert'): changed.update(range(start, end))
    previous_codes[ref['fileName']] = ref['content']
    rendered_code = ''.join(f'<span class="code-line{chr(32) + "changed-line" if i in changed else ""}">{highlighted(line)}</span>\n' for i, line in enumerate(ref['content']))
    change_note = '<p class="code-change-note">파란 배경은 이전 단계에서 바뀐 줄입니다.</p>' if changed else ''
    copy_button = '' if '읽기 전용' in ref['fileName'] else f'<button type="button" class="copy-button" data-copy="code-{index}" aria-label="{esc(ref["fileName"])} 전체 코드 복사">전체 복사</button>'
    return f'''<div class="code-block">
    <div class="code-toolbar"><span>{esc(ref['fileName'])}</span>{copy_button}</div>
    <details{opened}><summary>전체 코드 <span>{lines}줄 · Swift</span></summary><pre tabindex="0" aria-label="{esc(ref['fileName'])} 코드"><code id="code-{index}">{rendered_code}</code></pre></details>{change_note}
    </div>'''


def media(identifier):
    ref = refs[identifier]
    url = esc(docc_url(ref['variants'][0]['url']), quote=True)
    caption = esc(ref.get('alt', ''))
    return f'<figure><a href="{url}" target="_blank" rel="noopener" aria-label="실행 화면 크게 보기: {caption}"><img src="{url}" alt="{caption}" loading="lazy" ></a><figcaption>{caption}<a class="image-link" href="{url}" target="_blank" rel="noopener">실행 화면 크게 보기 ↗</a></figcaption></figure>'

def render_page(chapter, source):
    global refs, previous_codes
    number, _, route, label, eyebrow, device = chapter
    data = json.loads(source.read_text())
    refs = data['references']
    previous_codes = {}
    hero = next(section for section in data['sections'] if section['kind'] == 'hero')
    tasks = next(section['tasks'] for section in data['sections'] if section['kind'] == 'tasks')
    nav, sections = [], []
    step_count = 0
    for i, task in enumerate(tasks):
        anchor = task['anchor']
        title = task['title']
        short = title.split(' · ', 1)[-1] if ' · ' in title else re.sub(r'^\d+\. ', '', title)
        phase = re.match(r'^(\d+)\.', title)
        section_label = f'실습 {phase[1]}' if phase else title.split(' · ', 1)[0]
        nav_index = f'{int(phase[1]):02}' if phase else ('읽기' if title.startswith('선택') else title.split(' · ', 1)[0])
        nav.append(f'<li><a href="#{esc(anchor)}"><span class="nav-index">{esc(nav_index)}</span><span>{esc(short)}</span></a></li>')
        contents = []
        for block in task['contentSection']:
            contents.append(content_blocks(block.get('content', [])))
            if block.get('media'): contents.append(media(block['media']))
        steps = []
        for j, step in enumerate(task['stepsSection'], 1):
            step_count += 1
            steps.append(f'<article class="step" id="step-{step_count}"><div class="step-number" aria-label="{step_count}번째 단계">{step_count:02}</div><div class="step-body">{paragraphs(step["content"], instruction=True)}')
            if step.get('code'): steps.append(codeblock(step['code'], step_count))
            steps.append(paragraphs(step.get('caption', [])))
            steps.append('</div></article>')
        next_link = f'<a class="next-section" href="#{esc(tasks[i+1]["anchor"])}">다음: {esc(tasks[i+1]["title"])} <span aria-hidden="true">→</span></a>' if i+1 < len(tasks) else '<a class="next-section" href="#top">처음으로 돌아가기 ↑</a>'
        sections.append(f'<section class="chapter-section" id="{esc(anchor)}" aria-labelledby="heading-{i}"><header class="section-heading"><p class="eyebrow">{esc(section_label)}</p><h2 id="heading-{i}">{esc(short)}</h2></header><div class="section-intro">{"".join(contents)}</div>{"".join(steps)}{next_link}</section>')

    download = docc_url(refs[hero['projectFiles']]['url'])
    chapter_links = []
    for n, _, path, name, *_ in CHAPTERS:
        current = ' aria-current="page"' if n == number else ''
        chapter_links.append(f'<a href="{path}"{current}>0{n} <span>{esc(name)}</span></a>')
    previous = f'<a href="{CHAPTERS[number-2][2]}">← 이전 장 · {esc(CHAPTERS[number-2][3])}</a>' if number > 1 else ''
    following = f'<a href="{CHAPTERS[number][2]}">다음 장 · {esc(CHAPTERS[number][3])} →</a>' if number < len(CHAPTERS) else ''
    description = ''.join(item.get('text', '') for item in hero['content'][0].get('inlineContent', []))
    phases = [re.sub(r'^\d+\.\s*', '', task['title']) for task in tasks if re.match(r'^\d+\.', task['title'])]
    learning_path = '<ol class="learning-path" aria-label="만들어 볼 순서">' + ''.join(f'<li><span>{i:02}</span>{esc(phase)}</li>' for i, phase in enumerate(phases, 1)) + '</ol>' if phases else ''
    facts = f'<dl class="lesson-facts"><div><dt>실행할 곳</dt><dd>{esc(device)}</dd></div><div><dt>고칠 파일</dt><dd>ContentView.swift 하나</dd></div></dl>'
    page = f'''<!doctype html>
<html lang="ko-KR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(hero['title'])} — 씬킷에서 리얼리티킷으로</title>
<meta name="description" content="{esc(description, quote=True)}">
<link rel="icon" href="{docc_url('/favicon.svg')}"><link rel="stylesheet" href="/reader.css"><script defer src="/reader.js"></script></head>
<body id="top" class="chapter-{number}"><a class="skip-link" href="#lesson">본문으로 건너뛰기</a>
<header class="site-header"><a class="brand" href="/">씬킷에서 리얼리티킷으로<span>돼지와 함께 만드는 첫 공간 앱</span></a><a class="docc-link" href="{docc_url('/tutorials/scenekittorealitykit/')}">DocC 원문 <span aria-hidden="true">↗</span></a></header>
<nav class="chapter-nav" aria-label="전체 장">{''.join(chapter_links)}</nav>
<div class="layout"><aside class="sidebar"><details class="toc-disclosure" open><summary>이 장의 순서 보기</summary><nav aria-label="이번 장 목차"><p class="nav-title">CHAPTER 0{number} <span>{esc(label)}</span></p><ol>{''.join(nav)}</ol></nav></details></aside>
<main id="lesson"><header class="lesson-header"><p class="eyebrow">{number}장 · {esc(label)}</p><h1>{esc(hero['title'])}</h1>{paragraphs(hero['content'])}{facts}<div class="lesson-actions"><a class="primary-link" href="#{esc(tasks[0]['anchor'])}">처음부터 따라 하기 <span aria-hidden="true">↓</span></a><a class="download-link" href="{esc(download, quote=True)}" download>실습 자료 내려받기 <span aria-hidden="true">↙</span></a></div><p class="download-note">준비 파일과 단계별 정답이 함께 들어 있습니다.</p>{learning_path}</header>
{''.join(sections)}<nav class="chapter-pagination" aria-label="장 이동">{previous}{following}</nav><footer class="lesson-footer">씬킷에서 리얼리티킷으로 · Chapter {number}</footer></main></div><div id="copy-status" role="status" aria-live="polite"></div></body></html>'''
    # Only URL attributes are prefixed; code examples and copied Swift stay exact.
    page = re.sub(r'((?:href|src)=")/(?!/)', lambda match: match[1] + base_path + '/', page)
    destination = args.public / route.lstrip('/') / 'index.html'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(page)
    print(f'Chapter {number}: {len(tasks)} sections, {step_count} steps')


shutil.copytree(args.archive, args.public / docc_subdirectory, dirs_exist_ok=True)
for chapter in CHAPTERS:
    source = next((args.archive / 'data/tutorials').rglob(chapter[1]), None)
    if source is None: raise FileNotFoundError(f'Missing DocC tutorial render JSON: {chapter[1]}')
    render_page(chapter, source)
for name in ['reader.css', 'reader.js']:
    shutil.copy2(Path(__file__).with_name(name), args.public/name)
