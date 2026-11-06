extends RefCounted
## Reads touches straight from the browser on the web build.
## Godot's own touch events do not reliably reach the game in iOS Safari, so the page records
## touches itself and the game picks them up each frame. Positions come back as fractions of the
## canvas, so they work whatever the page's pixel ratio or the stretch settings are.

const INSTALL := """
(function () {
	if (window.__bbTouch) return;
	var state = { queue: [], last: 0 };
	window.__bbTouch = state;
	function canvas() { return document.querySelector('canvas'); }
	function record(type, e) {
		var c = canvas();
		if (!c) return;
		var r = c.getBoundingClientRect();
		state.last = performance.now();
		for (var i = 0; i < e.changedTouches.length; i++) {
			var t = e.changedTouches[i];
			state.queue.push([type, t.identifier, (t.clientX - r.left) / r.width, (t.clientY - r.top) / r.height]);
		}
	}
	var options = { capture: true, passive: true };
	window.addEventListener('touchstart', function (e) { record('start', e); }, options);
	window.addEventListener('touchmove', function (e) { record('move', e); }, options);
	window.addEventListener('touchend', function (e) { record('end', e); }, options);
	window.addEventListener('touchcancel', function (e) { record('end', e); }, options);
})();
"""

## Godot's own copy of a touch is dropped for this long after the browser reported one.
const OVERLAP_MS := 800.0

var active := false
var _finger := -1


func _init() -> void:
	active = OS.has_feature("web")
	if active:
		JavaScriptBridge.eval(INSTALL, true)


## The touches since the last call, as [type, position] pairs, following one finger at a time.
func take(view: Vector2) -> Array:
	var found: Array = []
	if not active:
		return found
	var raw = JavaScriptBridge.eval("JSON.stringify(window.__bbTouch ? window.__bbTouch.queue.splice(0) : [])", true)
	if typeof(raw) != TYPE_STRING:
		return found
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return found
	for entry in parsed:
		var type := String(entry[0])
		var finger := int(entry[1])
		var at := Vector2(float(entry[2]) * view.x, float(entry[3]) * view.y)
		if type == "start":
			if _finger != -1:
				continue
			_finger = finger
		elif finger != _finger:
			continue
		elif type == "end":
			_finger = -1
		found.append([type, at])
	return found


## Whether the browser saw a real touch just now, so Godot's own report of it would be a duplicate.
func touched_recently() -> bool:
	if not active:
		return false
	var since = JavaScriptBridge.eval("window.__bbTouch ? performance.now() - window.__bbTouch.last : 1e9", true)
	return typeof(since) in [TYPE_FLOAT, TYPE_INT] and float(since) < OVERLAP_MS
