#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
from pathlib import Path
from bs4 import BeautifulSoup

# Dictionary for decomposing common ligatures
LIGATURE_MAP = {
    '\ufb00': 'ff',   # ﬀ
    '\ufb01': 'fi',   # ﬁ
    '\ufb02': 'fl',   # ﬂ
    '\ufb03': 'ffi',  # ﬃ
    '\ufb04': 'ffl',  # ﬄ
}

def decompose_ligatures(text: str) -> str:
    for lig, plain in LIGATURE_MAP.items():
        text = text.replace(lig, plain)
    return text

def html_to_clean_paragraphs(html_content: str) -> str:
    soup = BeautifulSoup(html_content, "lxml-xml")

    for tag in soup(["script", "style", "noscript", "header", "footer", "nav", "aside", "svg"]):
        tag.decompose()

    # Each block with one of these tags goes to a new line
    block_tags = {
        'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'li', 'dt', 'dd', 'div', 'section', 'article',
        'blockquote', 'pre', 'tr'
    }

    lines = []

    for elem in soup.find_all(block_tags):
        text = elem.get_text(separator=" ", strip=True)

        if text:
            text = " ".join(text.split())  # normalizza spazi interni
            lines.append(text)

    # Remove duplicated empty lines
    cleaned = []

    for line in lines:
        if line or (cleaned and cleaned[-1]):
            cleaned.append(line)

    return decompose_ligatures("\n".join(cleaned))

if len(sys.argv) < 2:
    print("Usage: html2txt.py file.html [output.txt]")
    sys.exit(1)

input_path = Path(sys.argv[1])

if not input_path.exists():
    print(f"File not found: {input_path}")
    sys.exit(1)

html = input_path.read_text(encoding="utf-8", errors="ignore")
text = html_to_clean_paragraphs(html)

output_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else input_path.with_suffix(".txt")

if not output_path.exists() or output_path.read_text(encoding="utf-8") != text:
    print(f"Creating {output_path}...")
    output_path.write_text(text, encoding="utf-8")
else:
    print(f"{output_path} is unchanged")