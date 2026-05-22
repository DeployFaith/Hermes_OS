class_name HermesOperationRouter
extends RefCounted

const HermesProtocol = preload("res://scripts/hermes/hermes_protocol.gd")

var _kernel: Node

func setup(kernel: Node) -> void:
	_kernel = kernel

func execute(op: String, args: Dictionary, request_id := "") -> Dictionary:
	if _kernel == null:
		return {
			"ok": false,
			"error": HermesProtocol.make_error("KERNEL_UNAVAILABLE", "Kernel is not attached to operation router")
		}
	if op.begins_with("os."):
		return _kernel.route_os_operation(op, args, request_id)
	if op.begins_with("game."):
		return _kernel.route_game_operation(op, args, request_id)
	return _kernel.route_shell_operation(op, args, request_id)
