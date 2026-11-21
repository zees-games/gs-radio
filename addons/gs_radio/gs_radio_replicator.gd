class_name GSRadioReplicator
extends RefCounted

## Pushes the station's schedule to clients over any transport, gs-net included, instead of each client polling `GET /now`. Transport-agnostic on purpose: gs-radio does not depend on gs-net, so the host wraps [method encode]'s bytes in one `GSNetMessage` (TO_CLIENT, RELIABLE) whose body is a byte string, and hands the received bytes to [method GSRadioClient.apply_wire]. Audio still comes over HTTP; only the schedule moves.
##
## Call [method update] from the server's tick. It sends when the station's `rev` changed (track change, queue, playlist, rating) and otherwise every `heartbeat_sec`, so a client that missed one still converges and positions stay anchored.

## Wire format version, first key of every payload.
const VERSION := 1
## Largest payload [method decode] accepts, so a hostile server cannot make a client parse megabytes.
const MAX_BYTES := 4096

var station: GSRadioStation
## Callable(payload: PackedByteArray) -> void, broadcasting to every listener.
var broadcast: Callable
var heartbeat_sec := 5.0
## Override for tests: Callable() -> seconds.
var clock := Callable()

var sent := 0
var _last_rev := -1
var _last_sent := -1000000.0


func _init(p_station: GSRadioStation = null) -> void:
	station = p_station


func update() -> bool:
	if station == null or not broadcast.is_valid():
		return false
	var t := _now()
	if station.rev == _last_rev and t - _last_sent < heartbeat_sec:
		return false
	_last_rev = station.rev
	_last_sent = t
	broadcast.call(encode(station.now_playing()))
	sent += 1
	return true


## The payload for one joining peer: call from the host's peer-connected hook and send to that peer only.
func snapshot() -> PackedByteArray:
	return encode(station.now_playing())


static func encode(now: Dictionary) -> PackedByteArray:
	var d := now.duplicate(true)
	d["v"] = VERSION
	return JSON.stringify(d).to_utf8_buffer()


## The schedule dictionary, or a failure for anything oversized, malformed, of another version, or lacking the fields a client needs.
static func decode(payload: PackedByteArray) -> GSResult:
	if payload.size() > MAX_BYTES:
		return GSResult.fail(GSError.CODE_INVALID, "radio schedule payload too large", str(payload.size()))
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(payload.get_string_from_utf8()) == OK else null
	if not (parsed is Dictionary):
		return GSResult.fail(GSError.CODE_PARSE, "radio schedule payload is not an object")
	var d: Dictionary = parsed
	if int(d.get("v", 0)) != VERSION:
		return GSResult.fail(GSError.CODE_VERSION, "radio schedule version %s is not supported" % str(d.get("v", "none")))
	if not (d.get("id", null) is String):
		return GSResult.fail(GSError.CODE_INVALID, "radio schedule has no id")
	d.erase("v")
	return GSResult.success(d)


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_ticks_msec() / 1000.0
