/// Universally Unique Identifiers (UUIDs) for MoonBit
/// 
/// This library implements UUID versions 3, 4, 5, 7, and 8 according to RFC 9562.
/// UUIDs are 128-bit identifiers that are unique across both space and time.

///| A UUID is represented as 16 bytes (128 bits)
struct Uuid {
  bytes : FixedArray[Byte]
} derive(Eq, Compare)


///| Show the UUID as a string which conforms to the UUID format (8-4-4-4-12) 
/// # Example
/// ```
/// let uuid = Uuid::from_bytes(b'\x7F', b'\xAA', b'\x02', b'\x93', b'\x7F', b'\xAA', b'\x32', b'\x93', b'\xBF', b'\xAA', b'\x02', b'\x93', b'\x7F', b'\xAA', b'\x02', b'\x93')
/// println(uuid) // Output: 7faa0293-7faa-3293-bfaa-02937faa0293
/// ```
pub impl Show for Uuid with output(self, logger) {
  logger.write_string(self.to_string())
}
///| UUID variant as defined in RFC 9562
enum Variant {
  /// Reserved for NCS compatibility (0b0xx)
  Ncs
  /// RFC 9562 variant (0b10x) 
  Rfc9562
  /// Reserved for Microsoft compatibility (0b110)
  Microsoft
  /// Reserved for future definition (0b111)
  Reserved
} derive(Eq, Show)

///| UUID version as defined in RFC 9562
enum Version {
  /// Version 1: Time-based (deprecated)
  V1
  /// Version 2: DCE Security (deprecated) 
  V2
  /// Version 3: Name-based using MD5 hashing
  V3
  /// Version 4: Random or pseudo-random
  V4
  /// Version 5: Name-based using SHA-1 hashing
  V5
  /// Version 6: Reordered time-based (draft)
  V6
  /// Version 7: Time-ordered random
  V7
  /// Version 8: Custom format
  V8
} derive(Eq, Show)

///| Create a new UUID from 16 bytes
pub fn Uuid::new(bytes : FixedArray[Byte]) -> Uuid {
  if bytes.length() != 16 {
    abort("UUID must be exactly 16 bytes")
  }
  { bytes, }
}

///| Create a UUID from individual byte values
pub fn Uuid::from_bytes(
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
  b4 : Byte,
  b5 : Byte,
  b6 : Byte,
  b7 : Byte,
  b8 : Byte,
  b9 : Byte,
  b10 : Byte,
  b11 : Byte,
  b12 : Byte,
  b13 : Byte,
  b14 : Byte,
  b15 : Byte,
) -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  bytes[0] = b0
  bytes[1] = b1
  bytes[2] = b2
  bytes[3] = b3
  bytes[4] = b4
  bytes[5] = b5
  bytes[6] = b6
  bytes[7] = b7
  bytes[8] = b8
  bytes[9] = b9
  bytes[10] = b10
  bytes[11] = b11
  bytes[12] = b12
  bytes[13] = b13
  bytes[14] = b14
  bytes[15] = b15
  { bytes, }
}

///| Get the raw bytes of the UUID
pub fn bytes(self : Uuid) -> FixedArray[Byte] {
  self.bytes
}

///| Get the variant of the UUID
pub fn variant(self : Uuid) -> Variant {
  let bits = self.bytes[8].to_int() >> 6
  match bits {
    0 | 1 => Variant::Ncs
    2 | 3 => Variant::Rfc9562
    6 => Variant::Microsoft
    7 => Variant::Reserved
    _ => Variant::Reserved // Should not happen
  }
}

///| Get the version of the UUID (only meaningful for RFC 9562 variant)
pub fn version(self : Uuid) -> Version? {
  if self.variant() != Variant::Rfc9562 {
    None
  } else {
    let version_bits = self.bytes[6].to_int() >> 4
    match version_bits {
      1 => Some(Version::V1)
      2 => Some(Version::V2)
      3 => Some(Version::V3)
      4 => Some(Version::V4)
      5 => Some(Version::V5)
      6 => Some(Version::V6)
      7 => Some(Version::V7)
      8 => Some(Version::V8)
      _ => None
    }
  }
}

///| Set the variant and version bits for an RFC 9562 UUID
fn set_variant_and_version(bytes : FixedArray[Byte], version : Version) -> Unit {
  // Set variant bits (bits 6-7 of octet 8) to 10 (RFC 9562)
  bytes[8] = bytes[8].to_int().land(0x3F).lor(0x80).to_byte()

  // Set version bits (bits 4-7 of octet 6)
  let version_int = match version {
    Version::V1 => 1
    Version::V2 => 2
    Version::V3 => 3
    Version::V4 => 4
    Version::V5 => 5
    Version::V6 => 6
    Version::V7 => 7
    Version::V8 => 8
  }
  bytes[6] = bytes[6].to_int().land(0x0F).lor(version_int << 4).to_byte()
}

///| Generate the nil UUID (all zeros)
pub fn nil() -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  { bytes, }
}

///| Check if the UUID is nil (all zeros)
pub fn is_nil(self : Uuid) -> Bool {
  for i = 0; i < 16; i = i + 1 {
    if self.bytes[i] != b'\x00' {
      return false
    }
  }
  true
}

///| Generate the max UUID (all ones)
pub fn max() -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\xFF')
  { bytes, }
}

///| Check if the UUID is max (all ones)
pub fn is_max(self : Uuid) -> Bool {
  for i = 0; i < 16; i = i + 1 {
    if self.bytes[i] != b'\xFF' {
      return false
    }
  }
  true
}
