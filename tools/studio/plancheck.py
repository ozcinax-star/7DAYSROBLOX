# Dev-only: lists every unreachable floor cell, furniture piece, blocked doorway and stair entry in
# all building templates at once, mirroring the Buildings tests in tests/run.luau. Runs without Studio.
# Usage: python tools/studio/plancheck.py src/server/World/BuildingTemplates.luau
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
# Named plan constants (e.g. HOUSE_TWO_STORY) and templates.
blocks = {}
for m in re.finditer(r'local (\w+) = \{\n(.*?)\n\}', src, re.S):
    blocks[m.group(1)] = m.group(2)
templates = {}
body = src[src.index("local BuildingTemplates"):]
for m in re.finditer(r'\n\t(\w+) = \{\n(.*?)\n\t\},', body, re.S):
    name, text = m.group(1), m.group(2)
    fm = re.search(r'floors = (\w+),', text)
    floors_text = blocks[fm.group(1)] if fm else text[text.index("floors = {"):]
    floors = []
    for fb in re.finditer(r'\{\n((?:\s*"[^"]*",\n)+)\s*\}', floors_text):
        floors.append(re.findall(r'"([^"]*)"', fb.group(1)))
    templates[name] = floors
WALLS = set("#WDG")
STAIRS = {"^": (0, -1), "v": (0, 1), "<": (-1, 0), ">": (1, 0)}
FURN = set("bycTUnkgifoaeFtrlphmdAqsCBLxRwH")
def ch(plan, r, c):
    if 1 <= r <= len(plan) and 1 <= c <= len(plan[0]): return plan[r-1][c-1]
    return " "
def stairs(plan):
    seen, out = set(), []
    for r in range(1, len(plan)+1):
        for c in range(1, len(plan[0])+1):
            s = ch(plan, r, c)
            if s in STAIRS and (r, c) not in seen:
                dx, dz = STAIRS[s]; cells = []; rr, cc = r, c
                while ch(plan, rr, cc) == s:
                    seen.add((rr, cc)); cells.append((rr, cc)); rr += abs(dz); cc += abs(dx)
                rising = dx + dz > 0
                low = cells[0] if rising else cells[-1]; high = cells[-1] if rising else cells[0]
                out.append(((low[0]-dz, low[1]-dx), (high[0]+dz, high[1]+dx), cells))
    return out
problems = 0
for name, floors in templates.items():
    plan1 = floors[0]; R, C = len(plan1), len(plan1[0])
    starts = [(r, c) for r in range(1, R+1) for c in range(1, C+1)
              if (r in (1, R) or c in (1, C)) and ch(plan1, r, c) in ".D"]
    holes = set()
    for i, plan in enumerate(floors, 1):
        ok = lambda r, c: ch(plan, r, c) in ".D" and (r, c) not in holes
        reached = set(s for s in starts if ok(*s)); q = list(reached)
        while q:
            r, c = q.pop()
            for dr, dc in ((0,1),(0,-1),(1,0),(-1,0)):
                n = (r+dr, c+dc)
                if ok(*n) and n not in reached: reached.add(n); q.append(n)
        for r in range(1, R+1):
            for c in range(1, C+1):
                x = ch(plan, r, c)
                if ok(r, c) and (r, c) not in reached:
                    print(f"{name} floor {i} ({r},{c}) '{x}' unreachable"); problems += 1
                elif x in FURN and not any((r+dr, c+dc) in reached for dr, dc in ((0,1),(0,-1),(1,0),(-1,0))):
                    print(f"{name} floor {i} ({r},{c}) '{x}' unreachable"); problems += 1
                if x == "D":
                    h = ch(plan, r, c-1) in WALLS or ch(plan, r, c+1) in WALLS
                    v = ch(plan, r-1, c) in WALLS or ch(plan, r+1, c) in WALLS
                    sides = [(r-1, c), (r+1, c)] if h and not v else [(r, c-1), (r, c+1)] if v and not h else []
                    if not sides: print(f"{name} floor {i} ({r},{c}) door not straight"); problems += 1
                    for s in sides:
                        if ch(plan, *s) not in ". D": print(f"{name} floor {i} ({r},{c}) door blocked by {ch(plan, *s)}"); problems += 1
        starts, holes = [], set()
        for entry, exit, cells in stairs(plan):
            if entry not in reached: print(f"{name} floor {i}: stair entry unreachable"); problems += 1
            starts.append(exit); holes |= set(cells)
print(f"{len(templates)} templates, {problems} problems")
