extends GutTest


func test_runtime_and_owned_queue_release_when_the_last_owner_reference_is_dropped() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var runtime_reference: WeakRef = weakref(runtime)
	var queue_reference: WeakRef = weakref(runtime.followup_queue)
	runtime.reset_run()
	runtime = null
	assert_null(runtime_reference.get_ref(), "The queue relay must not retain its runtime owner.")
	assert_null(queue_reference.get_ref(), "An unowned followup queue must also be released.")


func test_an_external_queue_reference_does_not_keep_the_runtime_alive() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var queue := runtime.followup_queue
	var runtime_reference: WeakRef = weakref(runtime)
	runtime = null
	assert_null(runtime_reference.get_ref())
	assert_eq(queue.request_queued.get_connections().size(), 0, "The released relay target is automatically disconnected.")


func test_queue_relay_is_synchronous_once_and_preserves_request_identity_after_reset() -> void:
	var runtime := MasteryReactiveRuntimeService.new()
	var forwarded: Array[TacticalFollowupRequest] = []
	runtime.tactical_followup_queued.connect(
		func(request: TacticalFollowupRequest) -> void: forwarded.append(request)
	)
	var first := _request(&"first")
	assert_true(runtime.followup_queue.enqueue(first).accepted)
	assert_eq(forwarded.size(), 1, "Accepted requests are forwarded synchronously and exactly once.")
	assert_same(forwarded[0], first, "The relay must not duplicate or transform the request.")
	assert_false(runtime.followup_queue.enqueue(first).accepted)
	assert_eq(forwarded.size(), 1, "Rejected duplicates must not cause an extra emission.")
	runtime.reset_run()
	var second := _request(&"second")
	assert_true(runtime.followup_queue.enqueue(second).accepted)
	assert_eq(forwarded.size(), 2, "Resetting run counters must not remove the relay.")
	assert_same(forwarded[1], second)


func _request(source: StringName) -> TacticalFollowupRequest:
	var request := TacticalFollowupRequest.new()
	request.source_id = source
	request.request_type = TacticalFollowupRequest.TYPE_FREE_MOVE
	request.valid_cells = [Vector2i(2, 3)]
	return request
