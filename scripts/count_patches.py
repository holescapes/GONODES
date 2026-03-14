from pathlib import Path
root = Path('.')
families = {}
for gp in root.rglob('addons/*/help/**/*.gnpatch'):
    fam = gp.parent.name
    families.setdefault(fam, 0)
    families[fam] += 1
for fam in sorted(families.keys()):
    print(f'  {fam:10s}: {families[fam]}')
print(f'  TOTAL     : {sum(families.values())}')
