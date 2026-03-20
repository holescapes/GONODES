"""
CSV Parse DAT — Example: Parse CSV text into a structured table.

Demonstrates:
  - Reading text input from upstream DAT
  - Parsing CSV without external libraries (stdlib csv module)
  - Outputting structured table data with header
"""

from gonodes.dat import make_dat_result, get_input_text
from gonodes.params import input_port, output_port, string_param, bool_param
import csv
import io


def get_port_definitions():
    return {"ports": [
        input_port("in", "DAT", label="Raw CSV text"),
        output_port("out", "DAT", label="Parsed table"),
    ]}


def get_param_definitions():
    return {"params": [
        string_param("delimiter", ",", "Delimiter",
                      "Column separator character."),
        bool_param("has_header", True, "Has Header",
                    "First row is a header row."),
        string_param("fallback_csv", "name,value\nalpha,1\nbeta,2\ngamma,3",
                      "Fallback CSV",
                      "Used when no input is connected."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    text = get_input_text(inputs, 0)
    if not text:
        text = params.get("fallback_csv", "")
    if not text:
        return make_dat_result(rows=[], header=[])

    delimiter = params.get("delimiter", ",")
    if len(delimiter) != 1:
        delimiter = ","
    has_header = params.get("has_header", True)

    reader = csv.reader(io.StringIO(text), delimiter=delimiter)
    all_rows = list(reader)

    header = None
    rows = all_rows
    if has_header and all_rows:
        header = all_rows[0]
        rows = all_rows[1:]

    return make_dat_result(rows=rows, header=header)
