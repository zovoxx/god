#!/usr/bin/env python3
"""Dev helper: GDScript refuses `var x := <untyped expression>`. This finds every such
error reported by check_all and drops the inference (`:=` -> `=`) on that line. Run from the
project root: python3 tools/fix_inference.py [path-to-godot]"""
import re, subprocess, sys, os
godot = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/bin/godot")
for it in range(15):
    out = subprocess.run([godot, "--headless", "--path", ".", "-s", "tools/check_all.gd"], capture_output=True, text=True).stdout
    errs = set(re.findall(r'ERROR: res://(\S+?):(\d+) Parse Error: (?:Cannot infer the type of "\w+"|The variable type is being inferred from a Variant)', out))
    if not errs:
        rest = sorted(set(l for l in out.splitlines() if l.startswith("ERROR: res://")))
        print("no inference errors left" + ("; other errors:\n" + "\n".join(rest) if rest else ""))
        break
    for f, l in errs:
        lines = open(f).read().split("\n")
        i = int(l) - 1
        lines[i] = re.sub(r'\b(var|const|for)\s+(\w+)\s*:=', r'\1 \2 =', lines[i], count=1)
        open(f, "w").write("\n".join(lines))
    print("fixed", len(errs))
