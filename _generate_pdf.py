#!/usr/bin/env python3
"""Convert ASCENDSME_UPDATES.md to a clean professional PDF."""

import markdown
from weasyprint import HTML
import re

def convert_to_pdf():
    with open('ASCENDSME_UPDATES.md', 'r', encoding='utf-8') as f:
        md_content = f.read()

    # Convert markdown to HTML
    html_body = markdown.markdown(
        md_content,
        extensions=['extra', 'toc', 'sane_lists']
    )

    # Build a clean, professional HTML document
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  @page {{
    size: A4;
    margin: 2cm 2.2cm;
    @bottom-center {{
      content: "Page " counter(page) " of " counter(pages);
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      font-size: 9pt;
      color: #888;
    }}
  }}

  * {{
    box-sizing: border-box;
  }}

  body {{
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-size: 10.5pt;
    line-height: 1.6;
    color: #1a1a2e;
    counter-reset: h2-counter;
  }}

  /* ── Cover / Title ── */
  .cover {{
    text-align: center;
    padding: 60px 0 30px 0;
    margin-bottom: 40px;
    border-bottom: 3px solid #1a365d;
  }}
  .cover h1 {{
    font-size: 26pt;
    font-weight: 700;
    color: #1a365d;
    margin: 0 0 8px 0;
    letter-spacing: -0.5px;
  }}
  .cover .subtitle {{
    font-size: 12pt;
    color: #555;
    margin-bottom: 6px;
  }}
  .cover .version {{
    font-size: 10pt;
    color: #888;
    font-style: italic;
  }}

  /* ── TOC ── */
  .toc {{
    background: #f8f9fa;
    border-radius: 8px;
    padding: 18px 24px;
    margin-bottom: 36px;
    page-break-inside: avoid;
  }}
  .toc h2 {{
    font-size: 13pt;
    color: #1a365d;
    margin: 0 0 10px 0;
    border: none;
    padding: 0;
    background: none;
  }}
  .toc ul {{
    list-style: none;
    padding: 0;
    margin: 0;
    columns: 2;
    column-gap: 30px;
  }}
  .toc li {{
    margin: 3px 0;
    font-size: 10pt;
  }}
  .toc a {{
    color: #2563eb;
    text-decoration: none;
  }}

  /* ── Section Headings ── */
  h2 {{
    font-size: 16pt;
    font-weight: 700;
    color: #ffffff;
    background: #1a365d;
    padding: 8px 16px;
    border-radius: 6px;
    margin: 30px 0 16px 0;
    page-break-after: avoid;
  }}

  h3 {{
    font-size: 13pt;
    font-weight: 700;
    color: #1a365d;
    margin: 22px 0 10px 0;
    padding-bottom: 4px;
    border-bottom: 2px solid #e2e8f0;
    page-break-after: avoid;
  }}

  h4 {{
    font-size: 11.5pt;
    font-weight: 600;
    color: #2d3748;
    margin: 16px 0 8px 0;
  }}

  /* ── Paragraphs & Lists ── */
  p {{
    margin: 0 0 10px 0;
  }}

  ul, ol {{
    margin: 6px 0 12px 0;
    padding-left: 22px;
  }}
  li {{
    margin-bottom: 4px;
  }}

  /* ── Blockquotes (for "What changed" / highlights) ── */
  blockquote {{
    margin: 12px 0;
    padding: 10px 16px;
    background: #f0f4ff;
    border-left: 4px solid #2563eb;
    border-radius: 0 6px 6px 0;
    page-break-inside: avoid;
  }}
  blockquote p {{
    margin: 0;
    color: #1e40af;
    font-weight: 500;
  }}

  /* ── Tables ── */
  table {{
    width: 100%;
    border-collapse: collapse;
    margin: 14px 0;
    font-size: 9.5pt;
    page-break-inside: avoid;
  }}
  th {{
    background: #1a365d;
    color: white;
    font-weight: 600;
    padding: 8px 10px;
    text-align: left;
  }}
  td {{
    padding: 6px 10px;
    border-bottom: 1px solid #e2e8f0;
  }}
  tr:nth-child(even) td {{
    background: #f8f9fa;
  }}

  /* ── Code / Inline highlights ── */
  code {{
    font-family: 'SF Mono', 'Fira Code', 'Consolas', monospace;
    font-size: 9pt;
    background: #f1f5f9;
    padding: 1px 5px;
    border-radius: 3px;
    color: #b91c1c;
  }}

  /* ── Horizontal rules ── */
  hr {{
    border: none;
    border-top: 2px solid #e2e8f0;
    margin: 28px 0;
  }}

  /* ── Strong / emphasis ── */
  strong {{
    font-weight: 700;
    color: #1a365d;
  }}

  /* ── Footer ── */
  .footer {{
    text-align: center;
    font-size: 9pt;
    color: #aaa;
    margin-top: 40px;
    padding-top: 16px;
    border-top: 1px solid #e2e8f0;
  }}

  /* ── Priority badges ── */
  .badge-high {{
    display: inline-block;
    background: #dc2626;
    color: white;
    font-size: 8pt;
    font-weight: 700;
    padding: 1px 8px;
    border-radius: 10px;
    margin-right: 4px;
  }}
  .badge-medium {{
    display: inline-block;
    background: #d97706;
    color: white;
    font-size: 8pt;
    font-weight: 700;
    padding: 1px 8px;
    border-radius: 10px;
    margin-right: 4px;
  }}
  .badge-low {{
    display: inline-block;
    background: #059669;
    color: white;
    font-size: 8pt;
    font-weight: 700;
    padding: 1px 8px;
    border-radius: 10px;
    margin-right: 4px;
  }}

  .page-break {{
    page-break-before: always;
  }}
</style>
</head>
<body>

<div class="cover">
  <h1>AscendSME Mobile</h1>
  <div class="subtitle">Recent Updates &amp; Testing Guide</div>
  <div class="version">Latest Build — June 2026</div>
</div>

{html_body}

<div class="footer">
  Generated from the latest build &middot; For questions, contact the development team
</div>

</body>
</html>"""

    # Write HTML
    with open('ASCENDSME_UPDATES.html', 'w', encoding='utf-8') as f:
        f.write(html)

    # Convert to PDF
    HTML('ASCENDSME_UPDATES.html').write_pdf('ASCENDSME_UPDATES.pdf')

    print("✅ PDF generated: ASCENDSME_UPDATES.pdf")
    print("✅ HTML source: ASCENDSME_UPDATES.html")

if __name__ == '__main__':
    convert_to_pdf()
