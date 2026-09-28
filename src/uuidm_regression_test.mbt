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

///|
test "regression: v8_mixed stores the suffix in the last 6 bytes" {
  // Found by "qc: v8_mixed stores the 48-bit timestamp and the suffix in the
  // last 6 bytes" (counterexample: timestamp 0, suffix 512): the suffix was
  // shifted as a 32-bit Int by 40 and 32 bits, which wraps to 8 and 0, so
  // octets 10-11 repeated octets 14-15 instead of holding the high bits.
  let b = @uuidm.v8_mixed(0L, 512).bytes()
  @debug.debug_inspect(
    b[10:16].to_owned().map(x => x.to_int()),
    content="[0, 0, 0, 0, 2, 0]",
  )
  let b = @uuidm.v8_mixed(0L, -2).bytes()
  @debug.debug_inspect(
    b[10:16].to_owned().map(x => x.to_int()),
    content="[255, 255, 255, 255, 255, 254]",
  )
}

///|
test "regression: string_to_bytes encodes astral characters as 4-byte UTF-8" {
  // Found by "qc: names are hashed as their UTF-8 encoding" (counterexample:
  // "\u{10FFFF}"): each UTF-16 code unit was encoded on its own, so a
  // surrogate pair became two 3-byte sequences (CESU-8) and v3 / v5 hashed
  // bytes no other implementation produces.
  let hex = (s : String) => {
    @uuidm.string_to_bytes(s)
    .iter()
    .map(b => b.to_int().to_string(radix=16))
    .collect()
  }
  @debug.debug_inspect(
    hex("\u{10FFFF}"),
    content="[\"f4\", \"8f\", \"bf\", \"bf\"]",
  )
  @debug.debug_inspect(hex("😈"), content="[\"f0\", \"9f\", \"98\", \"88\"]")
  // Found by "qc: unpaired surrogates in names are encoded as U+FFFD, like
  // TextEncoder" (counterexample: a lone U+DC00).
  let lone = String::from_array([Int::unsafe_to_char(0xDC00), 'x'])
  @debug.debug_inspect(hex(lone), content="[\"ef\", \"bf\", \"bd\", \"78\"]")
}

///|
test "regression: Uuid does not share its bytes with callers" {
  // Found by "qc: a Uuid is a value: mutating the input or bytes() array
  // does not change it": `Uuid::new` kept the caller's array and `bytes()`
  // handed out the internal one, so e.g. `ns_dns.bytes()[0] = ...` silently
  // changed the global DNS namespace (and every later v3_dns / v5_dns).
  let src : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let u = @uuidm.Uuid::new(src)
  src[0] = b'\xFF'
  inspect(u.is_nil(), content="true")
  let out = @uuidm.ns_dns.bytes()
  out[0] = b'\x00'
  inspect(@uuidm.ns_dns, content="6ba7b810-9dad-11d1-80b4-00c04fd430c8")
}

///|
test "regression: v4_with_rng does not cycle every 16 UUIDs" {
  // Found by "qc: v4_with_rng never repeats a UUID within 256 draws"
  // (counterexample: seed 0): `next_byte` returned the low byte of a
  // mod-2^64 LCG, which has period 256, so the 17th UUID equalled the 1st.
  let rng = @uuidm.SimpleRng::new(0L)
  let first = @uuidm.v4_with_rng(rng)
  for _ in 1..<16 {
    ignore(@uuidm.v4_with_rng(rng))
  }
  let seventeenth = @uuidm.v4_with_rng(rng)
  inspect(first == seventeenth, content="false")
}
