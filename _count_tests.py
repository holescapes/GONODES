"""Count pass/fail in test_results.txt using raw byte matching."""
data = open("test_results.txt", "rb").read()
pass_marker = b"\xc2\xa3\xc3\xb4"  # pass checkmark
lines = data.split(b"\n")

pass_count = 0
fail_count = 0
fail_names = []
suite_sep = b"\xc3\x96\xc3\x87"  # suite separator chars

for line in lines:
    stripped = line.strip()
    if b"test_" not in stripped:
        continue
    if b"res://" in stripped:
        continue
    if suite_sep in stripped:
        continue
    if pass_marker in stripped:
        pass_count += 1
    else:
        fail_count += 1
        fail_names.append(stripped.decode("utf-8", errors="replace"))

total = pass_count + fail_count
print(f"Pass: {pass_count}, Fail: {fail_count}, Total: {total}")
if fail_names:
    print("\nFailed tests:")
    for name in fail_names:
        print(f"  {name}")
