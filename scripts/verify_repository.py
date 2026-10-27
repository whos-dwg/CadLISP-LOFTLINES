"""Check the imported source snapshot and local documentation; never run AutoCAD."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def source_structure(text: str) -> tuple[list[dict], dict]:
    masked = []
    in_string = in_comment = escaped = False
    for char in text:
        if in_comment:
            if char == '\n':
                in_comment = False
            masked.append('\n' if char == '\n' else ' ')
        elif in_string:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                in_string = False
            masked.append('\n' if char == '\n' else ' ')
        elif char == ';':
            in_comment = True
            masked.append(' ')
        elif char == '"':
            in_string = True
            masked.append(' ')
        else:
            masked.append(char)
    code = ''.join(masked)
    commands = [
        {'name': m.group(1).upper(), 'line': code.count('\n', 0, m.start()) + 1}
        for m in re.finditer(r'\(defun\s+c:([^\s()]+)', code, re.I)
    ]
    depth = minimum = 0
    for char in code:
        depth += (char == '(') - (char == ')')
        minimum = min(depth, minimum)
    return commands, {
        'parenthesis_balance': depth,
        'minimum_depth': minimum,
        'unterminated_string': in_string,
    }


def heading_ids(text: str) -> set[str]:
    found = set()
    counts: dict[str, int] = {}
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith('```'):
            in_fence = not in_fence
        if in_fence or not re.match(r'^#{1,6}\s', line):
            continue
        heading = re.sub(r'^#{1,6}\s+', '', line).strip().lower()
        heading = re.sub(r'<[^>]*>', '', heading).replace('`', '')
        heading = re.sub(r'[^\w\-\s\u3400-\u9fff]', '', heading)
        heading = heading.replace(' ', '-')
        count = counts.get(heading, 0)
        counts[heading] = count + 1
        found.add(heading + (f'-{count}' if count else ''))
    return found


def main() -> int:
    errors = []
    manifest = json.loads((ROOT / 'metadata/source-manifest.json').read_text('utf-8'))
    catalog = json.loads((ROOT / 'metadata/commands.json').read_text('utf-8'))
    media = json.loads((ROOT / 'metadata/media-manifest.json').read_text('utf-8'))
    actual_paths = {
        p.relative_to(ROOT).as_posix()
        for p in (ROOT / 'lsp').iterdir()
        if p.is_file() and p.suffix.lower() == '.lsp'
    }
    expected_paths = {r['path'] for r in manifest['files']}
    if actual_paths != expected_paths:
        errors.append('LISP file set differs from the source manifest')
    public_commands = []
    syntax = []
    for rec in manifest['files']:
        path = ROOT / rec['path']
        if not path.is_file():
            errors.append(f"Missing source: {rec['path']}")
            continue
        data = path.read_bytes()
        if len(data) != rec['bytes'] or hashlib.sha256(data).hexdigest() != rec['sha256']:
            errors.append(f"Source bytes differ: {rec['path']}")
        try:
            text = data.decode('utf-8-sig')
        except UnicodeDecodeError:
            errors.append(f"Invalid UTF-8: {rec['path']}")
            continue
        commands, structure = source_structure(text)
        if commands != rec['commands']:
            errors.append(f"Command definitions differ: {rec['path']}")
        if structure['parenthesis_balance'] or structure['minimum_depth'] or structure['unterminated_string']:
            errors.append(f"Unbalanced source structure: {rec['path']}")
        public_commands.extend(c['name'] for c in commands)
        syntax.append({'path': rec['path'], **structure})
    if len(set(public_commands)) != len(public_commands):
        errors.append('Duplicate public command definitions in primary files')
    expected_catalog = {r['path']: [c['name'] for c in r['commands']] for r in manifest['files']}
    if {t['file']: t['commands'] for t in catalog} != expected_catalog:
        errors.append('Command catalog differs from source definitions')
    for entry in catalog:
        if not (ROOT / entry['manual']).is_file():
            errors.append(f"Missing manual: {entry['manual']}")
    for rec in media:
        path = ROOT / rec['path']
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != rec['sha256']:
            errors.append(f"Demo bytes differ: {rec['path']}")
    local_links = 0
    # This repository uses inline Markdown links with URL-encoded parentheses.
    for path in ROOT.rglob('*.md'):
        text = path.read_text('utf-8')
        without_code = re.sub(r'```.*?```', '', text, flags=re.S)
        for match in re.finditer(r'!?\[[^\]\n]*\]\(([^\s]+?)(?:\s+"[^"\n]*")?\)', without_code):
            url = match.group(1).strip('<>')
            parsed = urlsplit(url)
            if parsed.scheme or url.startswith('//'):
                continue
            local_links += 1
            target = (path.parent / unquote(parsed.path)).resolve() if parsed.path else path
            try:
                target.relative_to(ROOT)
            except ValueError:
                errors.append(f'Link leaves repository: {url}')
                continue
            if not target.exists():
                errors.append(f'Broken link in {path.relative_to(ROOT)}: {url}')
            elif parsed.fragment and target.suffix == '.md':
                if unquote(parsed.fragment) not in heading_ids(target.read_text('utf-8')):
                    errors.append(f'Broken heading in {path.relative_to(ROOT)}: {url}')
    report = {
        'snapshot_date': manifest['snapshot_date'],
        'status': 'passed' if not errors else 'failed',
        'scope': 'Static source and documentation checks only',
        'lisp_files': len(expected_paths),
        'public_commands': len(public_commands),
        'manuals': len(catalog),
        'demo_gifs': len(media),
        'local_links_checked': local_links,
        'source_hashes_match': not any('bytes differ' in e for e in errors),
        'autocad_runtime_tests': 'not performed',
        'known_source_issues': 'See docs/KNOWN_ISSUES.md; static success does not resolve those issues',
        'structure': syntax,
        'errors': errors,
    }
    (ROOT / 'metadata/validation-report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8'
    )
    print(json.dumps({k: v for k, v in report.items() if k != 'structure'}, ensure_ascii=True, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
