"""DAT Template — Minimal table/text processor."""

from gonodes.dat import make_dat_result, get_input_table
from gonodes.params import input_port, output_port


def get_port_definitions():
    return {"ports": [
        input_port("in", "DAT", label="Input table"),
        output_port("out", "DAT", label="Output table"),
    ]}


def get_param_definitions():
    return {"params": []}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    header, rows = get_input_table(inputs, 0)
    # Process rows here
    return make_dat_result(rows=rows, header=header)
