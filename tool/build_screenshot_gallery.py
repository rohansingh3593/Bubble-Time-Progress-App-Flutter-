"""Build a local, dependency-free review gallery from capture manifests."""
import hashlib
import html
import json
import sys
from pathlib import Path


SCREEN_CATALOG = {
    "00-app-shell": ("App shell", "Navigation", "Persistent app destinations and shell."),
    "00-navigation": ("More", "Feature directory", "Searchable feature index and grouped destinations."),
    "00-settings": ("Settings", "Configuration", "Appearance and app preference controls."),
    "00-plan-day": ("Plan — Day", "Planning", "Selected-day agenda inside the app shell."),
    "00-plan-week": ("Plan — Week", "Planning", "Selected-week planning view inside the app shell."),
    "00-plan-month": ("Plan — Month", "Planning", "Selected-month planning view inside the app shell."),
    "00-plan-year": ("Plan — Year", "Planning", "Selected-year overview inside the app shell."),
    "00-progress": ("Progress", "Progress", "Progress destination inside the app shell."),
    "01-dashboard": ("Dashboard", "Dashboard", "Productivity dashboard and tabbed summaries."),
    "02-year": ("Year plan", "Planning", "Yearly planning overview."),
    "03-month": ("Month plan", "Planning", "Monthly planning overview."),
    "04-week": ("Week plan", "Planning", "Weekly planning overview."),
    "05-day": ("Day plan", "Planning", "Daily agenda and schedule."),
    "06-tasks": ("Tasks", "Task management", "Task list, search, filters, and task actions."),
    "07-streak": ("Streaks", "Progress", "Streak and activity history."),
    "08-instructions": ("Instructions", "More", "Instruction and routine management."),
    "09-goals": ("Goals", "More", "Goal and reward-goal management."),
    "10-money": ("Reward money", "Rewards", "Reward balance and recorded activity."),
    "11-motivation": ("Motivation", "More", "Motivational motto collection."),
    "12-progress-reports": ("Progress reports", "Progress", "Productivity reports and trends."),
    "13-log-earn": ("Log & Earn", "Rewards", "Logging work and earning rewards."),
    "14-journal": ("Journal", "Reflection", "Date-specific journal entry."),
    "15-journey": ("Journey", "Reflection", "Journey timeline and entries."),
    "16-voice": ("Voice task capture", "Task capture", "Voice-assisted task entry."),
    "17-today": ("Today", "Dashboard", "Daily task overview and reflection entry point."),
    "18-settings": ("Settings", "Configuration", "Appearance and app preference controls."),
}


def describe_capture(capture):
    source_name = capture.get("screen", "")
    base_name = source_name
    for suffix in (
        "-create-form", "-edit-form", "-occurrence", "-overview",
        "-productivity", "-instructions", "-growth", "-tasks", "-goals",
        "-form",
    ):
        if base_name.endswith(suffix):
            base_name = base_name[:-len(suffix)]
            break
    name, category, purpose = SCREEN_CATALOG.get(
        base_name, ("Unidentified", "Unclassified", "Screen identity needs visual review.")
    )
    if source_name != base_name:
        if source_name.endswith("-overview"):
            name += " — Overview"
        elif source_name.endswith("-productivity"):
            name += " — Productivity"
        elif source_name.endswith("-tasks"):
            name += " — Tasks"
        elif source_name.endswith("-goals"):
            name += " — Goals"
        elif source_name.endswith("-instructions"):
            name += " — Instructions"
        elif source_name.endswith("-growth"):
            name += " — Growth"
        elif source_name.endswith("-form"):
            name += " — Form"
            category = "Form"
        elif source_name.endswith("-create-form"):
            name += " — Create form"
            category = "Form"
        elif source_name.endswith("-edit-form"):
            name += " — Edit form"
            category = "Form"
        elif source_name.endswith("-occurrence"):
            name += " — Occurrence"
            category = "Task management"

    page = capture.get("page", 1)
    if page != 1:
        section = "Continued scroll content"
        position = "Scrollable content"
    else:
        section = "Primary viewport"
        position = "Full screenshot"
    note = capture.get("note", "")
    if note:
        section = note
    return {
        "screenName": name,
        "purpose": purpose,
        "category": category,
        "theme": capture.get("theme", "Unknown"),
        "palette": capture.get("palette", "Unknown"),
        "state": "Reference render with sample data",
        "variation": "Scroll continuation" if page != 1 else "Theme / palette",
        "sections": [{
            "name": section,
            "position": position,
            "elements": "Not identified from capture metadata; confirm by viewing the image.",
        }],
    }


def load_captures(root):
    manifest_paths = sorted(root.rglob("manifest.json"))
    manifests = [json.loads(p.read_text(encoding="utf-8")) for p in manifest_paths]
    captures = []
    for manifest_path, manifest in zip(manifest_paths, manifests):
        for capture in manifest.get("captures", []):
            item = dict(capture)
            source = (manifest_path.parent.parent / capture["file"]).resolve()
            try:
                item["file"] = source.relative_to(root).as_posix()
            except ValueError:
                item["file"] = str(source)
            item["_source"] = str(source)
            item["_captureRoot"] = str(root)
            item["_method"] = manifest.get("method", "Unknown capture method")
            item["_data"] = manifest.get("data", "Unknown data source")
            captures.append(item)

    if not manifests:
        for image in sorted(
            p for p in root.rglob("*")
            if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
        ):
            captures.append({
                "file": image.relative_to(root).as_posix(),
                "screen": "Unidentified",
                "page": 1,
                "theme": "Unknown",
                "palette": "Unknown",
                "note": "Imported image; visual classification required.",
                "_source": str(image.resolve()),
                "_captureRoot": str(root),
                "_method": "Imported image",
                "_data": "Unknown",
            })
    return manifests, captures


def image_hash(path):
    try:
        digest = hashlib.sha256()
        with Path(path).open("rb") as image:
            for block in iter(lambda: image.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest()
    except OSError:
        return None


def register_captures(captures, registry_path):
    registry_path = Path(registry_path).resolve()
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    if registry_path.exists():
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
    else:
        registry = {"nextId": 1, "records": []}
    registry.setdefault("nextId", 1)
    registry.setdefault("records", [])
    by_path = {record["sourcePath"]: record for record in registry.get("records", [])}
    hashes = {}
    for record in registry["records"]:
        if record.get("sha256"):
            hashes.setdefault(record["sha256"], record)
    for capture in captures:
        source = Path(capture["_source"])
        try:
            source_path = source.relative_to(registry_path.parent).as_posix()
        except ValueError:
            source_path = str(source)
        metadata = describe_capture(capture)
        record = by_path.get(source_path)
        if record is None:
            record = {"id": "S{:02d}".format(registry["nextId"]), "sourcePath": source_path}
            registry["nextId"] += 1
            registry["records"].append(record)
            by_path[source_path] = record
        record.update({
            "file": capture["file"],
            "screenId": capture.get("screen", "Unidentified"),
            "page": capture.get("page", 1),
            "note": capture.get("note", ""),
            "method": capture["_method"],
            "dataSource": capture["_data"],
            **metadata,
        })
        digest = image_hash(capture["_source"])
        record["sha256"] = digest
        matching_hash = hashes.get(digest) if digest else None
        record["duplicateOf"] = (
            matching_hash["id"]
            if matching_hash and matching_hash["id"] != record["id"]
            else None
        )
        if digest:
            hashes.setdefault(digest, record)
        capture["id"] = record["id"]
        capture.update(metadata)

    registry_path.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
    return registry


def write_inventory(path, records, title):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    for record in records:
        record.setdefault("palette", "Unknown")
    path.write_text(json.dumps({"screenshots": records}, indent=2, ensure_ascii=False), encoding="utf-8")
    screens = {record["screenName"] for record in records}
    categories = {}
    for record in records:
        categories.setdefault(record["category"], []).append(record["id"])
    exact_duplicates = [record for record in records if record.get("duplicateOf")]
    unclassified = [record for record in records if record["category"] == "Unclassified"]
    lines = [
        "# Screenshot inventory",
        "",
        title,
        "",
        "Section and element labels are not inferred from image pixels. Entries requiring visual review say so explicitly.",
        "",
        "## Collection summary",
        "",
        "- Screenshots: {}".format(len(records)),
        "- Screen/page groups: {}".format(len(screens)),
        "- Recorded theme/state variations: {}".format(len({
            (record["screenName"], record["theme"], record["palette"], record["variation"])
            for record in records
        })),
        "- Sections listed: {}".format(sum(len(record["sections"]) for record in records)),
        "- Shared components visually confirmed: 0 (not image-inspected by this generator)",
        "- Exact duplicate images: {}".format(len(exact_duplicates)),
        "- Near-duplicates: not assessed",
        "- Unclassified images needing review: {}".format(len(unclassified)),
        "",
        "## Master inventory",
        "",
        "| ID | Screen | Category | Mode | Palette | State / variation | Image |",
        "|---|---|---|---|---|---|---|",
    ]
    for record in records:
        lines.append(
            "| {id} | {screenName} | {category} | {theme} | {palette} | {variation} | `{sourcePath}` |".format(
                **record
            )
        )
    lines.extend(["", "## Screen groups", ""])
    groups = {}
    for record in records:
        groups.setdefault(record["screenName"], []).append(record["id"])
    for screen, ids in groups.items():
        lines.append("- **{}**: {}".format(screen, ", ".join(ids)))
    lines.extend(["", "## Screenshot coverage", "",
                  "| Category | Included IDs |",
                  "|---|---|"])
    for category, ids in sorted(categories.items()):
        lines.append("| {} | {} |".format(category, ", ".join(ids)))
    lines.extend(["", "## Screenshot-wise breakdown", ""])
    for record in records:
        lines.extend([
            "### {} — {}".format(record["id"], record["screenName"]),
            "",
            "- **Purpose:** {}".format(record["purpose"]),
            "- **Category:** {}".format(record["category"]),
            "- **Mode:** {}".format(record["theme"]),
            "- **Palette:** {}".format(record["palette"]),
            "- **State / variation:** {}".format(record["variation"]),
            "- **Source:** `{}` ({})".format(record["sourcePath"], record["method"]),
            "- **Data:** {}".format(record["dataSource"]),
            "- **Exact duplicate:** {}".format(record["duplicateOf"] or "None detected"),
            "- **Sections:**",
        ])
        for index, section in enumerate(record["sections"], start=1):
            lines.append(
                "  - {}-SEC{:02d} **{}** — {}. {}".format(
                    record["id"], index, section["name"], section["position"], section["elements"]
                )
            )
        lines.append("")
    lines.extend([
        "## Component inventory",
        "",
        "Not generated from manifest data. Confirm shared components by visually reviewing the referenced images.",
        "",
        "## Coverage notes",
        "",
        "- Display mode, color palette, and page variations are recorded from the capture manifest.",
        "- Missing states in this inventory are suggested collection items, not evidence that the app lacks those states.",
        "- Imported images without manifests are assigned Unidentified / Unclassified until visually reviewed.",
        "- Exact duplicates are detected using SHA-256; visually similar but different images are not automatically labeled duplicates.",
        "",
    ])
    path.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit("Usage: build_screenshot_gallery.py <directory> [--inventory-only] [--registry <path>]")
    root = Path(args[0]).resolve()
    inventory_only = "--inventory-only" in args
    registry = root.parent / "screenshot-inventory.json"
    if "--registry" in args:
        index = args.index("--registry")
        if index + 1 >= len(args):
            raise SystemExit("--registry requires a path")
        registry = Path(args[index + 1])
    if not root.is_dir():
        raise SystemExit("Screenshot directory does not exist: {}".format(root))

    manifests, captures = load_captures(root)
    if not captures:
        raise SystemExit("No screenshot images or capture manifests found in {}".format(root))

    registry_data = register_captures(captures, registry)
    master_inventory = Path(registry).resolve().parent / "screenshot-inventory.json"
    local_records = []
    local_ids = {capture["id"] for capture in captures}
    for record in registry_data["records"]:
        if record["id"] in local_ids:
            local_records.append(record)
    write_inventory(root / "screenshot-inventory.json", local_records,
                    "Inventory for `{}`.".format(root))
    write_inventory(master_inventory, registry_data["records"],
                    "Cumulative inventory; IDs are retained when the builder is rerun.")

    if inventory_only:
        print("Inventory: {} screenshots".format(len(captures)))
        print("Local inventory: {}".format(root / "screenshot-inventory.md"))
        print("Master inventory: {}".format(master_inventory.with_suffix(".md")))
        return

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
                esc(c["id"] + ' ' + screen + ' ' + c["theme"] + ' ' + c["palette"] +
                    ' page ' + str(c["page"]), quote=True) +
                '"></a><figcaption>' + esc(c["palette"]) + ' · ' + esc(c["theme"]) +
                ' · page ' + str(c["page"]) +
                ' · ' + esc(c["id"]) +
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
    page += '<p><a href="capture-report.json">Capture report</a> · <a href="screenshot-inventory.md">Screenshot inventory</a> · ' + str(len(issues)) + ' recorded rendering/capture issues.</p>'
    page += '<nav>' + nav + '</nav></header><main>' + "".join(sections)
    page += '<section><h2>Recorded issues</h2>' + (issue_html or '<p>No errors recorded by this capture run.</p>') + '</section></main></html>'
    (root / "index.html").write_text(page, encoding="utf-8")
    (root / "capture-report.json").write_text(json.dumps(
        {"captures": captures, "issues": issues, "runs": manifests}, indent=2), encoding="utf-8")
    print(f"Gallery: {root / 'index.html'}")
    print(f"{len(captures)} images; {len(groups)} screen/form groups; {len(issues)} recorded issues")
    print(f"Inventory: {root / 'screenshot-inventory.md'}")
    print(f"Master inventory: {master_inventory.with_suffix('.md')}")

if __name__ == "__main__":
    main()
