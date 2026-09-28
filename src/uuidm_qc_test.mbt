///|
/// Property-based tests for `bobzhang/uuidm`, driven by
/// `moonbitlang/core/quickcheck`.
///
/// Contracts exercised (from the README, the doc comments and RFC 9562):
/// - `to_string` / `to_string_simple` / `to_urn` round-trip through
///   `from_string` / `from_urn`, case-insensitively, and the parsers reject
///   anything that is not a 32-digit or 8-4-4-4-12 hex string, without
///   panicking;
/// - `Uuid::new` / `from_bytes` / `bytes` round-trip and `Uuid` behaves as a
///   value (mutating arrays passed in or handed out does not change it);
/// - ordering is the unsigned lexicographic order of the 16 bytes;
/// - `variant` / `version` decode the RFC 9562 bit layout;
/// - every generator sets the RFC 9562 variant and its own version and keeps
///   the caller-provided fields;
/// - v3 / v5 are deterministic and name-sensitive, and hash the UTF-8
///   encoding of the name;
/// - v7 timestamps round-trip through `extract_timestamp` and order the UUIDs;
/// - random UUIDs (v4) do not repeat.

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

///|
/// 16 raw bytes. Mostly uniform, sometimes built from bytes that sit on the
/// variant / version bit boundaries (and nil / max).
priv struct B16 {
  bytes : Array[Byte]
} derive(Debug, Eq)

///|
fn B16::uuid(self : B16) -> @uuidm.Uuid {
  @uuidm.Uuid::new(FixedArray::from_array(self.bytes))
}

///|
fn b16_gen() -> @qc.Generator[B16] {
  let boundary : @qc.Generator[Byte] = @qc.elements([
    b'\x00', b'\xFF', b'\x7F', b'\x80', b'\xBF', b'\xC0', b'\xDF', b'\xE0', b'\x3F',
    b'\x40',
  ])
  @qc.frequency([
    (6, @qc.spawn().array_with_size(16)),
    (2, boundary.array_with_size(16)),
    (1, @qc.pure(Array::make(16, b'\x00'))),
    (1, @qc.pure(Array::make(16, b'\xFF'))),
  ]).map(bytes => { bytes, })
}

///|
impl @qc.Arbitrary for B16 with fn arbitrary(size, rs) {
  b16_gen().run(size, rs)
}

///|
/// Keeps the length at 16: first zero whole bytes, then shrink single bytes.
impl @qc.Shrink for B16 with fn shrink(self) {
  let out : Array[B16] = []
  for i, b in self.bytes {
    if b != b'\x00' {
      let bytes = self.bytes.copy()
      bytes[i] = b'\x00'
      out.push({ bytes, })
    }
  }
  for i, b in self.bytes {
    for smaller in @qc.Shrink::shrink(b) {
      if smaller != b'\x00' {
        let bytes = self.bytes.copy()
        bytes[i] = smaller
        out.push({ bytes, })
      }
    }
  }
  out.iter()
}

///|
/// Characters for names hashed by v3 / v5: ASCII, BMP (incl. neighbours of
/// the surrogate block) and astral characters.
fn name_char_gen() -> @qc.Generator[Char] {
  @qc.frequency([
    (8, @qc.char_range('a', 'z')),
    (2, @qc.elements(['.', '-', '/', ':', '0', '9', ' ', '\u{0}', '\u{7F}'])),
    (2, @qc.elements(['\u{80}', 'é', '\u{7FF}', '\u{800}', '中', '\u{D7FF}'])),
    (1, @qc.elements(['\u{E000}', '\u{FFFD}', '\u{FFFF}'])),
    (2, @qc.elements(['😈', '𝄞', '\u{10000}', '\u{10FFFF}'])),
    (1, @qc.spawn()),
  ])
}

///|
/// A well-formed (surrogate-pair-correct) name.
priv struct Name {
  chars : Array[Char]
} derive(Debug, Eq)

///|
fn Name::text(self : Name) -> String {
  String::from_array(self.chars)
}

///|
impl @qc.Arbitrary for Name with fn arbitrary(size, rs) {
  let gen = @qc.sized(size => {
    @qc.int_range(0, size + 1).flat_map(n => name_char_gen().array_with_size(n))
  })
  { chars: gen.run(size, rs), }
}

///|
impl @qc.Shrink for Name with fn shrink(self) {
  @qc.Shrink::shrink(self.chars).map(chars => { chars, })
}

///|
fn has_astral(s : String) -> Bool {
  for c in s {
    if c.to_int() > 0xFFFF {
      return true
    }
  }
  false
}

///|
fn has_non_ascii(s : String) -> Bool {
  for c in s {
    if c.to_int() > 0x7F {
      return true
    }
  }
  false
}

///|
fn to_array(bytes : FixedArray[Byte]) -> Array[Byte] {
  let out = []
  for b in bytes {
    out.push(b)
  }
  out
}

///|
/// Unsigned lexicographic comparison of two equal-length byte arrays,
/// normalised to -1 / 0 / 1.
fn lex_compare(a : Array[Byte], b : Array[Byte]) -> Int {
  for i in 0..<a.length() {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  0
}

///|
/// `k mod n` in `[0, n)`, also for negative `k` (and `Int::min_value`).
fn non_negative_mod(k : Int, n : Int) -> Int {
  (k % n + n) % n
}

///|
fn sign(x : Int) -> Int {
  if x < 0 {
    -1
  } else if x > 0 {
    1
  } else {
    0
  }
}

///|
fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Reference acceptance predicate for `from_string`: 32 hex digits, or the
/// 8-4-4-4-12 hyphenated form.
fn reference_valid(s : String) -> Bool {
  let chars = s.to_array()
  if s.length() != chars.length() {
    return false // contains astral characters
  }
  match chars.length() {
    32 => chars.iter().all(is_hex_digit)
    36 =>
      chars
      .iter()
      .mapi((i, c) => {
        if i == 8 || i == 13 || i == 18 || i == 23 {
          c == '-'
        } else {
          is_hex_digit(c)
        }
      })
      .all(ok => ok)
    _ => false
  }
}

///|
fn ascii_lower(s : String) -> String {
  String::from_array(
    s
    .to_array()
    .map(c => {
      if c >= 'A' && c <= 'Z' {
        Int::unsafe_to_char(c.to_int() + 32)
      } else {
        c
      }
    }),
  )
}

///|
fn ascii_upper(s : String) -> String {
  String::from_array(
    s
    .to_array()
    .map(c => {
      if c >= 'a' && c <= 'z' {
        Int::unsafe_to_char(c.to_int() - 32)
      } else {
        c
      }
    }),
  )
}

///|
fn remove_hyphens(s : String) -> String {
  String::from_array(s.to_array().filter(c => c != '-'))
}

///|
/// A valid UUID string (hyphenated or simple) and a mutation
/// that must make it invalid.
priv struct Malformed {
  uuid : B16
  simple : Bool
  kind : Int
  pos : Int
  ch : Char
} derive(Debug)

///|
impl @qc.Arbitrary for Malformed with fn arbitrary(size, rs) {
  let uuid : B16 = @qc.Arbitrary::arbitrary(size, rs)
  let simple : Bool = @qc.Arbitrary::arbitrary(size, rs)
  let kind = @qc.int_range(0, 6).run(size, rs)
  let pos = @qc.int_range(0, 36).run(size, rs)
  let ch = @qc.elements([
    'g', 'G', 'z', 'x', ' ', '_', '{', '}', '+', '\u{0}', 'é', '０', '😈',
  ]).run(size, rs)
  { uuid, simple, kind, pos, ch, }
}

///|
impl @qc.Shrink for Malformed with fn shrink(self) {
  @qc.Shrink::shrink(self.uuid).map(uuid => { ..self, uuid, })
}

///|
fn Malformed::render(self : Malformed) -> String {
  let base = if self.simple {
    self.uuid.uuid().to_string_simple()
  } else {
    self.uuid.uuid().to_string()
  }
  let chars = base.to_array()
  let n = chars.length()
  let pos = self.pos % n
  match self.kind {
    // replace one digit with a non-hex character
    0 => {
      let pos = if chars[pos] == '-' { pos + 1 } else { pos }
      chars[pos] = self.ch
    }
    // delete one character
    1 => chars.remove(pos) |> ignore
    // insert one character (a hex digit, so only the length is wrong)
    2 => chars.insert(pos, 'a')
    // swap a hyphen with its neighbour (hyphenated form) / insert a hyphen
    // into a digit run (simple form), keeping length 36 when possible
    3 =>
      if self.simple {
        chars.insert(pos, '-')
      } else {
        let h = [8, 13, 18, 23][pos % 4]
        chars[h] = chars[h + 1]
        chars[h + 1] = '-'
      }
    // truncate
    4 => chars.truncate(pos % n)
    // replace every hyphen by a digit (36 digits) / append 4 digits
    _ =>
      if self.simple {
        chars.append(['0', '1', '2', '3'])
      } else {
        for i in [8, 13, 18, 23] {
          chars[i] = 'f'
        }
      }
  }
  String::from_array(chars)
}

///|
/// Strings that look a lot like UUIDs: length 32 or 36 (or close to it),
/// made of hex digits with the odd hyphen / stray character.
priv struct NearUuid {
  chars : Array[Char]
} derive(Debug)

///|
impl @qc.Arbitrary for NearUuid with fn arbitrary(size, rs) {
  // Noise level per string: clean hex strings are valid about half the
  // time, noisy ones exercise the rejection paths.
  let noise = @qc.elements([0, 0, 1, 20]).run(size, rs)
  let c = @qc.frequency([
    (200, @qc.elements("0123456789abcdefABCDEF".to_array())),
    (noise.reinterpret_as_uint(), @qc.pure('-')),
    (
      noise.reinterpret_as_uint(),
      @qc.elements(['g', ' ', '{', '}', 'é', '😈', '\u{0}']),
    ),
  ])
  let len = @qc.frequency([
    (4, @qc.pure(36)),
    (4, @qc.pure(32)),
    (1, @qc.int_range(0, 40)),
  ]).run(size, rs)
  let chars = c.array_with_size(len).run(size, rs)
  // Put hyphens where they belong in most 36-character candidates.
  if len == 36 && rs.next_uint(limit=4) != 0 {
    for i in [8, 13, 18, 23] {
      chars[i] = '-'
    }
  }
  { chars, }
}

///|
impl @qc.Shrink for NearUuid with fn shrink(self) {
  @qc.Shrink::shrink(self.chars).map(chars => { chars, })
}

// ---------------------------------------------------------------------------
// String conversions
// ---------------------------------------------------------------------------

///|
test "qc: to_string has the 8-4-4-4-12 lowercase layout and agrees with to_string_simple" {
  @qc.check(
    (b : B16) => {
      let u = b.uuid()
      let s = u.to_string()
      let simple = u.to_string_simple()
      s.length() == 36 &&
      reference_valid(s) &&
      ascii_lower(s) == s &&
      remove_hyphens(s) == simple &&
      simple.length() == 32 &&
      u.to_urn() == "urn:uuid:" + s &&
      u.to_string() == "\{u}"
    },
    seed=0x5eed_0001,
  )
}

///|
test "qc: from_string inverts to_string and to_string_simple, in any case" {
  @qc.check(
    (b : B16) => {
      let u = b.uuid()
      let s = u.to_string()
      let simple = u.to_string_simple()
      @uuidm.from_string(s) == Some(u) &&
      @uuidm.from_string(simple) == Some(u) &&
      @uuidm.from_string(ascii_upper(s)) == Some(u) &&
      @uuidm.from_string(ascii_upper(simple)) == Some(u) &&
      @uuidm.from_string_exn(s) == u
    },
    observe=b => {
      let s = b.uuid().to_string()
      [@qc.classify(s != ascii_upper(s), "has a-f digits")]
    },
    seed=0x5eed_0002,
  )
}

///|
test "qc: from_urn inverts to_urn and requires the urn:uuid: prefix" {
  @qc.check(
    (input : (B16, Int)) => {
      let (b, k) = input
      let u = b.uuid()
      let s = u.to_string()
      let bad_prefix = [
          "urn:uuid-", "urn:uuix:", "xxxxxxxxx", "urn:oid::", "urn:uuid", "",
        ][non_negative_mod(k, 6)]
      @uuidm.from_urn(u.to_urn()) == Some(u) &&
      @uuidm.from_urn("URN:UUID:" + ascii_upper(s)) == Some(u) &&
      @uuidm.from_urn_exn(u.to_urn()) == u &&
      @uuidm.from_urn(bad_prefix + s) is None &&
      @uuidm.from_urn(s) is None
    },
    seed=0x5eed_0003,
  )
}

///|
test "qc: from_string rejects mutated UUID strings" {
  @qc.check(
    (m : Malformed) => @uuidm.from_string(m.render()) is None,
    observe=m => {
      [
        @qc.label(
          [
            "bad digit", "deletion", "insertion", "misplaced hyphen", "truncation",
            "hyphens replaced / too long",
          ][m.kind],
        ),
        @qc.classify(m.simple, "simple form"),
      ]
    },
    counterexample_context=m => m.render(),
    count=500,
    seed=0x5eed_0004,
  )
}

///|
test "qc: from_string accepts exactly the reference grammar on near-UUID strings" {
  @qc.check(
    (n : NearUuid) => {
      let s = String::from_array(n.chars)
      match @uuidm.from_string(s) {
        Some(u) =>
          reference_valid(s) &&
          u.to_string_simple() == ascii_lower(remove_hyphens(s))
        None => !reference_valid(s)
      }
    },
    observe=n => {
      let s = String::from_array(n.chars)
      [@qc.classify(reference_valid(s), "valid"), @qc.collect(s.length())]
    },
    counterexample_context=n => String::from_array(n.chars),
    count=500,
    seed=0x5eed_0005,
  )
}

///|
test "qc: from_string and from_urn never panic on arbitrary strings" {
  @qc.check(
    (s : String) => {
      let ok1 = match @uuidm.from_string(s) {
        Some(u) =>
          reference_valid(s) &&
          u.to_string_simple() == ascii_lower(remove_hyphens(s))
        None => !reference_valid(s)
      }
      let ok2 = match @uuidm.from_urn("urn:uuid:" + s) {
        Some(u) => @uuidm.from_string(s) == Some(u)
        None => @uuidm.from_string(s) is None
      }
      // `from_urn` on the raw string must not panic either (for example when
      // offset 9 falls inside a surrogate pair).
      let _ = @uuidm.from_urn(s)
      ok1 && ok2
    },
    count=500,
    seed=0x5eed_0006,
  )
}

// ---------------------------------------------------------------------------
// Bytes, equality, ordering
// ---------------------------------------------------------------------------

///|
test "qc: new / from_bytes / bytes round-trip and nil / max detection" {
  @qc.check(
    (b : B16) => {
      let arr = b.bytes
      let u = b.uuid()
      let v = @uuidm.Uuid::from_bytes(
        arr[0],
        arr[1],
        arr[2],
        arr[3],
        arr[4],
        arr[5],
        arr[6],
        arr[7],
        arr[8],
        arr[9],
        arr[10],
        arr[11],
        arr[12],
        arr[13],
        arr[14],
        arr[15],
      )
      to_array(u.bytes()) == arr &&
      u == v &&
      u.is_nil() == arr.iter().all(x => x == b'\x00') &&
      u.is_max() == arr.iter().all(x => x == b'\xFF') &&
      (u == @uuidm.nil()) == u.is_nil() &&
      (u == @uuidm.max()) == u.is_max()
    },
    observe=b => {
      [
        @qc.classify(b.uuid().is_nil(), "nil"),
        @qc.classify(b.uuid().is_max(), "max"),
      ]
    },
    seed=0x5eed_0007,
  )
}

///|
test "qc: a Uuid is a value: mutating the input or bytes() array does not change it" {
  @qc.check(
    (input : (B16, Int)) => {
      let (b, k) = input
      let i = non_negative_mod(k, 16)
      let src = FixedArray::from_array(b.bytes)
      let u = @uuidm.Uuid::new(src)
      let before = u.to_string()
      src[i] = src[i] ^ b'\xFF'
      let out = u.bytes()
      out[(i + 1) % 16] = out[(i + 1) % 16] ^ b'\xFF'
      u.to_string() == before && to_array(u.bytes()) == b.bytes
    },
    count=200,
    seed=0x5eed_0008,
  )
}

///|
test "qc: compare / equality follow unsigned byte order and string order" {
  @qc.check(
    (pair : (B16, B16)) => {
      let (a, b) = pair
      let ua = a.uuid()
      let ub = b.uuid()
      let expected = lex_compare(a.bytes, b.bytes)
      sign(ua.compare(ub)) == expected &&
      sign(ub.compare(ua)) == -expected &&
      (ua == ub) == (expected == 0) &&
      (ua < ub) == (expected < 0) &&
      (ua <= ub) == (expected <= 0) &&
      sign(ua.to_string().compare(ub.to_string())) == expected
    },
    observe=pair => [@qc.collect(lex_compare(pair.0.bytes, pair.1.bytes))],
    count=300,
    seed=0x5eed_0009,
  )
}

// ---------------------------------------------------------------------------
// Variant and version
// ---------------------------------------------------------------------------

///|
/// RFC 9562 section 4.1, table 1.
fn reference_variant(b8 : Byte) -> String {
  let x = b8.to_int()
  if (x & 0x80) == 0 {
    "Ncs"
  } else if (x & 0xC0) == 0x80 {
    "Rfc9562"
  } else if (x & 0xE0) == 0xC0 {
    "Microsoft"
  } else {
    "Reserved"
  }
}

///|
fn version_string(u : @uuidm.Uuid) -> String? {
  u.version().map(v => v.to_string())
}

///|
test "qc: variant and version decode the RFC 9562 bit layout" {
  @qc.check(
    (b : B16) => {
      let u = b.uuid()
      let variant = reference_variant(b.bytes[8])
      let nibble = b.bytes[6].to_int() >> 4
      let version = if variant == "Rfc9562" && nibble >= 1 && nibble <= 8 {
        Some("V\{nibble}")
      } else {
        None
      }
      u.variant().to_string() == variant && version_string(u) == version
    },
    observe=b => [@qc.label(reference_variant(b.bytes[8]))],
    count=400,
    seed=0x5eed_000a,
  )
}

///|
/// The generated UUID carries the RFC 9562 variant bits (10) and `version` in
/// the high nibble of octet 6, both in the bits and as decoded.
fn has_version(u : @uuidm.Uuid, version : Int) -> Bool {
  let b = u.bytes()
  b[6].to_int() >> 4 == version &&
  b[8].to_int() >> 6 == 2 &&
  u.variant().to_string() == "Rfc9562" &&
  version_string(u) == Some("V\{version}")
}

///|
test "qc: v8 sets version 8 / RFC variant and keeps the other 122 bits" {
  @qc.check(
    (b : B16) => {
      let data = FixedArray::from_array(b.bytes)
      let u = @uuidm.v8(data)
      let out = u.bytes()
      let mut same = true
      for i in 0..<16 {
        if i != 6 && i != 8 && out[i] != b.bytes[i] {
          same = false
        }
      }
      has_version(u, 8) &&
      same &&
      (out[6] & b'\x0F') == (b.bytes[6] & b'\x0F') &&
      (out[8] & b'\x3F') == (b.bytes[8] & b'\x3F') &&
      @uuidm.extract_custom_data(u).map(to_array) == Some(to_array(out)) &&
      data
      .iter()
      .zip(b.bytes.iter())
      .all(p => p.0 == p.1) // input untouched
    },
    seed=0x5eed_000b,
  )
}

///|
fn be_int64(b : FixedArray[Byte], start : Int, len : Int) -> Int64 {
  let mut x = 0L
  for i in start..<(start + len) {
    x = (x << 8) | b[i].to_int64()
  }
  x
}

///|
fn masked_eq(a : Int64, b : Int64, mask : Int64) -> Bool {
  ((a ^ b) & mask) == 0L
}

///|
test "qc: v8_from_int128 and v8_counter store their fields big-endian" {
  @qc.check(
    (input : (Int64, Int64, Int, Int)) => {
      let (hi, lo, node, app) = input
      let u = @uuidm.v8_from_int128(hi, lo)
      let b = u.bytes()
      let c = @uuidm.v8_counter(hi, node, app)
      let cb = c.bytes()
      has_version(u, 8) &&
      has_version(c, 8) &&
      masked_eq(be_int64(b, 0, 8), hi, 0xFFFF_FFFF_FFFF_0FFFL) &&
      masked_eq(be_int64(b, 8, 8), lo, 0x3FFF_FFFF_FFFF_FFFFL) &&
      masked_eq(be_int64(cb, 0, 8), hi, 0xFFFF_FFFF_FFFF_0FFFL) &&
      masked_eq(be_int64(cb, 8, 4), node.to_int64(), 0x3FFF_FFFFL) &&
      be_int64(cb, 12, 4) == (app.to_int64() & 0xFFFF_FFFFL)
    },
    seed=0x5eed_000c,
  )
}

///|
test "qc: v8_mixed stores the 48-bit timestamp and the suffix in the last 6 bytes" {
  @qc.check(
    (input : (Int64, Int)) => {
      let (ts, suffix) = input
      let ts = ts & 0xFFFF_FFFF_FFFFL
      let u = @uuidm.v8_mixed(ts, suffix)
      let b = u.bytes()
      has_version(u, 8) &&
      be_int64(b, 0, 6) == ts &&
      // the suffix is an `Int`, stored as a 48-bit two's-complement value
      be_int64(b, 10, 6) == (suffix.to_int64() & 0xFFFF_FFFF_FFFFL)
    },
    observe=input => [@qc.classify(input.1 < 0, "negative suffix")],
    seed=0x5eed_000d,
  )
}

// ---------------------------------------------------------------------------
// v3 / v5
// ---------------------------------------------------------------------------

///|
test "qc: v3 / v5 are deterministic, versioned and consistent with the helpers" {
  @qc.check(
    (input : (B16, Name)) => {
      let (ns, name) = input
      let ns = ns.uuid()
      let name = name.text()
      let a3 = @uuidm.v3(ns, name)
      let a5 = @uuidm.v5(ns, name)
      a3 == @uuidm.v3(ns, name) &&
      a5 == @uuidm.v5(ns, name) &&
      has_version(a3, 3) &&
      has_version(a5, 5) &&
      a3 != a5 &&
      @uuidm.v3_dns(name) == @uuidm.v3(@uuidm.ns_dns, name) &&
      @uuidm.v3_url(name) == @uuidm.v3(@uuidm.ns_url, name) &&
      @uuidm.v3_oid(name) == @uuidm.v3(@uuidm.ns_oid, name) &&
      @uuidm.v3_x500(name) == @uuidm.v3(@uuidm.ns_x500, name) &&
      @uuidm.v5_dns(name) == @uuidm.v5(@uuidm.ns_dns, name) &&
      @uuidm.v5_url(name) == @uuidm.v5(@uuidm.ns_url, name) &&
      @uuidm.v5_oid(name) == @uuidm.v5(@uuidm.ns_oid, name) &&
      @uuidm.v5_x500(name) == @uuidm.v5(@uuidm.ns_x500, name)
    },
    observe=input => {
      let name = input.1.text()
      [
        @qc.classify(name == "", "empty name"),
        @qc.classify(has_non_ascii(name), "non-ASCII name"),
        @qc.classify(has_astral(name), "astral name"),
      ]
    },
    count=200,
    seed=0x5eed_000e,
  )
}

///|
test "qc: v3 / v5 differ for different names and different namespaces" {
  @qc.check(
    (input : (B16, B16, Name, Name)) => {
      let (ns1, ns2, n1, n2) = input
      let (ns1, ns2) = (ns1.uuid(), ns2.uuid())
      let (n1, n2) = (n1.text(), n2.text())
      (
        n1 == n2 ||
        (
          @uuidm.v3(ns1, n1) != @uuidm.v3(ns1, n2) &&
          @uuidm.v5(ns1, n1) != @uuidm.v5(ns1, n2)
        )
      ) &&
      (
        ns1 == ns2 ||
        (
          @uuidm.v3(ns1, n1) != @uuidm.v3(ns2, n1) &&
          @uuidm.v5(ns1, n1) != @uuidm.v5(ns2, n1)
        )
      )
    },
    observe=input => {
      [
        @qc.classify(input.2 == input.3, "same name"),
        @qc.classify(input.0 == input.1, "same namespace"),
      ]
    },
    count=300,
    seed=0x5eed_000f,
  )
}

///|
test "qc: names are hashed as their UTF-8 encoding" {
  @qc.check(
    (input : (B16, Name)) => {
      let (ns, name) = input
      let name = name.text()
      let expected = @utf8.encode(name).to_array()
      let combined = @uuidm.combine_namespace_and_name(ns.uuid(), name)
      to_array(@uuidm.string_to_bytes(name)) == expected &&
      to_array(combined) == ns.bytes + expected
    },
    observe=input => [@qc.classify(has_astral(input.1.text()), "astral name")],
    seed=0x5eed_0010,
  )
}

///|
test "qc: unpaired surrogates in names are encoded as U+FFFD, like TextEncoder" {
  @qc.check(
    (input : (Name, Int, Bool)) => {
      let (name, k, high) = input
      let surrogate = if high {
        0xD800 + non_negative_mod(k, 0x400)
      } else {
        0xDC00 + non_negative_mod(k, 0x400)
      }
      // `prefix + surrogate + "x"` cannot form a valid pair: the character
      // before the surrogate is a whole scalar value and the one after is 'x'.
      let prefix = name.text()
      let buf = StringBuilder()
      buf.write_string(prefix)
      buf.write_char(Int::unsafe_to_char(surrogate))
      buf.write_char('x')
      let s = buf.to_string()
      let expected = @utf8.encode(prefix).to_array() +
        [b'\xEF', b'\xBF', b'\xBD', b'x']
      to_array(@uuidm.string_to_bytes(s)) == expected
    },
    count=100,
    seed=0x5eed_0011,
  )
}

// ---------------------------------------------------------------------------
// v7
// ---------------------------------------------------------------------------

///|
priv struct Ts {
  ms : Int64
} derive(Debug)

///|
impl @qc.Arbitrary for Ts with fn arbitrary(size, rs) {
  let max = 0xFFFF_FFFF_FFFFL
  let ms = @qc.frequency([
    (
      6,
      @qc.Generator((_, rs) => {
        rs
        .next_uint64(limit=(max + 1L).reinterpret_as_uint64())
        .reinterpret_as_int64()
      }),
    ),
    (
      2,
      @qc.elements([
        0L,
        1L,
        255L,
        256L,
        0xFFFF_FFFFL,
        0x1_0000_0000L,
        max - 1L,
        max,
        1640995200000L,
      ]),
    ),
    (2, @qc.int_range(0, 1000).map(x => x.to_int64())),
  ]).run(size, rs)
  { ms, }
}

///|
impl @qc.Shrink for Ts with fn shrink(self) {
  @qc.Shrink::shrink(self.ms).filter(ms => ms >= 0L).map(ms => { ms, })
}

///|
test "qc: extract_timestamp inverts v7_with_timestamp on 48-bit timestamps" {
  @qc.check(
    (t : Ts) => {
      let u = @uuidm.v7_with_timestamp(t.ms)
      has_version(u, 7) && @uuidm.extract_timestamp(u) == Some(t.ms)
    },
    seed=0x5eed_0012,
  )
}

///|
test "qc: v7 UUIDs are ordered by their timestamps" {
  @qc.check(
    (pair : (Ts, Ts)) => {
      let (a, b) = pair
      let ua = @uuidm.v7_with_timestamp(a.ms)
      let ub = @uuidm.v7_with_timestamp(b.ms)
      a.ms == b.ms || (a.ms < b.ms) == (ua < ub)
    },
    observe=pair => [@qc.classify(pair.0.ms == pair.1.ms, "equal timestamps")],
    seed=0x5eed_0013,
  )
}

///|
test "qc: v7_sequence is strictly increasing with consecutive timestamps" {
  @qc.check(
    (n : Int) => {
      let n = non_negative_mod(n, 64)
      let seq = @uuidm.v7_sequence(n)
      let mut ok = seq.length() == n
      for i in 0..<seq.length() {
        ok = ok && has_version(seq[i], 7)
        if i > 0 {
          ok = ok &&
            seq[i - 1] < seq[i] &&
            @uuidm.extract_timestamp(seq[i]).unwrap() ==
            @uuidm.extract_timestamp(seq[i - 1]).unwrap() + 1L
        }
      }
      ok
    },
    count=50,
    seed=0x5eed_0014,
  )
}

///|
test "qc: extract_timestamp / extract_custom_data only answer for their versions" {
  @qc.check(
    (b : B16) => {
      let u = b.uuid()
      let v = version_string(u)
      (@uuidm.extract_timestamp(u) is Some(_)) == (v == Some("V7")) &&
      (@uuidm.extract_custom_data(u) is Some(_)) == (v == Some("V8"))
    },
    seed=0x5eed_0015,
  )
}

// ---------------------------------------------------------------------------
// v4
// ---------------------------------------------------------------------------

///|
fn all_distinct(xs : Array[@uuidm.Uuid]) -> Bool {
  let seen : Map[String, Bool] = Map([])
  for x in xs {
    let k = x.to_string()
    if seen.contains(k) {
      return false
    }
    seen[k] = true
  }
  true
}

///|
test "qc: v4_with_rng never repeats a UUID within 256 draws" {
  @qc.check(
    (seed : Int64) => {
      let rng = @uuidm.SimpleRng::new(seed)
      let xs = Array::makei(256, _ => @uuidm.v4_with_rng(rng))
      xs.iter().all(u => has_version(u, 4)) && all_distinct(xs)
    },
    count=30,
    seed=0x5eed_0016,
  )
}

///|
test "qc: v4 / v4_bulk / v7 produce distinct UUIDs" {
  @qc.check(
    (n : Int) => {
      let n = 2 + non_negative_mod(n, 40)
      let bulk = @uuidm.v4_bulk(n)
      let singles = Array::makei(n, _ => @uuidm.v4())
      let v7s = Array::makei(n, _ => @uuidm.v7())
      bulk.length() == n &&
      bulk.iter().all(u => has_version(u, 4)) &&
      all_distinct(bulk + singles) &&
      v7s.iter().all(u => has_version(u, 7)) &&
      all_distinct(v7s)
    },
    count=30,
    seed=0x5eed_0017,
  )
}
