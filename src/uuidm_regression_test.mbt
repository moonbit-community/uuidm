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

///|
test "regression: successive v4 / v7 calls return different UUIDs" {
  // Found by "qc: v4 / v4_bulk / v7 produce distinct UUIDs": `random_bytes`
  // re-seeded a fresh generator from its `count` argument on every call, so
  // `v4()` always returned the same UUID, `v4_bulk(n)` n copies of it, and
  // `v7()` (fixed clock) was constant too.
  inspect(@uuidm.v4() == @uuidm.v4(), content="false")
  let bulk = @uuidm.v4_bulk(3)
  inspect(bulk[0] == bulk[1] || bulk[1] == bulk[2], content="false")
  inspect(@uuidm.v7() == @uuidm.v7(), content="false")
  inspect(@uuidm.random_bytes(8) == @uuidm.random_bytes(8), content="false")
}

///|
fn hex_digest(bytes : FixedArray[Byte]) -> String {
  let buf = StringBuilder()
  for b in bytes {
    let x = b.to_int()
    buf.write_char("0123456789abcdef".get_char(x >> 4).unwrap())
    buf.write_char("0123456789abcdef".get_char(x & 0xF).unwrap())
  }
  buf.to_string()
}

///|
test "regression: md5_hash and sha1_hash match the standard test vectors" {
  // md5_hash / sha1_hash were placeholders, so v3 / v5 matched no other
  // implementation (see the RFC 9562 vectors below).
  let ascii = (s : String) => @uuidm.string_to_bytes(s)
  inspect(
    hex_digest(@uuidm.md5_hash(ascii(""))),
    content="d41d8cd98f00b204e9800998ecf8427e",
  )
  inspect(
    hex_digest(@uuidm.md5_hash(ascii("abc"))),
    content="900150983cd24fb0d6963f7d28e17f72",
  )
  inspect(
    hex_digest(@uuidm.md5_hash(ascii("message digest"))),
    content="f96b697d7cb7938d525a2f31aaf161d0",
  )
  inspect(
    hex_digest(@uuidm.sha1_hash(ascii(""))),
    content="da39a3ee5e6b4b0d3255bfef95601890afd80709",
  )
  inspect(
    hex_digest(@uuidm.sha1_hash(ascii("abc"))),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
  // Lengths around the 56- and 64-byte padding boundaries and multi-block
  // messages (expected values from Python's hashlib).
  let expected = [
    (
      55, "52c0e574e1198de5fe3f8f11440dcb1b", "ddf57317ef34bfee3b6df83d359098930eb278bc",
    ),
    (
      56, "46c9907fc908ee68b1e7b8e71286a518", "a0d492bb0fc889d0eca3bc137066ab6f4f74f369",
    ),
    (
      57, "1c805dd236c35cab25fcb1bc73802c51", "11a02dcf95859677a62e75024067c22b165d890f",
    ),
    (
      63, "a62f6d59e837867693f042f5b8f5a236", "c55856749bef509bdfe6bfebfc7bf4e793e82132",
    ),
    (
      64, "7160b8fb5e9e4023d549c3971fbaeead", "bede92be29c3874e1b54ddc77988d606fc857a8e",
    ),
    (
      65, "70bd662e7aefbda85a0f7244167b7897", "b05a80522b053d6dc7e0a517d0e70212c7dad11f",
    ),
    (
      119, "e84905d4214f4d1ca56c2cdcc152b143", "504e27376a6e0f0dba8295b85cb25dc4dfa17d23",
    ),
    (
      120, "e3eb5a6c8669ea01a8c185b8abc8a5dc", "82134b02fb3f702491be9bed581eeab59334acb2",
    ),
    (
      128, "10b2da1a82f16d99a81a7203fe9f02cb", "a09133e6730ffe899efb70204cb5646cd5dc24ee",
    ),
    (
      1000, "10046f077f2082ac19676b8079f1cb1a", "4231a8a50a10fa9758db8ec71fdef855b751048a",
    ),
  ]
  for entry in expected {
    let (len, md5, sha1) = entry
    let data = FixedArray::makei(len, i => ((i * 7 + 3) & 0xFF).to_byte())
    assert_eq(hex_digest(@uuidm.md5_hash(data)), md5)
    assert_eq(hex_digest(@uuidm.sha1_hash(data)), sha1)
  }
}

///|
test "regression: v3 / v5 match RFC 9562 and other implementations" {
  // RFC 9562 appendix A.2 / A.4
  inspect(
    @uuidm.v3_dns("www.example.com"),
    content="5df41881-3aed-3515-88a7-2f4a814cf09e",
  )
  inspect(
    @uuidm.v5_dns("www.example.com"),
    content="2ed6657d-e927-568b-95e1-2665a8aea6a2",
  )
  // Python's uuid module; the last name also needs 4-byte UTF-8
  inspect(
    @uuidm.v3_oid("1.3.6.1"),
    content="dd1a1cef-13d5-368a-ad82-eca71acd4cd1",
  )
  inspect(
    @uuidm.v5_x500("cn=John Smith"),
    content="d1407efb-6828-5023-9fde-962c4ecc2adb",
  )
  inspect(
    @uuidm.v3_url("https://例え.jp/😈"),
    content="cd7e2264-102b-3b45-9bd2-ec7aadeb63f1",
  )
  inspect(
    @uuidm.v5_url("https://例え.jp/😈"),
    content="fbcdc681-f315-5f46-9062-ba5cf21dd237",
  )
  // The placeholder "MD5" was linear in the input bits: equal changes to
  // two bytes 32 positions apart cancelled out, so these two names collided.
  let a = "a" + "x".repeat(31) + "a"
  let b = "b" + "x".repeat(31) + "b"
  inspect(@uuidm.v3_dns(a) == @uuidm.v3_dns(b), content="false")
}
