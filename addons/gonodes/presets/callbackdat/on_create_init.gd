# Runs once when the CallbackDAT is first cooked.
# Use to initialize state or create helper nodes.
# Variables: target, event ("create"), event_param (null)

func cook():
	print("[CallbackDAT] Initialized — observing: ", target.id if target else "(none)")
