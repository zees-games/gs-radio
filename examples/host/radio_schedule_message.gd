class_name RadioScheduleMessage
extends GSNetMessage

## The host-side wrapper for [GSRadioReplicator]: one reliable server-to-client dot-net message whose body is the replicator's payload. dot-radio itself has no dot-net dependency, so this lives with the host (here, as the reference one); copy it into a game.

const TYPE := &"radio.schedule"

var payload := PackedByteArray()


func _type_name() -> StringName:
	return TYPE


func _write(writer: GSNetWriter) -> void:
	writer.write_bytes(payload)


func _read(reader: GSNetReader) -> void:
	payload = reader.read_bytes(GSRadioReplicator.MAX_BYTES)


func _validate() -> GSResult:
	if payload.is_empty() or payload.size() > GSRadioReplicator.MAX_BYTES:
		return GSResult.fail(GSError.CODE_INVALID, "radio schedule payload has a bad size", str(payload.size()))
	return GSResult.success(true)


static func make(bytes: PackedByteArray) -> RadioScheduleMessage:
	var m := RadioScheduleMessage.new()
	m.payload = bytes
	return m
