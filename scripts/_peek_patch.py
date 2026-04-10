import json, sys
path = sys.argv[1]
p = json.load(open(path))
for nid, nd in p["nodes"].items():
    t = nd.get("type", "?")
    print(f"  {nid}: {t}")
print("---")
anns = p.get("annotations", [])
if anns:
    print(anns[0].get("text", "NO TEXT")[:80])
else:
    print("NO ANNOTATIONS")
