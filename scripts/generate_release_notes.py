"""
Generate a business-friendly release notes PDF from CHANGELOG.md.

Reads the "Unreleased" section of CHANGELOG.md (written in plain language),
formats it as a polished A4 PDF with cover page, feature sections, and
testing instructions. Designed for non-technical readers.

Usage:
    python3 scripts/generate_release_notes.py          # use CHANGELOG.md
    python3 scripts/generate_release_notes.py --draft  # mark as DRAFT
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHANGELOG_PATH = PROJECT_ROOT / 'CHANGELOG.md'


# ── Parse CHANGELOG.md ───────────────────────────────────────────────────────

class Section:
    """A feature section with heading, description, and test steps."""
    def __init__(self, heading: str, content: str):
        self.heading = heading
        self.description = ''
        self.test_steps: list[str] = []
        self._parse(content)

    def _parse(self, content: str):
        parts = content.split('**How to test:**', 1)
        self.description = parts[0].strip()
        if len(parts) > 1:
            raw_steps = parts[1].strip()
            for line in raw_steps.split('\n'):
                line = line.strip()
                if line.startswith('- ') or line.startswith('1.'):
                    step = line.lstrip('- 1234567890. ')
                    if step:
                        self.test_steps.append(step)


def read_changelog() -> tuple[str, list[Section], str | None]:
    """
    Parse CHANGELOG.md and return:
      - title / version label
      - list of Section objects from "Unreleased" (or latest version)
      - optional previous-release notes (everything after the latest section)
    """
    if not CHANGELOG_PATH.exists():
        print(f'⚠️  {CHANGELOG_PATH} not found. Creating a template.')
        sys.exit(1)

    text = CHANGELOG_PATH.read_text(encoding='utf-8')

    # Find the first h2 section (either "Unreleased" or a version tag)
    lines = text.split('\n')
    sections: list[Section] = []
    prev_notes: list[str] = []
    current_heading = ''
    current_content = ''
    in_latest = False
    passed_latest = False
    title = 'Release Notes'

    for line in lines:
        if line.startswith('# '):
            title = line[2:].strip()
        elif line.startswith('## '):
            heading = line[3:].strip()
            # If we already captured a section, save it
            if in_latest and current_heading:
                sections.append(Section(current_heading, current_content))
                current_content = ''

            # Start of unreleased or first version
            if heading.lower() in ('unreleased',) or re.match(r'^v?\d+\.\d+', heading):
                if not in_latest:
                    in_latest = True
                    current_heading = heading
                else:
                    # We found another version after unreleased — stop
                    passed_latest = True
                    prev_notes.append(line)
            else:
                if in_latest and not passed_latest:
                    current_heading = heading
                else:
                    passed_latest = True
                    prev_notes.append(line)

        elif line.startswith('### '):
            # Feature sections use ### level headings
            heading = line[4:].strip()
            if in_latest and not passed_latest:
                # Save previous section if exists
                if current_heading and current_content.strip():
                    sections.append(Section(current_heading, current_content))
                current_heading = heading
                current_content = ''
            elif passed_latest:
                prev_notes.append(line)

        elif in_latest and not passed_latest:
            current_content += line + '\n'
        elif passed_latest:
            prev_notes.append(line)

    # Save last section
    if in_latest and current_heading:
        sections.append(Section(current_heading, current_content))

    # Collect previous release notes (everything after unreleased sections)
    prev = '\n'.join(prev_notes).strip() if prev_notes else None

    return title, sections, prev


# ── HTML / PDF generation ────────────────────────────────────────────────────

def escape_html(text: str) -> str:
    """Escape HTML special characters."""
    return (text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&#39;'))


def build_html(title: str, sections: list[Section], prev_notes: str | None, is_draft: bool) -> str:
    """Build a beautiful HTML document for PDF output."""
    today = datetime.now().strftime('%B %d, %Y')

    parts = [
        '<!DOCTYPE html><html><head><meta charset="utf-8">',
        '<style>',
        '  @page {',
        '    size: A4;',
        '    margin: 2.2cm 2.5cm;',
        '    @bottom-right {',
        '      content: counter(page) " / " counter(pages);',
        '      font-size: 9px; color: #999; font-family: "Segoe UI", sans-serif;',
        '    }',
        '    @top-right {',
        '      content: "' + escape_html(today) + '";',
        '      font-size: 8px; color: #bbb; font-family: "Segoe UI", sans-serif;',
        '    }',
        '  }',
        '  @page:first { @top-right { content: none; } }',
        '  * { box-sizing: border-box; }',
        '  body {',
        '    font-family: "Segoe UI", "DejaVu Sans", Arial, sans-serif;',
        '    font-size: 11px; line-height: 1.65; color: #1a1a2e;',
        '  }',

        # ── Cover page ──
        '  .cover { page-break-after: always; text-align: center; padding-top: 6cm; }',
        '  .cover .tag {',
        '    display: inline-block; background: #009B9E; color: white;',
        '    padding: 6px 18px; border-radius: 20px; font-size: 11px;',
        '    font-weight: 700; letter-spacing: 1px; text-transform: uppercase;',
        '    margin-bottom: 20px;',
        '  }',
        '  .cover h1 { font-size: 32px; color: #0a1628; margin: 10px 0 6px; }',
        '  .cover .subtitle { font-size: 14px; color: #555; margin-bottom: 30px; }',
        '  .cover .meta { font-size: 11px; color: #888; }',
        '  .cover .line { width: 60px; height: 3px; background: #009B9E; margin: 20px auto; border: none; }',
        '  .cover .navy-block {',
        '    background: linear-gradient(135deg, #0a1628, #1a2a4a);',
        '    color: white; padding: 24px 40px; border-radius: 12px;',
        '    margin: 30px auto 0; max-width: 350px; text-align: left;',
        '  }',
        '  .cover .navy-block p { margin: 4px 0; font-size: 12px; opacity: 0.85; }',
        '  .cover .navy-block strong { color: #00BFA6; opacity: 1; }',

        # ── Draft watermark ──
        ('  .draft-badge { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-30deg); '
         'font-size: 80px; color: rgba(220, 38, 38, 0.08); font-weight: 900; '
         'letter-spacing: 12px; pointer-events: none; z-index: 0; }' if is_draft else ''),

        # ── Section styling ──
        '  .section { margin: 24px 0; }',
        '  .section h2 {',
        '    font-size: 18px; color: #0a1628; margin: 0 0 8px;',
        '    padding-bottom: 6px; border-bottom: 2px solid #e5e7eb;',
        '  }',
        '  .section h2 .accent { color: #009B9E; }',
        '  .section .desc { color: #374151; margin: 0 0 10px; }',
        '  .section .test-header {',
        '    font-size: 10px; text-transform: uppercase; letter-spacing: 1px;',
        '    color: #009B9E; font-weight: 700; margin: 10px 0 4px;',
        '  }',
        '  .section ol { margin: 0; padding-left: 22px; }',
        '  .section ol li { margin: 3px 0; padding-left: 4px; color: #374151; }',

        # ── Previous release ──
        '  .prev { margin-top: 30px; }',
        '  .prev h3 { font-size: 14px; color: #555; }',
        '  .prev ul { padding-left: 18px; color: #666; font-size: 10.5px; }',

        # ── Footer ──
        '  .footer { margin-top: 30px; padding-top: 12px; border-top: 1px solid #eee; }',
        '  .footer p { font-size: 9px; color: #aaa; text-align: center; }',

        '</style></head><body>',
    ]

    if is_draft:
        parts.append('<div class="draft-badge">DRAFT</div>')

    # ── Cover ──
    parts.extend([
        '<div class="cover">',
        '<div class="tag">Release Notes</div>',
        '<h1>', escape_html(title), '</h1>',
        '<div class="subtitle">What\u2019s new in this build</div>',
        '<hr class="line">',
        '<div class="meta">', escape_html(today), '</div>',
        '<div class="navy-block">',
        '<p><strong>', str(len(sections)), '</strong> feature areas updated</p>',
        '<p>Share this PDF with your team for testing</p>',
        '</div>',
        '</div>',
    ])

    # ── Summary page ──
    parts.append('<div class="section"><h2>Overview</h2>')
    parts.append('<p class="desc">This release includes updates to the following areas:</p>')
    parts.append('<ol>')
    for section in sections:
        clean_heading = re.sub(r'\s*[—–-]\s*.*', '', section.heading).strip()
        parts.append(f'<li><strong>{escape_html(clean_heading)}</strong></li>')
    parts.append('</ol></div>')

    # ── Feature sections ──
    for section in sections:
        parts.append('<div class="section">')
        parts.append(f'<h2><span class="accent">\u25b8</span> {escape_html(section.heading)}</h2>')

        # Description
        desc_html = section.description.replace('\n', '<br>')
        # Bold markers
        desc_html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', desc_html)
        parts.append(f'<div class="desc">{desc_html}</div>')

        # Test steps
        if section.test_steps:
            parts.append('<div class="test-header">How to test</div>')
            parts.append('<ol>')
            for step in section.test_steps:
                parts.append(f'<li>{escape_html(step)}</li>')
            parts.append('</ol>')

        parts.append('</div>')

    # ── Previous release notes ──
    if prev_notes:
        parts.append('<div class="prev">')
        parts.append('<h3>Previously released</h3>')
        prev_html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', prev_notes)
        prev_html = prev_html.replace('\n- ', '</li><li>')
        parts.append(f'<ul><li>{prev_html}</li></ul>')
        parts.append('</div>')

    # ── Footer ──
    parts.extend([
        '<div class="footer">',
        '<p>AscendSME Mobile &middot; Generated ', escape_html(today), '</p>',
        '</div>',
        '</body></html>',
    ])

    return '\n'.join(parts)


def generate_pdf(title: str, sections: list[Section], prev_notes: str | None, is_draft: bool):
    """Generate the PDF file."""
    html = build_html(title, sections, prev_notes, is_draft)

    # Write intermediate HTML for debugging
    html_path = PROJECT_ROOT / 'ASCENDSME_UPDATES.html'
    html_path.write_text(html, encoding='utf-8')

    # Convert to PDF
    try:
        import weasyprint
        pdf_path = PROJECT_ROOT / 'ASCENDSME_UPDATES.pdf'
        doc = weasyprint.HTML(string=html)
        doc.write_pdf(str(pdf_path))
        size_kb = pdf_path.stat().st_size / 1024
        print(f'✅ PDF generated: {pdf_path} ({size_kb:.0f} KB)')
    except ImportError:
        print('⚠️  weasyprint not installed. PDF skipped.')
        print(f'   Open ASCENDSME_UPDATES.html in a browser instead.')
        print(f'   To install: pip3 install weasyprint')


def main():
    parser = argparse.ArgumentParser(description='Generate release notes PDF from CHANGELOG.md')
    parser.add_argument('--draft', action='store_true', help='Mark output as DRAFT')
    args = parser.parse_args()

    if not CHANGELOG_PATH.exists():
        print(f'❌ {CHANGELOG_PATH} not found.')
        print(f'   Create a CHANGELOG.md file in the project root.')
        sys.exit(1)

    title, sections, prev_notes = read_changelog()
    if not sections:
        print('⚠️  No "Unreleased" or version section found in CHANGELOG.md.')
        print('   Add your changes under ## Unreleased in CHANGELOG.md.')
        sys.exit(1)

    print(f'📄 Found {len(sections)} feature section(s) in CHANGELOG.md')
    generate_pdf(title, sections, prev_notes, args.draft)


if __name__ == '__main__':
    main()
