"""
GONODES Python SDK — write real-time operators in Python with NumPy.

This module is automatically added to sys.path by GNPythonRuntime.
Import it in your operator scripts::

    from gonodes import sop, chop, img, top, dat

Lifecycle functions your module can define:

    def get_port_definitions() -> dict:
        # Return {"ports": [list of port definition dicts]}

    def get_param_definitions() -> dict:
        # Return {"params": [list of param definition dicts]}

    def setup(me: dict, context: dict) -> None:
        # Called once at load and on each script reload.

    def cook(me: dict, params: dict, inputs: list, context: dict) -> dict:
        # Called each frame (or when upstream changes).
        # Return a result dict appropriate for your family.

The ``me`` dict contains:
    me["name"]  — node name in the network
    me["path"]  — filesystem path to this .py file
    me["time"]  — elapsed time in seconds
    me["frame"] — current frame number
    me["delta"] — frame delta time
"""


def make_multi_output(*outputs):
    """Wrap per-port result dicts into multi-output protocol format.

    Each argument should be a result from make_chop_result(),
    make_dat_result(), make_sop_result(), etc.

    Example::

        from gonodes import make_multi_output
        from gonodes.chop import make_chop_result
        from gonodes.dat import make_dat_result

        def cook(me, params, inputs, context):
            chop = make_chop_result({"ch0": np.array([1.0])})
            dat = make_dat_result(rows=[["a", "b"]], header=["x", "y"])
            return make_multi_output(chop, dat)
    """
    return {"outputs": list(outputs)}

__version__ = "0.1.0"

from gonodes.sop import make_sop_result, make_point_cloud
from gonodes.chop import make_chop_result, make_chop_single
from gonodes.img import make_img_result
from gonodes.top import make_top_result
from gonodes.dat import make_dat_result
from gonodes.params import port, param

__all__ = [
    "sop", "chop", "img", "top", "dat",
    "make_sop_result", "make_point_cloud",
    "make_chop_result", "make_chop_single",
    "make_img_result",
    "make_top_result",
    "make_dat_result",
    "port", "param",
]
