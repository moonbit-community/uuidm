///|
/// Regression tests for bugs found by the property tests in
/// `uuidm_qc_test.mbt`.

///|
test "regression: from_string parses the hex digits" {
  // Found by "qc: from_string inverts to_string and to_string_simple": the
  // parser was a placeholder that ignored the digits and returned a UUID
  // derived from the input length only.
  let u = @uuidm.from_string("550e8400-e29b-41d4-a716-446655440000").unwrap()
  inspect(u, content="550e8400-e29b-41d4-a716-446655440000")
  let v = @uuidm.from_string("550E8400E29B41D4A716446655440000").unwrap()
  inspect(v, content="550e8400-e29b-41d4-a716-446655440000")
  // Found by "qc: from_string rejects mutated UUID strings": any string of
  // length 32 or 36 used to be accepted.
  inspect(
    @uuidm.from_string("00000000f0000f0000f0000f000000000000") is None,
    content="true",
  )
  inspect(
    @uuidm.from_string("zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz") is None,
    content="true",
  )
  inspect(
    @uuidm.from_string("550e8400e-29b-41d4-a716-446655440000") is None,
    content="true",
  )
}
