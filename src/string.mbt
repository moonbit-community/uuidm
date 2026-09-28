/// String conversion utilities for UUIDs

///|
/// Convert a byte to a two-character hexadecimal string
fn byte_to_hex(b : Byte) -> String {
  let high = (b.to_int() >> 4) & 0xF
  let low = b.to_int() & 0xF
  let high_char = if high < 10 {
    '0'.to_int() + high
  } else {
    'a'.to_int() + high - 10
  }
  let low_char = if low < 10 {
    '0'.to_int() + low
  } else {
    'a'.to_int() + low - 10
  }
  Int::unsafe_to_char(high_char).to_string() +
  Int::unsafe_to_char(low_char).to_string()
}

///|
/// Convert a hexadecimal character to its numeric value
fn hex_char_to_int(c : Char) -> Int {
  let code = c.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    code - 'A'.to_int() + 10
  } else {
    abort("Invalid hexadecimal character: " + c.to_string())
  }
}

///|
/// Convert two hexadecimal characters to a byte
/// Note: Currently unused but kept for future string parsing improvements
fn _hex_to_byte(h : Char, l : Char) -> Byte {
  let high = hex_char_to_int(h)
  let low = hex_char_to_int(l)
  (high << 4).lor(low).to_byte()
}

///|
/// Convert UUID to string representation with hyphens
/// Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
pub fn Uuid::to_string(self : Uuid) -> String {
  let bytes = self.0
  byte_to_hex(bytes[0]) +
  byte_to_hex(bytes[1]) +
  byte_to_hex(bytes[2]) +
  byte_to_hex(bytes[3]) +
  "-" +
  byte_to_hex(bytes[4]) +
  byte_to_hex(bytes[5]) +
  "-" +
  byte_to_hex(bytes[6]) +
  byte_to_hex(bytes[7]) +
  "-" +
  byte_to_hex(bytes[8]) +
  byte_to_hex(bytes[9]) +
  "-" +
  byte_to_hex(bytes[10]) +
  byte_to_hex(bytes[11]) +
  byte_to_hex(bytes[12]) +
  byte_to_hex(bytes[13]) +
  byte_to_hex(bytes[14]) +
  byte_to_hex(bytes[15])
}

///|
/// Convert UUID to string representation without hyphens
pub fn Uuid::to_string_simple(self : Uuid) -> String {
  let bytes = self.0
  let mut result = ""
  for i = 0; i < 16; i = i + 1 {
    result = result + byte_to_hex(bytes[i])
  }
  result
}

///|
/// Value of an ASCII hexadecimal digit given as a UTF-16 code unit, or -1.
fn hex_digit_value(code : Int) -> Int {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    code - '0'.to_int()
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    code - 'a'.to_int() + 10
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    code - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
/// Parse UUID from string representation
/// Accepts both hyphenated (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) and
/// non-hyphenated (32 hex digits) formats; hex digits may be in either case.
/// Returns `None` for anything else.
pub fn from_string(s : String) -> Uuid? {
  // Must be exactly 32 hex characters (without hyphens) or 36 (with hyphens)
  let hyphenated = s.length() == 36
  if s.length() != 32 && !hyphenated {
    return None
  }
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let mut pos = 0
  for i = 0; i < 16; i = i + 1 {
    // Hyphens come before octets 4, 6, 8 and 10 (8-4-4-4-12 layout)
    if hyphenated && (i == 4 || i == 6 || i == 8 || i == 10) {
      if s.code_unit_at(pos).to_int() != '-'.to_int() {
        return None
      }
      pos = pos + 1
    }
    let high = hex_digit_value(s.code_unit_at(pos).to_int())
    let low = hex_digit_value(s.code_unit_at(pos + 1).to_int())
    if high < 0 || low < 0 {
      return None
    }
    bytes[i] = ((high << 4) | low).to_byte()
    pos = pos + 2
  }
  Some(Uuid::new(bytes))
}

///|
/// Parse UUID from string, panics on invalid input
pub fn from_string_exn(s : String) -> Uuid {
  match from_string(s) {
    Some(uuid) => uuid
    None => abort("Invalid UUID string: " + s)
  }
}

///|
/// Convert UUID to URN string representation
/// Format: urn:uuid:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
pub fn Uuid::to_urn(self : Uuid) -> String {
  "urn:uuid:" + self.to_string()
}

///|
/// Parse UUID from URN string representation
/// The `urn:uuid:` prefix is required (matched case-insensitively) and must be
/// followed by a string accepted by `from_string`.
pub fn from_urn(s : String) -> Uuid? {
  let prefix = "urn:uuid:"
  if s.length() <= prefix.length() {
    return None
  }
  for i = 0; i < prefix.length(); i = i + 1 {
    let code = s.code_unit_at(i).to_int()
    let lower = if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      code + 32
    } else {
      code
    }
    if lower != prefix.code_unit_at(i).to_int() {
      return None
    }
  }
  // The prefix is ASCII, so offset 9 is a character boundary.
  from_string(s[prefix.length():].to_owned())
}

///|
/// Parse UUID from URN string, panics on invalid input
pub fn from_urn_exn(s : String) -> Uuid {
  match from_urn(s) {
    Some(uuid) => uuid
    None => abort("Invalid UUID URN: " + s)
  }
}
