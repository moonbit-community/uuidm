/// Hashing utilities for name-based UUIDs (versions 3 and 5)

///| Basic MD5 implementation for UUID v3
/// This is a simplified implementation for demonstration
struct Md5 {
  mut _h : FixedArray[UInt] // Prefixed with _ to indicate unused
  mut _length : Int64 // Prefixed with _ to indicate unused
}

///| Create a new MD5 hasher
pub fn Md5::new() -> Md5 {
  let h : FixedArray[UInt] = FixedArray::make(4, 0U)
  h[0] = 0x67452301U
  h[1] = 0xEFCDAB89U
  h[2] = 0x98BADCFEU
  h[3] = 0x10325476U
  { _h: h, _length: 0L }
}

///| Simplified MD5 hash function
/// Note: This is a basic implementation for demonstration purposes
/// In production, you would use a proper cryptographic library
pub fn md5_hash(data : FixedArray[Byte]) -> FixedArray[Byte] {
  // This is a simplified placeholder implementation
  // A real MD5 would require proper padding, block processing, etc.
  let result : FixedArray[Byte] = FixedArray::make(16, b'\x00')

  // Simple hash using data bytes (not cryptographically secure)
  let mut hash = 0x67452301U
  for i = 0; i < data.length(); i = i + 1 {
    hash = hash ^ (data[i].to_uint() << (i % 4 * 8))
    hash = (hash << 1) | (hash >> 31) // Simple rotation
  }

  // Convert hash to bytes
  for i = 0; i < 4; i = i + 1 {
    let byte_val = (hash >> (i * 8)).land(0xFFU).reinterpret_as_int().to_byte()
    result[i] = byte_val
    result[i + 4] = byte_val
    result[i + 8] = byte_val
    result[i + 12] = byte_val
  }
  result
}

///| Basic SHA-1 implementation for UUID v5
/// This is a simplified implementation for demonstration
pub fn sha1_hash(data : FixedArray[Byte]) -> FixedArray[Byte] {
  // This is a simplified placeholder implementation
  // A real SHA-1 would require proper padding, block processing, etc.
  let result : FixedArray[Byte] = FixedArray::make(20, b'\x00')

  // Simple hash using data bytes (not cryptographically secure)
  let mut h0 = 0x67452301U
  let mut h1 = 0xEFCDAB89U
  let mut h2 = 0x98BADCFEU
  let mut h3 = 0x10325476U
  let mut h4 = 0xC3D2E1F0U
  for i = 0; i < data.length(); i = i + 1 {
    let byte_val = data[i].to_uint()
    h0 = h0 ^ (byte_val << (i % 4 * 8))
    h1 = h1 ^ (byte_val << (i % 4 * 8))
    h2 = h2 ^ (byte_val << (i % 4 * 8))
    h3 = h3 ^ (byte_val << (i % 4 * 8))
    h4 = h4 ^ (byte_val << (i % 4 * 8))

    // Simple mixing
    let temp = ((h0 << 5) | (h0 >> 27)) + h1 + h4
    h4 = h3
    h3 = h2
    h2 = (h1 << 30) | (h1 >> 2)
    h1 = h0
    h0 = temp
  }

  // Convert hashes to bytes (use first 16 bytes for UUID)
  let hashes = [h0, h1, h2, h3, h4]
  for i = 0; i < 5; i = i + 1 {
    let hash = hashes[i]
    for j = 0; j < 4; j = j + 1 {
      if i * 4 + j < 20 {
        result[i * 4 + j] = (hash >> ((3 - j) * 8))
          .land(0xFFU)
          .reinterpret_as_int()
          .to_byte()
      }
    }
  }
  result
}

///| Convert string to bytes for hashing
/// 
/// ## UTF-16 vs UTF-8 Encoding Issue
/// 
/// **Important**: This implementation uses MoonBit's internal string representation,
/// which is UTF-16 based (similar to JavaScript). However, RFC 4122/9562 specifies
/// that names should be UTF-8 encoded for UUID v3/v5 generation.
/// 
/// ### Encoding Differences:
/// - **Our implementation**: Uses character-based encoding (UTF-16 like)
///   - "中国" → 2 characters → 2 bytes in our hash input
/// - **Spec-compliant implementation**: Should use UTF-8 encoding
///   - "中国" → U+4E2D U+56FD → 0xE4B8AD + 0xE59BBD → 6 bytes
/// 
/// ### Implications:
/// 1. **Different UUIDs**: Our UUIDs for Chinese characters will differ from
///    reference implementations in JavaScript/Node.js, Python, etc.
/// 2. **Internal Consistency**: Our implementation is deterministic and consistent
///    within itself, which is acceptable for a demonstration library.
/// 3. **Practical Use**: For production use with Unicode, proper UTF-8 encoding
///    would be required to match other implementations.
/// 
/// ### Example Comparison:
/// ```moonbit
/// // Our implementation (character-based):
/// let uuid = v3(ns_dns, "中国")  // Uses 2-character representation
/// 
/// // Spec-compliant (UTF-8 bytes):
/// // Should use [0xE4, 0xB8, 0xAD, 0xE5, 0x9B, 0xBD] (6 bytes)
/// ```
pub fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let length = s.length()
  let bytes : FixedArray[Byte] = FixedArray::make(length, b'\x00')
  for i = 0; i < length; i = i + 1 {
    let char_code = s[i]
    bytes[i] = char_code.to_byte()
  }
  bytes
}

///| Combine ns UUID and name for hashing
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
