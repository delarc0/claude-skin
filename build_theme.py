#!/usr/bin/env python3
"""Builds a skin for the Claude desktop app from a theme in themes/<name>.json.

Reads the app's own --cds-* tokens straight out of app.asar, then repaints its ramps:
every step keeps the app's OKLab lightness (so Anthropic's contrast design holds) and
takes its hue and chroma from the theme. Writes dist/<name>/theme.css and
dist/<name>/console-snippet.js (paste it in DevTools > Console).

    python3 build_theme.py lab37-cyberpunk           # build
    python3 build_theme.py my-brand --check          # build and print the contrast table
"""
import json, math, re, struct, sys
from pathlib import Path

ASAR = Path("/Applications/Claude.app/Contents/Resources/app.asar")
HERE = Path(__file__).parent

DARK = ("[data-mode=dark] .cds-root:not([data-mode=light]):not([data-mode=system]),"
        ".cds-root[data-mode=dark],.cds-dark-scope[data-mode=dark]")
SYSTEM = ("[data-mode=system] .cds-root:not([data-mode=light]):not([data-mode=dark]),"
          ".cds-root[data-mode=system],.cds-root:not([data-mode]):not([data-mode] *)")


# --- colour math (OKLab, WCAG) ---------------------------------------------
def _lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def _gam(c): return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def hex_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3: h = "".join(ch * 2 for ch in h)
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]

def to_oklch(h):
    r, g, b = (_lin(c) for c in hex_rgb(h))
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.atan2(bb, a)

def _oklch_rgb(L, C, H):
    a, b = C * math.cos(H), C * math.sin(H)
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)

def _in_gamut(L, C, H): return all(-1e-4 <= v <= 1 + 1e-4 for v in _oklch_rgb(L, C, H))

def from_oklch(L, C, H):
    lo, hi = 0.0, C  # largest chroma still inside sRGB, by bisection
    if _in_gamut(L, hi, H): lo = hi
    for _ in range(30 if lo < C else 0):
        mid = (lo + hi) / 2
        if _in_gamut(L, mid, H): lo = mid
        else: hi = mid
    return "#" + "".join(f"{round(min(1, max(0, _gam(max(0, v)))) * 255):02x}" for v in _oklch_rgb(L, lo, H))

def contrast(a, b):
    ya, yb = (sum(w * _lin(c) for w, c in zip((0.2126, 0.7152, 0.0722), hex_rgb(h))) for h in (a, b))
    return (max(ya, yb) + 0.05) / (min(ya, yb) + 0.05)


# --- the app's tokens ----------------------------------------------------------
def app_css():
    with ASAR.open("rb") as f:
        f.seek(12); hlen = struct.unpack("<I", f.read(4))[0]
        header = json.loads(f.read(hlen)); base = (16 + hlen + 3) & ~3
        stack = [header]
        while stack:
            node = stack.pop()
            for name, v in node.get("files", {}).items():
                if "files" in v: stack.append(v); continue
                if not name.endswith(".css") or v.get("unpacked"): continue
                f.seek(base + int(v["offset"])); data = f.read(v["size"]).decode("utf-8", "replace")
                if "--cds-surface-0:" in data: return data
    sys.exit("no --cds-* stylesheet in app.asar: the app's theme layout changed, re-read it")

def blocks(css):
    """selector -> {token: value}, repeated selectors merged in source order."""
    out = {}
    for sel, body in re.findall(r"([^{}@]+)\{(\s*--[^{}]*)\}", css):
        decls = out.setdefault(sel.strip(), {})
        for d in body.split(";"):
            if d.strip().startswith("--") and ":" in d:
                k, v = d.split(":", 1); decls[k.strip()] = v.strip()
    return out

def chain(token, *scopes):
    """Follows var() through scopes (first scope wins); returns every token visited and the literal."""
    seen = []
    while len(seen) < 20:
        seen.append(token)
        value = next((s[token] for s in scopes if token in s), None)
        m = re.fullmatch(r"var\((--[\w-]+)\)", (value or "").replace("!important", "").strip())
        if not m: return seen, value
        token = m.group(1)
    sys.exit(f"var() loop at {token}")


def build(theme, css):
    b = blocks(css)
    root, light = b[":where(:root,:host)"], b[".cds-root"]
    dark = {**light, **b[DARK.rsplit(",", 1)[0]]}
    ramp = lambda name: {k.rsplit("-", 1)[1]: v for k, v in root.items()
                         if re.fullmatch(rf"--cds-{name}-\d+", k) and v.startswith("#")}
    out = {}

    g = theme["ground"]
    pins = {}
    for tok, pin in (("--cds-surface-0", g.get("deep")), ("--cds-surface-1", g.get("base"))):
        if pin: pins[chain(tok, dark, root)[0][-1]] = pin   # the gray step dark mode reads there
    _, gc, gh = to_oklch(g["hue"])
    for step, hexv in ramp("gray").items():
        L = to_oklch(hexv)[0]
        tok = f"--cds-gray-{step}"
        out[tok] = pins.get(tok) or from_oklch(L, gc * max(0.2, min(1, (0.95 - L) / 0.75)), gh)

    deep_ink = chain("--cds-surface-0", dark, out, root)[1]  # dark mode's page colour, after the repaint
    for role, neon in theme["roles"].items():
        steps = {k.rsplit("-", 1)[1]: v for k, v in root.items() if re.fullmatch(rf"--cds-role-{role}-\d+", k)}
        src = re.fullmatch(r"var\(--cds-([a-z]+)-\d+\)", next(iter(steps.values()), ""))
        if not steps or not src: sys.exit(f"app has no --cds-role-{role}-* ramp on a colour scale")
        src_ramp = ramp(src.group(1))
        # the pure colour goes where dark mode reads this role's text, and its fill when the ink on it still reads
        ink = deep_ink if role == "accent" else chain(f"--cds-on-{role}", dark, root)[1]
        keys = [f"--cds-text-{role}"] + ([f"--cds-fill-{role}"] if contrast(neon, ink) >= 4.5 else [])
        neon_at = {t for k in keys for t in chain(k, dark, root)[0]}
        _, nc, nh = to_oklch(neon)
        for step in steps:
            tok = f"--cds-role-{role}-{step}"
            out[tok] = neon if tok in neon_at else from_oklch(to_oklch(src_ramp[step])[0], nc, nh)
    if "accent" in theme["roles"]:
        out["--cds-role-accent-on"] = deep_ink  # dark ink on the neon fill

    dark_over = {"--cds-text-primary": "var(--cds-gray-100)"}  # LAB37 v4 anti-glare ceiling, L ~ 0.90
    if "accent" in theme["roles"]:
        dark_over["--cds-bg-user-message"] = f"color-mix(in oklab,{theme['roles']['accent']} 8%,transparent)"
    if g.get("raised"):
        dark_over["--cds-surface-3"] = g["raised"]
    return out, dark_over, (root, light, dark)


def check(out, dark_over, scopes):
    root, light, dark = scopes
    val = lambda tok, *s: chain(tok, *s)[1]
    D, Lt = (dark_over, out, dark, root), (out, light, root)
    app = {id(D): (dark, root), id(Lt): (light, root)}  # the same pair before the skin
    pairs = [("dark text-primary / surface-0", D, "--cds-text-primary", "--cds-surface-0", 7),
             ("dark text-secondary / surface-1", D, "--cds-text-secondary", "--cds-surface-1", 4.5),
             ("dark text-muted / surface-1", D, "--cds-text-muted", "--cds-surface-1", 4.5),
             ("light text-primary / surface-0", Lt, "--cds-text-primary", "--cds-surface-0", 7),
             ("light text-muted / surface-0", Lt, "--cds-text-muted", "--cds-surface-0", 4.5)]
    for role in ("accent", "success", "danger", "warning"):
        pairs.append((f"dark text-{role} / surface-0", D, f"--cds-text-{role}", "--cds-surface-0", 4.5))
        pairs.append((f"light text-{role} / surface-0", Lt, f"--cds-text-{role}", "--cds-surface-0", 4.5))
        pairs.append((f"dark on-{role} / fill-{role}", D, f"--cds-on-{role}", f"--cds-fill-{role}", 4.5))
    bad = []
    for label, s, fg, bg, floor in pairs:
        f, b = val(fg, *s), val(bg, *s)
        if not (f or "").startswith("#") or not (b or "").startswith("#"): continue  # not a flat colour
        ratio = contrast(f, b)
        # never fail a pair the app itself ships below the floor (light muted text is ~3.4), only worsening it
        floor = min(floor, contrast(val(fg, *app[id(s)]), val(bg, *app[id(s)])) - 0.05)
        if "--check" in sys.argv: print(f"{ratio:5.2f}  {'ok ' if ratio >= floor else 'LOW'}  {label}  {f} on {b}")
        if ratio < floor: bad.append(f"{label} {ratio:.2f}")
    return bad


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(names) != 1: sys.exit(f"usage: build_theme.py <theme> [--check]; themes: {', '.join(p.stem for p in (HERE / 'themes').glob('*.json'))}")
    name = names[0]
    theme = json.loads((HERE / "themes" / f"{name}.json").read_text())
    out, dark_over, scopes = build(theme, app_css())
    bad = check(out, dark_over, scopes)
    if bad: sys.exit("contrast below floor: " + ", ".join(bad))

    imp = lambda d: ";".join(f"{k}:{v}!important" for k, v in d.items())
    fonts = theme.get("fonts", {})
    base = dict(out)
    if fonts.get("sans"): base["--cds-font-sans"] = f'"{fonts["sans"]}",var(--cds-font-system,system-ui),sans-serif'
    if fonts.get("mono"): base["--cds-font-mono-override"] = f'"{fonts["mono"]}","SF Mono",'  # the app appends its own stack
    base["--cds-radius-composer"] = "8px"
    # .cds-root re-points role-accent at the gray ramp (Claude's accent is neutral), so the ramps
    # land on it too; !important also outranks its inactive-window greying
    css = (f"/* {theme['label']} skin for the Claude app, built by claude-skin/build_theme.py */\n"
           f":root,.cds-root{{{imp(base)}}}\n{DARK}{{{imp(dark_over)}}}\n"
           f"@media (prefers-color-scheme:dark){{{SYSTEM}{{{imp(dark_over)}}}}}\n")
    js = ("(()=>{const id='claude-skin';document.getElementById(id)?.remove();"
          "const s=document.createElement('style');s.id=id;"
          f"s.textContent={json.dumps(css)};document.head.append(s);"
          f"return {json.dumps(theme['label'] + ' skin on: ')}+document.title}})()\n")
    dist = HERE / "dist" / name
    dist.mkdir(parents=True, exist_ok=True)
    (dist / "theme.css").write_text(css)
    (dist / "console-snippet.js").write_text(js)
    print(f"wrote {dist}/theme.css ({len(css)} B) and console-snippet.js")


if __name__ == "__main__":
    main()
