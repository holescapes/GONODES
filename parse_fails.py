import re

lines = open('test_output.txt', 'r', encoding='utf-8').readlines()

# Find the summary line
for l in lines:
    if 'passed' in l and 'failed' in l:
        print("SUMMARY:", l.strip())

# Find all failure lines - they contain test_xxx::test_yyy and some marker
# Look for lines after "FAILED" summary that list individual failures
in_fail_section = False
fails = []
for l in lines:
    s = l.strip()
    if 'passed' in s and 'failed' in s and 'FAILED' in s:
        in_fail_section = True
        continue
    if in_fail_section:
        m = re.search(r'(test_\w+::test_\w+)', s)
        if m:
            # Truncate
            msg = s[:200] if len(s) > 200 else s
            fails.append(msg)

print(f"\n=== {len(fails)} FAILURES ===")
# Group by suite
groups = {}
for f in fails:
    m = re.search(r'(test_\w+)::', f)
    suite = m.group(1) if m else 'unknown'
    groups.setdefault(suite, []).append(f)

for suite in sorted(groups.keys()):
    items = groups[suite]
    print(f"\n[{suite}] ({len(items)} failures)")
    for item in items:
        print(f"  {item}")
