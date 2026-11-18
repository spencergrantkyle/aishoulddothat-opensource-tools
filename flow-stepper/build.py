"""Build a self-contained flow-stepper HTML page from one or more spec JSON files.

    python build.py spec.json [more.json ...] -o out.html [--title "Page title"] [--intro "One paragraph"]

Validates every spec first and refuses to build if any reference is broken.
No dependencies beyond the standard library.
"""
import argparse
import html
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SIDES = {"top", "bottom", "left", "right"}
LABEL_SIDES = {"above", "below", "left", "right"}
ITEM_STATES = {"ok", "fail", "pending", "focus", "hidden"}
ICONS = {"person", "team", "doc", "sheet", "chip", "db", "gear", "cloud", "shield", "list", "bolt",
         "lock", "chat", "spark", "play", "folder", "eye", "printer", "flag", "warn"}
NODE_KEYS = {"planned", "danger", "highlight", "meta", "metaMarker", "items"}


def validate(spec, name):
    errs = []
    e = errs.append
    if not re.fullmatch(r"[A-Za-z][\w-]*", str(spec.get("id", ""))):
        e("spec.id is required: a short slug, unique on the page (used for SVG marker ids)")
    nodes = {}
    for n in spec.get("nodes", []):
        nid = n.get("id")
        if nid in nodes:
            e(f"duplicate node id {nid!r}")
        nodes[nid] = n
        if not n.get("area"):
            e(f"node {nid!r} has no grid 'area' (row-start / col-start / row-end / col-end)")
        if n.get("icon") and n["icon"] not in ICONS:
            e(f"node {nid!r}: unknown icon {n['icon']!r} (have: {', '.join(sorted(ICONS))})")
        for it in n.get("items", []):
            if it.get("status", "ok") not in ITEM_STATES:
                e(f"node {nid!r} item {it.get('id')!r}: bad status")
    if not nodes:
        e("no nodes")
    edges = {}
    for ed in spec.get("edges", []):
        eid = ed.get("id")
        edges[eid] = ed
        for end in ("from", "to"):
            if ed.get(end) not in nodes:
                e(f"edge {eid!r}: {end} {ed.get(end)!r} is not a node")
        for s in ("fromSide", "toSide"):
            if ed.get(s) not in SIDES:
                e(f"edge {eid!r}: {s} must be one of {sorted(SIDES)}")
    steps = spec.get("steps", [])
    if not steps:
        e("no steps")
    for i, st in enumerate(steps, 1):
        if not st.get("title"):
            e(f"step {i}: no title")
        for a in st.get("active", []):
            if a not in nodes:
                e(f"step {i}: active {a!r} is not a node")
        for f in st.get("flows", []):
            if f.get("edge") not in edges:
                e(f"step {i}: flow edge {f.get('edge')!r} is not an edge")
            if f.get("side") and f["side"] not in LABEL_SIDES:
                e(f"step {i}: label side must be one of {sorted(LABEL_SIDES)}")
        for nid, patch in st.get("set", {}).items():
            if nid not in nodes:
                e(f"step {i}: set {nid!r} is not a node")
                continue
            for k in patch:
                if k not in NODE_KEYS:
                    e(f"step {i}: set.{nid}.{k} is not a node state key ({sorted(NODE_KEYS)})")
            item_ids = {it["id"] for it in nodes[nid].get("items", [])}
            for iid, v in patch.get("items", {}).items():
                if iid not in item_ids:
                    e(f"step {i}: item {iid!r} not in node {nid!r}")
                if v not in ITEM_STATES:
                    e(f"step {i}: item {iid!r} status {v!r} not in {sorted(ITEM_STATES)}")
            if "meta" in patch and nodes[nid].get("meta") is None:
                e(f"step {i}: node {nid!r} gets a meta but declares none (give it \"meta\": \"\")")
    return [f"{name}: {x}" for x in errs]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("specs", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--title")
    ap.add_argument("--intro", help="optional paragraph above the figures")
    a = ap.parse_args()

    specs, errs = [], []
    for p in a.specs:
        spec = json.loads(Path(p).read_text(encoding="utf-8"))
        errs += validate(spec, Path(p).name)
        specs.append(spec)
    ids = [s.get("id") for s in specs]
    if len(ids) != len(set(ids)):
        errs.append("two specs share an id")
    if errs:
        print("REFUSED - spec errors:", *errs, sep="\n  ", file=sys.stderr)
        return 1

    title = a.title or specs[0].get("title", "Walkthrough")
    blocks = "\n".join(
        '<script type="application/json" class="flow-spec">'
        + json.dumps(s, ensure_ascii=False).replace("</", "<\\/")
        + "</script>" for s in specs)
    intro = ""
    if a.intro or a.title:
        intro = (f'<header class="page-intro"><h1>{html.escape(title)}</h1>'
                 + (f"<p>{html.escape(a.intro)}</p>" if a.intro else "") + "</header>")
    page = ((HERE / "engine.html").read_text(encoding="utf-8")
            .replace("__TITLE__", html.escape(title))
            .replace("<!--INTRO-->", intro)
            .replace("<!--SPECS-->", blocks))
    Path(a.out).write_text(page, encoding="utf-8")
    steps = sum(len(s["steps"]) for s in specs)
    print(f"OK  {a.out}  ({len(specs)} figure(s), {steps} steps, {len(page) // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
