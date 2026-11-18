---
name: flow-stepper
description: Build an animated, step-through diagram guide (boxes, wires, numbered captions, Back/Next) as one self-contained HTML page, in the style of OpenAI's "control room" explainer. Use when the user asks for a visual walkthrough, a step-by-step diagram, an animated process explainer, "show how X flows", "walk me through the pipeline visually", "a diagram guide for <process>", or "use flow-stepper". You write a JSON spec (nodes, edges, steps); build.py validates it and renders the page. NOT for static charts (use dataviz) or one-off inline SVG.
---

# flow-stepper

A figure is a fixed set of **nodes** on a 12-column grid, the **edges** that may carry
traffic between them, and an ordered list of **steps**. Each step lights up some nodes, animates
some edges with labels, and patches node state. The reader steps through with Back/Next, the
tick bar, or the arrow keys.

```
flow-stepper/                  (this skill's folder; below it is called <skill>)
  build.py                     validator + renderer (Python 3, stdlib only)
  engine.html                  page template: CSS tokens, light/dark, the runtime
  examples/code-release.json   branch → CI → review → staging → prod, 11 steps, with a failure arc
```

Read `examples/code-release.json` before writing a new spec. It shows every feature in use.

## Workflow

1. **Get the source.** Read whatever describes the process (an artifact, doc, ticket, repo).
   List the actors, the things that hold state, and the order things happen in. Each of these
   becomes a node, and each handoff becomes an edge.
2. **Sketch the grid on paper first** (see Layout). Decide rows and column spans before writing JSON.
3. **Write the spec** to `<name>.json` in the working directory (not in the skill folder).
4. **Build.** This refuses to build if any reference is broken:
   ```bash
   python <skill>/build.py spec.json -o page.html --title "Two to four words" --intro "One paragraph."
   ```
   Pass several spec files to put several figures on one page. Each needs a unique `id`.
5. **Look at it** (see Checking). The validator cannot see geometry.
6. **Hand it over.** The output is one self-contained HTML file with no external scripts, which
   works offline and in light or dark mode. Give the user the file, or publish it with the
   Artifact tool if that's available (icon `diagram`).

## Spec

```jsonc
{
  "id": "factory",                       // slug, unique on the page (SVG marker ids)
  "title": "Figure heading",
  "lede": "One or two sentences under it. `code` and **bold** work.",
  "layout": { "rows": "auto 3rem auto 4.5rem auto", "minWidth": "50rem" },
  "tokens": { "accent": "#0e4b91" },     // optional: override CSS vars for this figure
  "nodes": [ ... ], "edges": [ ... ], "steps": [ ... ]
}
```

### Nodes

| key | meaning |
|---|---|
| `id` | required |
| `area` | required. CSS grid-area `"row-start / col-start / row-end / col-end"` on a 12-column grid |
| `title`, `sub` | heading and a smaller line (`sub` supports `code`/**bold**) |
| `icon` | one of: person team doc sheet chip db gear cloud shield list bolt lock chat spark play folder eye printer flag warn |
| `kind: "actor"` | a person or trigger: a circle icon with a name, no box |
| `meta` | a monospace status line. Declare it as `""` if any step will set it |
| `planned: true` | dashed and greyed, "not there yet". Steps clear it with `set` |
| `highlight: true` | accent outline |
| `items` | chips: `{id, label, color, status}`. `color` is a CSS colour, usually `var(--c1)`…`var(--c4)` |
| `cols` | chip columns (default 2) |

Item `status`: `ok` (tick), `fail` (cross), `pending` (empty ring), `focus`, `hidden` (takes up space but invisible).

### Edges

`{ "id", "from", "fromSide", "to", "toSide" }`. Sides are `top|bottom|left|right`. Edges are drawn
as faint rails at all times and animated only when a step lists them in `flows`.

Optional settings:
- `fromAt` / `toAt` (0–1, default 0.5): where along the side the wire attaches. Use these when
  two edges share a side.
- `mid`: the x (or y) pixel of the elbow.
- `rail: false`: hide the resting rail.

Routing is orthogonal:
- Opposite horizontal sides make a Z shape, and so do opposite vertical sides.
- A horizontal side to a vertical side makes an L.

### Steps

```jsonc
{ "title": "Short sentence, the claim of this step",
  "body": "One to three sentences. `code`, **bold**.",
  "active": ["nodeA", "nodeB"],                    // outlined this step only
  "flows": [{ "edge": "e1", "label": "push", "sub": "you approve",
              "side": "above|below|left|right", "danger": true, "reverse": true, "marker": false }],
  "set": { "nodeA": { "meta": "built", "metaMarker": "var(--c4)", "planned": false,
                      "danger": true, "highlight": true, "items": { "g1": "ok" } } } }
```

- **`set` is cumulative.** Each step patches the state left by the previous one, so a danger or
  highlight stays on until a later step sets it back to `false`. `active` and `flows` are for
  this step only.
- `reverse` animates the edge from `to` back to `from`.
- `marker: false` drops the diamond bullet before `sub`.
- `danger` turns the wire, label or node red.

## Layout rules (learned the hard way)

- **Use rows of nodes with gap rows between them**, e.g. `"auto 3rem auto 4.5rem auto"`. The gap
  rows are where wires and labels live. Give a gap row 4–5rem if a horizontal edge label sits in it.
- **Plan edges before placing nodes.** An L-shaped or Z-shaped wire runs straight through any node
  in its path. Place nodes so that every edge is a straight drop between rows, a short hop across
  an empty column, or a Z through a gap row.
- **Three columns of 4 spans each** (`1/5`, `5/9`, `9/13`) is the most readable layout. Use an
  actor in a 3-column span at a corner.
- **A horizontal edge between adjacent nodes needs a real gap.** The column gutter alone is about
  20px, too short for a label, and it collapses. Leave a column empty between the two nodes (e.g.
  `1/4` and `5/9`), or drop the label. `build.py` does not catch this.
- **Item labels: about 9 characters at most** in a 4-column node with 2 chip columns ("Research",
  "Test pack", "G1 plan"), or they are cut off. Put the detail in the step body, not the chip.
- **A 3-column node (e.g. `1/4`, `10/13`) with items needs `"cols": 1`.** Two chip columns there
  cut off even 5-letter labels.
- Keep `code` in `sub` short (a file name, not a full path). It wraps at any character, so a long
  path breaks mid-word.
- Edge labels wrap at 11rem. Keep `label` to 1–3 words and `sub` to 1–2.
- Use `side` to move a label off a wire that runs along a node edge.
- One figure: 6–10 nodes, 8–20 steps. Split anything bigger into two specs on one page.

## Writing the story

- Each step title states one fact in plain words. The body says why it matters or what a reader
  would otherwise miss. Don't narrate the animation ("an arrow moves to…").
- Order steps in the order things actually happen. Light only the nodes the step is about.
- **End with a failure arc** if there is a real failure mode. Show it with `danger`, then a step
  that says what rule prevents it, and reset the danger flags in that last step. This makes the
  diagram explain a constraint and not just a happy path. Both examples do this.
- Use the user's own terms and identifiers (ticket keys, GUIDs, file names) in `code`.

## Checking

The validator checks references, icons, sides and status values. It cannot check geometry. After
building, open the page in a browser. If you have no browser tool, tell the user to open the HTML
file, step to the busiest step, and look for cut-off text or squeezed arrow labels.

With a browser tool, serve the folder, because `file://` is usually blocked:

```bash
python -m http.server 8765 --bind 127.0.0.1    # run_in_background
```

Then `preview_start` with `http://127.0.0.1:8765/page.html` and resize to about 1300×1000. Jump to
the busiest step and a danger step by clicking the tick buttons, which have the aria-label
`Step N: …`. Wait about 2 seconds for transitions before a screenshot. Then run:

```js
JSON.stringify({
  overflowingNodes: [...document.querySelectorAll('.node')].filter(n => n.scrollWidth > n.clientWidth + 1).map(n => n.dataset.id),
  truncatedChips: [...document.querySelectorAll('.node li .lbl')].filter(l => l.scrollWidth > l.clientWidth + 1).map(l => l.textContent)
})   // both should be empty
```

Also look for edge labels squeezed between adjacent nodes.

Caption check gotcha: every caption is in the DOM at once. The visible one is the `.slide` with
`aria-hidden="false"`, so `.story.textContent` always starts with step 1.

Stop the server and reset the viewport (`resize_window` preset desktop) when done.
