"""
gonodes.dat — DAT family helpers.

Builds result dicts for table/text data.
"""


def make_dat_result(rows=None, text=None, header=None):
    """Build a DAT result dictionary.

    For table data:
        make_dat_result(rows=[["a","b"],["c","d"]], header=["col1","col2"])

    For text data:
        make_dat_result(text="Hello, world!")

    Args:
        rows:   list of lists (2D table).
        text:   raw text string (mutually exclusive with rows).
        header: optional list of column names.

    Returns:
        dict ready for the C++ bridge.
    """
    result = {}
    if text is not None:
        result["text"] = str(text)
        result["mode"] = "text"
    else:
        result["mode"] = "table"
        result["rows"] = rows or []
        if header is not None:
            result["header"] = list(header)
        result["num_rows"] = len(result["rows"])
        result["num_cols"] = len(result["rows"][0]) if result["rows"] else 0
    return result


def get_input_table(inputs, index=0):
    """Get input DAT as (header, rows).

    Returns:
        tuple(list[str] | None, list[list[str]]) or (None, []).
    """
    if index >= len(inputs) or inputs[index] is None:
        return None, []
    d = inputs[index]
    header = d.get("header", None)
    rows = d.get("rows", [])
    return header, rows


def get_input_text(inputs, index=0):
    """Get input DAT as raw text string."""
    if index >= len(inputs) or inputs[index] is None:
        return ""
    return inputs[index].get("text", "")
