/// Hashing utilities for name-based UUIDs (versions 3 and 5)

///|
/// Basic MD5 implementation for UUID v3
/// This is a simplified implementation for demonstration
struct Md5 {
  mut _h : FixedArray[UInt] // Prefixed with _ to indicate unused
  mut _length : Int64 // Prefixed with _ to indicate unused
}

///|
/// Create a new MD5 hasher
pub fn Md5::new() -> Md5 {
  let h : FixedArray[UInt] = FixedArray::make(4, 0U)
  h[0] = 0x67452301U
  h[1] = 0xEFCDAB89U
  h[2] = 0x98BADCFEU
  h[3] = 0x10325476U
  { _h: h, _length: 0L, }
}

///|
/// Left-rotate a 32-bit word
fn rotl32(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

///|
/// Pad a message as MD5 and SHA-1 require: a 0x80 byte, zeros up to 56 mod 64
/// bytes, then the message length in bits as a 64-bit integer (little-endian
/// for MD5, big-endian for SHA-1).
fn pad_message(data : FixedArray[Byte], big_endian : Bool) -> FixedArray[Byte] {
  let len = data.length()
  let padded_len = (len + 8) / 64 * 64 + 64
  let padded : FixedArray[Byte] = FixedArray::make(padded_len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    padded[i] = data[i]
  }
  padded[len] = b'\x80'
  let bit_len = len.to_int64() * 8L
  for i = 0; i < 8; i = i + 1 {
    let byte = (bit_len >> (i * 8)).land(0xFFL).to_int().to_byte()
    if big_endian {
      padded[padded_len - 1 - i] = byte
    } else {
      padded[padded_len - 8 + i] = byte
    }
  }
  padded
}

///|
/// MD5 per-round shift amounts (RFC 1321)
let md5_shifts : FixedArray[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
/// MD5 constants: floor(abs(sin(i + 1)) * 2^32) (RFC 1321)
let md5_table : FixedArray[UInt] = [
  0xD76AA478U, 0xE8C7B756U, 0x242070DBU, 0xC1BDCEEEU, 0xF57C0FAFU, 0x4787C62AU, 0xA8304613U,
  0xFD469501U, 0x698098D8U, 0x8B44F7AFU, 0xFFFF5BB1U, 0x895CD7BEU, 0x6B901122U, 0xFD987193U,
  0xA679438EU, 0x49B40821U, 0xF61E2562U, 0xC040B340U, 0x265E5A51U, 0xE9B6C7AAU, 0xD62F105DU,
  0x02441453U, 0xD8A1E681U, 0xE7D3FBC8U, 0x21E1CDE6U, 0xC33707D6U, 0xF4D50D87U, 0x455A14EDU,
  0xA9E3E905U, 0xFCEFA3F8U, 0x676F02D9U, 0x8D2A4C8AU, 0xFFFA3942U, 0x8771F681U, 0x6D9D6122U,
  0xFDE5380CU, 0xA4BEEA44U, 0x4BDECFA9U, 0xF6BB4B60U, 0xBEBFBC70U, 0x289B7EC6U, 0xEAA127FAU,
  0xD4EF3085U, 0x04881D05U, 0xD9D4D039U, 0xE6DB99E5U, 0x1FA27CF8U, 0xC4AC5665U, 0xF4292244U,
  0x432AFF97U, 0xAB9423A7U, 0xFC93A039U, 0x655B59C3U, 0x8F0CCC92U, 0xFFEFF47DU, 0x85845DD1U,
  0x6FA87E4FU, 0xFE2CE6E0U, 0xA3014314U, 0x4E0811A1U, 0xF7537E82U, 0xBD3AF235U, 0x2AD7D2BBU,
  0xEB86D391U,
]

///|
/// MD5 digest (RFC 1321), 16 bytes
pub fn md5_hash(data : FixedArray[Byte]) -> FixedArray[Byte] {
  let msg = pad_message(data, false)
  let mut a0 = 0x67452301U
  let mut b0 = 0xEFCDAB89U
  let mut c0 = 0x98BADCFEU
  let mut d0 = 0x10325476U
  let m : FixedArray[UInt] = FixedArray::make(16, 0U)
  for chunk = 0; chunk < msg.length(); chunk = chunk + 64 {
    for i = 0; i < 16; i = i + 1 {
      let j = chunk + i * 4
      m[i] = msg[j].to_uint() |
        (msg[j + 1].to_uint() << 8) |
        (msg[j + 2].to_uint() << 16) |
        (msg[j + 3].to_uint() << 24)
    }
    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0
    for i = 0; i < 64; i = i + 1 {
      let (f, g) = if i < 16 {
        ((b & c) | ((b ^ 0xFFFFFFFFU) & d), i)
      } else if i < 32 {
        ((d & b) | ((d ^ 0xFFFFFFFFU) & c), (5 * i + 1) % 16)
      } else if i < 48 {
        (b ^ c ^ d, (3 * i + 5) % 16)
      } else {
        (c ^ (b | (d ^ 0xFFFFFFFFU)), 7 * i % 16)
      }
      let f = f + a + md5_table[i] + m[g]
      a = d
      d = c
      c = b
      b = b + rotl32(f, md5_shifts[i])
    }
    a0 = a0 + a
    b0 = b0 + b
    c0 = c0 + c
    d0 = d0 + d
  }
  let result : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let words = [a0, b0, c0, d0]
  for i = 0; i < 4; i = i + 1 {
    for j = 0; j < 4; j = j + 1 {
      result[i * 4 + j] = (words[i] >> (j * 8))
        .land(0xFFU)
        .reinterpret_as_int()
        .to_byte()
    }
  }
  result
}

///|
/// SHA-1 digest (FIPS 180-4), 20 bytes
pub fn sha1_hash(data : FixedArray[Byte]) -> FixedArray[Byte] {
  let msg = pad_message(data, true)
  let mut h0 = 0x67452301U
  let mut h1 = 0xEFCDAB89U
  let mut h2 = 0x98BADCFEU
  let mut h3 = 0x10325476U
  let mut h4 = 0xC3D2E1F0U
  let w : FixedArray[UInt] = FixedArray::make(80, 0U)
  for chunk = 0; chunk < msg.length(); chunk = chunk + 64 {
    for i = 0; i < 16; i = i + 1 {
      let j = chunk + i * 4
      w[i] = (msg[j].to_uint() << 24) |
        (msg[j + 1].to_uint() << 16) |
        (msg[j + 2].to_uint() << 8) |
        msg[j + 3].to_uint()
    }
    for i = 16; i < 80; i = i + 1 {
      w[i] = rotl32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    for i = 0; i < 80; i = i + 1 {
      let (f, k) = if i < 20 {
        ((b & c) | ((b ^ 0xFFFFFFFFU) & d), 0x5A827999U)
      } else if i < 40 {
        (b ^ c ^ d, 0x6ED9EBA1U)
      } else if i < 60 {
        ((b & c) | (b & d) | (c & d), 0x8F1BBCDCU)
      } else {
        (b ^ c ^ d, 0xCA62C1D6U)
      }
      let temp = rotl32(a, 5) + f + e + k + w[i]
      e = d
      d = c
      c = rotl32(b, 30)
      b = a
      a = temp
    }
    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e
  }
  let result : FixedArray[Byte] = FixedArray::make(20, b'\x00')
  let words = [h0, h1, h2, h3, h4]
  for i = 0; i < 5; i = i + 1 {
    for j = 0; j < 4; j = j + 1 {
      result[i * 4 + j] = (words[i] >> ((3 - j) * 8))
        .land(0xFFU)
        .reinterpret_as_int()
        .to_byte()
    }
  }
  result
}

///|
/// Convert a Unicode code point to UTF-8 bytes
/// Returns the UTF-8 byte sequence for a given Unicode code point
fn encode_utf8_codepoint(codepoint : Int) -> Array[Byte] {
  let bytes : Array[Byte] = []
  if codepoint <= 0x7F {
    // 1-byte sequence: 0xxxxxxx
    bytes.push(codepoint.to_byte())
  } else if codepoint <= 0x7FF {
    // 2-byte sequence: 110xxxxx 10xxxxxx
    bytes.push((0xC0 | (codepoint >> 6)).to_byte())
    bytes.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else if codepoint <= 0xFFFF {
    // 3-byte sequence: 1110xxxx 10xxxxxx 10xxxxxx
    bytes.push((0xE0 | (codepoint >> 12)).to_byte())
    bytes.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    bytes.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else if codepoint <= 0x10FFFF {
    // 4-byte sequence: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    bytes.push((0xF0 | (codepoint >> 18)).to_byte())
    bytes.push((0x80 | ((codepoint >> 12) & 0x3F)).to_byte())
    bytes.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    bytes.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else {
    // Invalid code point, use replacement character (U+FFFD)
    bytes.push(b'\xEF') // 0xEF
    bytes.push(b'\xBF') // 0xBF
    bytes.push(b'\xBD') // 0xBD
  }
  bytes
}

///|
/// Convert string to UTF-8 bytes for hashing (RFC 4122/9562 compliant)
/// 
/// ## UTF-8 Encoding Implementation
/// 
/// This implementation now properly converts strings to UTF-8 bytes as required
/// by RFC 4122/9562 for UUID v3/v5 generation. This matches the behavior of
/// reference implementations in JavaScript/Node.js, Python, etc.
/// 
/// ### UTF-8 Encoding Rules:
/// - ASCII (U+0000-U+007F): 1 byte
/// - U+0080-U+07FF: 2 bytes  
/// - U+0800-U+FFFF: 3 bytes (includes most Chinese characters)
/// - U+10000-U+10FFFF: 4 bytes
/// 
/// ### Examples:
/// - "hello" → [0x68, 0x65, 0x6C, 0x6C, 0x6F] (5 bytes)
/// - "中" (U+4E2D) → [0xE4, 0xB8, 0xAD] (3 bytes)
/// - "国" (U+56FD) → [0xE5, 0x9B, 0xBD] (3 bytes)
/// - "中国" → [0xE4, 0xB8, 0xAD, 0xE5, 0x9B, 0xBD] (6 bytes)
/// 
/// This now matches JavaScript's `new TextEncoder().encode(string)` behavior.
/// 
/// ## Spec Compliance Achievement! 🎉
/// 
/// This implementation is now **RFC 4122/9562 compliant** for UTF-8 encoding!
/// UUIDs generated with Chinese characters should now match reference implementations
/// in JavaScript/Node.js, Python, and other spec-compliant libraries (assuming the
/// same MD5/SHA-1 implementation).
pub fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let utf8_bytes : Array[Byte] = []

  // Convert each character to its UTF-8 byte sequence. The string is UTF-16:
  // a surrogate pair is one code point, and an unpaired surrogate becomes
  // U+FFFD (as `TextEncoder` does).
  let mut i = 0
  while i < s.length() {
    let mut codepoint = s.code_unit_at(i).to_int()
    if codepoint >= 0xD800 && codepoint <= 0xDBFF && i + 1 < s.length() {
      let low = s.code_unit_at(i + 1).to_int()
      if low >= 0xDC00 && low <= 0xDFFF {
        codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00)
        i = i + 1
      }
    }
    if codepoint >= 0xD800 && codepoint <= 0xDFFF {
      codepoint = 0xFFFD
    }
    i = i + 1
    let char_bytes = encode_utf8_codepoint(codepoint)

    // Add all bytes from this character to the result
    for j = 0; j < char_bytes.length(); j = j + 1 {
      utf8_bytes.push(char_bytes[j])
    }
  }

  // Convert Array to FixedArray
  let result : FixedArray[Byte] = FixedArray::make(utf8_bytes.length(), b'\x00')
  for i = 0; i < utf8_bytes.length(); i = i + 1 {
    result[i] = utf8_bytes[i]
  }
  result
}

///|
/// Combine ns UUID and name for hashing
pub fn combine_namespace_and_name(ns : Uuid, name : String) -> FixedArray[Byte] {
  let ns_bytes = ns.bytes()
  let name_bytes = string_to_bytes(name)
  let total_length = 16 + name_bytes.length()
  let combined : FixedArray[Byte] = FixedArray::make(total_length, b'\x00')

  // Copy namespace bytes
  for i = 0; i < 16; i = i + 1 {
    combined[i] = ns_bytes[i]
  }

  // Copy name bytes
  for i = 0; i < name_bytes.length(); i = i + 1 {
    combined[16 + i] = name_bytes[i]
  }
  combined
}
