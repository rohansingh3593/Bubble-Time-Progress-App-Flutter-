"""Build a local, dependency-free review gallery from capture manifests."""
import html
import json
import sys
from pathlib import Path

def main():
    root = Path(sys.argv[1]).resolve()
    manifests = [json.loads(p.read_text(encoding="utf-8"))
                 for p in sorted(root.glob("*/manifest.json"))]
    if not manifests:
        raise SystemExit("No capture manifests found")
    captures = [c for m in manifests for c in m["captures"]]
    issues = [dict(theme=m["theme"], **i) for m in manifests for i in m["issues"]]
    groups = sorted({c["screen"] for c in captures})
    esc = html.escape
    nav = "".join('<a href="#' + esc(s) + '">' + esc(s) + '</a>' for s in groups)
    sections = []
    for screen in groups:
        cards = []
        for c in (c for c in captures if c["screen"] == screen):
            source = esc(c["file"], quote=True)
            cards.append(
                '<figure><a href="' + source + '" target="_blank" rel="noopener">'
                '<img loading="lazy" src="' + source + '" width="390" height="844" alt="' +
                esc(screen + ' ' + c["theme"] + ' page ' + str(c["page"]), quote=True) +
                '"></a><figcaption>' + esc(c["theme"]) + ' · page ' + str(c["page"]) +
                '</figcaption></figure>')
        sections.append('<section id="' + esc(screen) + '"><h2>' + esc(screen) +
                        '</h2><div class="grid">' + "".join(cards) + '</div></section>')
    issue_html = "".join('<details><summary>' + esc(i["theme"] + " / " + i["screen"]) +
                         '</summary><pre>' + esc(i["error"]) + '</pre></details>' for i in issues)
    limitations = "".join('<li>' + esc(x) + '</li>' for x in manifests[0]["limitations"])
    page = """<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Momentum phone screenshots</title><style>
body{margin:0;font:16px system-ui,sans-serif;color:#17202a;background:#f3f5f8}
header,main{max-width:1500px;margin:auto;padding:24px}
header{background:white}h1{margin-top:0}p,li{line-height:1.55}
nav{display:flex;gap:8px;flex-wrap:wrap}nav a{padding:8px 12px;background:#e7edf5;border-radius:8px;color:#154477;text-decoration:none}
.grid{display:flex;flex-wrap:wrap;gap:20px;align-items:start}
figure{margin:0 0 20px;background:white;padding:10px;border:1px solid #ccd4df;border-radius:12px}
img{display:block;max-width:100%;height:auto;width:312px;border:1px solid #ddd}
figcaption{padding:10px 0 2px}section{scroll-margin-top:20px}pre{white-space:pre-wrap;overflow-wrap:anywhere}
details{padding:12px;background:white;margin-bottom:8px}a{color:#165a9b}
</style><header><h1>Momentum · phone reference screenshots</h1>"""
    page += '<p>' + str(len(captures)) + ' PNGs · 390 × 844 logical pixels · 2× output resolution. '
    page += 'Real Flutter widgets with synthetic sample data. Click any image for full size.</p>'
    page += '<details><summary>Capture method and limitations</summary><ul>' + limitations + '</ul></details>'
    page += '<p><a href="capture-report.json">Capture report</a> · ' + str(len(issues)) + ' recorded rendering/capture issues.</p>'
    page += '<nav>' + nav + '</nav></header><main>' + "".join(sections)
    page += '<section><h2>Recorded issues</h2>' + (issue_html or '<p>No errors recorded by this capture run.</p>') + '</section></main></html>'
    (root / "index.html").write_text(page, encoding="utf-8")
    (root / "capture-report.json").write_text(json.dumps(
        {"captures": captures, "issues": issues, "runs": manifests}, indent=2), encoding="utf-8")
    print(f"Gallery: {root / 'index.html'}")
    print(f"{len(captures)} images; {len(groups)} screen/form groups; {len(issues)} recorded issues")

if __name__ == "__main__":
    main()

