#!/usr/bin/env python3
"""Renders a theme before you install it: a mock Claude window built on the app's own tokens,
before and after, dark and light, with the badge in the band above the prompt.

    python3 preview.py my-brand           # writes preview/my-brand.html; open it in a browser
Run build_theme.py <theme> first.
"""
import html, importlib.util, json, re, sys
from pathlib import Path

HERE = Path(__file__).parent

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path); m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m); return m

bt = load("build_theme", HERE / "build_theme.py")
mb = load("make_badge", HERE / "plugins/skin-badge/make_badge.py")

name = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: preview.py <theme>")
theme = json.loads((HERE / "themes" / f"{name}.json").read_text())
skin = (HERE / "dist" / name / "theme.css").read_text()
css = bt.app_css()
# the app's own token rules: the ramps, .cds-root and its light/dark/system variants
tokens = "\n".join(m.group(0) for m in re.finditer(
    r"(?<=[}\s])[^{}@]*(?:\.cds-root|:where\(:root,:host\))[^{}]*\{\s*--[^{}]*\}", css))
tokens += "\n".join(re.findall(r"@media \(prefers-color-scheme:\s*dark\)\{[^{}]*\.cds-root[^{}]*\{[^{}]*\}\}", css))
b, fonts = theme["badge"], theme.get("fonts", {})
mono = bool(fonts.get("mono"))
font = f"'{fonts['mono']}','SF Mono',monospace" if mono else f"'{fonts.get('sans', 'system-ui')}',system-ui,sans-serif"
badge = mb.badge(b["name"], b.get("sub", ""), b, font, mono)[0]

STYLE = """html,body{margin:0;height:100%}
.app{display:flex;height:100vh;font:15px/1.5 var(--cds-font-sans,-apple-system,system-ui,sans-serif);background:var(--cds-surface-0);color:var(--cds-text-primary)}
aside{width:220px;background:var(--cds-surface-1);border-right:1px solid var(--cds-border);padding:14px 10px;font-size:13px}
.brand{font-weight:600;margin:0 8px 14px}.sess{padding:6px 8px;border-radius:6px;color:var(--cds-text-secondary);display:flex;justify-content:space-between;align-items:center}
.sess.sel{background:var(--cds-fill-ghost-selected);color:var(--cds-text-primary)}.muted{color:var(--cds-text-muted)}
main{flex:1;padding:28px 36px;display:flex;flex-direction:column;gap:12px;max-width:760px}
.user{align-self:flex-end;background:var(--cds-bg-user-message);padding:8px 14px;border-radius:12px}
p{margin:0}a{color:var(--cds-text-accent)}code,.mono,pre{font-family:var(--cds-font-mono)}code{font-size:13px;background:var(--cds-fill-secondary);padding:1px 5px;border-radius:4px}
.tool{font-size:13px;display:flex;gap:8px;align-items:center;padding:8px 10px;border:1px solid var(--cds-border);border-radius:6px;background:var(--cds-surface-1)}
pre{margin:0;font-size:12px;padding:10px;background:var(--cds-surface-2);border-radius:6px;color:var(--cds-text-success)}
.chip{font-size:12px;padding:1px 8px;border-radius:4px;background:var(--cds-fill-secondary)}.chip.ok{color:var(--cds-text-success)}.chip.bad{color:var(--cds-text-danger)}.chip.warn{color:var(--cds-on-warning);background:var(--cds-fill-warning)}
.dot{width:7px;height:7px;border-radius:50%;background:var(--cds-text-success)}
.band{margin-top:auto;height:32px}.composer{border:1px solid var(--cds-border-strong);background:var(--cds-surface-1);border-radius:var(--cds-radius-composer,16px);padding:12px 14px;display:flex;flex-direction:column;gap:14px}
.row{display:flex;justify-content:space-between}button{border:0;width:30px;height:30px;border-radius:6px;background:var(--cds-fill-accent);color:var(--cds-on-accent);font-weight:700}"""

BODY = f"""<div class="cds-root app" data-mode="{{mode}}">
 <aside><div class="brand">Claude</div>
  <div class="sess sel">claude-skin <span class="dot"></span></div>
  <div class="sess">weekly report</div><div class="sess">landing page copy</div><div class="sess muted">archived chat</div></aside>
 <main>
  <div class="user">Make the app mine</div>
  <p>Read <code>--cds-surface-0</code> from <a href="#">app.asar</a>. The theme keeps the app's lightness steps, so contrast holds.</p>
  <div class="tool"><span class="mono">Bash</span> <span class="muted">build_theme.py --check</span> <span class="chip ok">passed</span> <span class="chip bad">1 error</span> <span class="chip warn">review</span></div>
  <pre>15.68  ok   dark text-accent / surface-0</pre>
  <div class="band">{badge}</div>
  <div class="composer"><span class="muted">Reply to Claude...</span><div class="row"><span class="chip">Opus</span><button>&#8593;</button></div></div>
 </main></div>"""

def page(mode, extra):
    return (f"<!doctype html><meta charset=utf-8><style>{tokens}</style><style>{extra}</style>"
            f"<style>{STYLE}</style>{BODY.replace('{mode}', mode)}")

frames = [("Before, dark", page("dark", "")), ("After, dark", page("dark", skin)), ("After, light", page("light", skin))]
out = HERE / "preview" / f"{name}.html"
out.parent.mkdir(exist_ok=True)
out.write_text(
    f"<!doctype html><meta charset=utf-8><title>{html.escape(theme['label'])} skin preview</title>"
    "<style>body{margin:0;padding:16px;background:#111;color:#ccc;font:13px/1.4 -apple-system,system-ui,sans-serif}"
    "figure{margin:0 0 20px}figcaption{margin:0 0 6px;font:500 11px/16px ui-monospace,Menlo,monospace;letter-spacing:.08em;text-transform:uppercase}"
    "iframe{width:100%;max-width:1100px;height:560px;border:1px solid #333;border-radius:6px;display:block}</style>"
    + "".join(f'<figure><figcaption>{c}</figcaption><iframe srcdoc="{html.escape(p)}"></iframe></figure>' for c, p in frames))
print(f"wrote {out}")
