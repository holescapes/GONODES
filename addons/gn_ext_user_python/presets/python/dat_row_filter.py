"""
Row Filter DAT — Example: Filter table rows by pattern matching.

Demonstrates:
  - Reading input DAT table with get_input_table()
  - String matching and filtering
  - Outputting filtered DAT table
"""

from gonodes.dat import make_dat_result, get_input_table
from gonodes.params import input_port, output_port, string_param, int_param, bool_param


def get_port_definitions():
    return {"ports": [
        input_port("in", "DAT", required=True, label="Input table"),
        output_port("out", "DAT", label="Filtered table"),
    ]}


def get_param_definitions():
    return {"params": [
        string_param("pattern", "", "Pattern",
                      "Text to match against column values (case-insensitive)."),
        int_param("column", 0, 0, 100, "Column",
                   "Column index to match against (0-based)."),
        bool_param("invert", False, "Invert",
                    "Discard matching rows instead of keeping them."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    pattern = params.get("pattern", "")
    col = int(params.get("column", 0))
    invert = params.get("invert", False)

    result = get_input_table(inputs, 0)
    if result is None:
        return {}

    header, rows = result
    pat_lower = pattern.lower()

    filtered = []
    for row in rows:
        match = False
        if col < len(row):
            match = pat_lower in row[col].lower()

        keep = (not match) if invert else match
        if not pattern:
            keep = True  # empty pattern = pass all rows

        if keep:
            filtered.append(row)

    return make_dat_result(rows=filtered, header=header)
