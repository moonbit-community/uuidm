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

///|
test "regression: from_urn requires the urn:uuid: prefix" {
  // Found by "qc: from_urn inverts to_urn and requires the urn:uuid: prefix":
  // the first 9 characters were dropped without being looked at.
  let s = "550e8400-e29b-41d4-a716-446655440000"
  inspect(@uuidm.from_urn("xxxxxxxxx" + s) is None, content="true")
  inspect(@uuidm.from_urn("urn:uuid-" + s) is None, content="true")
  inspect(@uuidm.from_urn("urn:uuid:" + s).unwrap(), content=s)
  inspect(@uuidm.from_urn("URN:UUID:" + s).unwrap(), content=s)
}

///|
test "regression: variant distinguishes Microsoft and reserved UUIDs" {
  // Found by "qc: variant and version decode the RFC 9562 bit layout": the
  // variant was read from the top 2 bits of octet 8 only, so 0b110 and 0b111
  // were reported as RFC 9562 (and got a version).
  let microsoft = @uuidm.from_string("00000000-0000-4000-c000-000000000000").unwrap()
  inspect(microsoft.variant(), content="Microsoft")
  inspect(microsoft.version() is None, content="true")
  let reserved = @uuidm.from_string("00000000-0000-4000-e000-000000000000").unwrap()
  inspect(reserved.variant(), content="Reserved")
  let rfc = @uuidm.from_string("00000000-0000-4000-bf00-000000000000").unwrap()
  inspect(rfc.variant(), content="Rfc9562")
  let ncs = @uuidm.from_string("00000000-0000-4000-7f00-000000000000").unwrap()
  inspect(ncs.variant(), content="Ncs")
}
