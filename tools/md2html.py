#!/usr/bin/env python3
"""Render a Markdown file as a standalone HTML page.

    python3 tools/md2html.py store/privacy-policy.md docs/index.html

Used for the privacy policy, which Google Play requires at a live public URL.
docs/ is served by GitHub Pages. Deliberately minimal: it handles the headings,
paragraphs, numbered lists, links, bold and code that the policy actually uses,
rather than pulling in a Markdown dependency for one file.
"""
import html
import re
import sys
from pathlib import Path

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
LIST_RE = re.compile(r"^\d+\.\s")


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return text


out, in_list = [], False
for line in src.read_text(encoding="utf-8").split("\n"):
    s = line.strip()
    if s.startswith("# "):
        out.append("<h1>" + inline(s[2:]) + "</h1>")
    elif s.startswith("## "):
        out.append("<h2>" + inline(s[3:]) + "</h2>")
    elif LIST_RE.match(s):
        if not in_list:
            out.append("<ol>")
            in_list = True
        out.append("<li>" + inline(LIST_RE.sub("", s)) + "</li>")
    elif not s:
        if in_list:
            out.append("</ol>")
            in_list = False
    else:
        if in_list:
            out.append("</ol>")
            in_list = False
        out.append("<p>" + inline(s) + "</p>")
if in_list:
    out.append("</ol>")

STYLE = """
  :root { color-scheme: light dark; --fg:#1a1c1e; --muted:#5a6068; --bg:#ffffff; --accent:#3F5B8B; }
  @media (prefers-color-scheme: dark) {
    :root { --fg:#e4e6e8; --muted:#a8aeb6; --bg:#15171a; --accent:#9db4dd; }
  }
  body { background:var(--bg); color:var(--fg); margin:0;
         font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  main { max-width:44rem; margin:0 auto; padding:3rem 1.25rem 5rem; }
  h1 { font-size:1.9rem; line-height:1.2; margin:0 0 .4rem; }
  h2 { font-size:1.15rem; margin:2.4rem 0 .6rem; color:var(--accent); }
  p { margin:0 0 1rem; }
  a { color:var(--accent); }
  code { background:rgba(128,128,128,.16); padding:.1em .35em; border-radius:4px; font-size:.9em; }
  ol { padding-left:1.3rem; } li { margin-bottom:.5rem; }
  h1 + p { color:var(--muted); font-size:.92rem; }
"""

dst.write_text(
    '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    "<title>Privacy Policy &middot; DeutschCards</title>\n<style>"
    + STYLE
    + "</style>\n</head>\n<body><main>\n"
    + "\n".join(out)
    + "\n</main></body>\n</html>\n",
    encoding="utf-8",
)
print("wrote", dst)
