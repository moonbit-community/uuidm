/// UUID Version 8 (Custom) implementation

///|
/// Generate a custom UUID (version 8)
/// The caller is responsible for providing the custom data
pub fn v8(custom_data : FixedArray[Byte]) -> Uuid {
  if custom_data.length() != 16 {
    abort("Custom data must be exactly 16 bytes")
  }
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')

  // Copy custom data
  for i = 0; i < 16; i = i + 1 {
    bytes[i] = custom_data[i]
  }

  // Set version and variant bits
  set_variant_and_version(bytes, Version::V8)
  Uuid::new(bytes)
}

///|
/// Generate a custom UUID from a 128-bit integer
pub fn v8_from_int128(high : Int64, low : Int64) -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')

  // Convert high 64 bits to bytes
  for i = 0; i < 8; i = i + 1 {
    bytes[i] = (high >> ((7 - i) * 8)).land(0xFFL).to_int().to_byte()
  }

  // Convert low 64 bits to bytes
  for i = 0; i < 8; i = i + 1 {
    bytes[8 + i] = (low >> ((7 - i) * 8)).land(0xFFL).to_int().to_byte()
  }

  // Set version and variant bits
  set_variant_and_version(bytes, Version::V8)
  Uuid::new(bytes)
}

///|
/// Generate a custom UUID with application-specific structure
/// Example: counter-based UUID with specific formatting
pub fn v8_counter(counter : Int64, node_id : Int, application_id : Int) -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')

  // First 8 bytes: counter
  for i = 0; i < 8; i = i + 1 {
    bytes[i] = (counter >> ((7 - i) * 8)).land(0xFFL).to_int().to_byte()
  }

  // Next 4 bytes: node_id
  for i = 0; i < 4; i = i + 1 {
    bytes[8 + i] = (node_id >> ((3 - i) * 8)).land(0xFF).to_byte()
  }

  // Last 4 bytes: application_id  
  for i = 0; i < 4; i = i + 1 {
    bytes[12 + i] = (application_id >> ((3 - i) * 8)).land(0xFF).to_byte()
  }

  // Set version and variant bits
  set_variant_and_version(bytes, Version::V8)
  Uuid::new(bytes)
}

///|
/// Generate a custom UUID with mixed content (timestamp + random + custom)
pub fn v8_mixed(timestamp_ms : Int64, custom_suffix : Int) -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')

  // First 6 bytes: timestamp (like v7)
  bytes[0] = (timestamp_ms >> 40).land(0xFFL).to_int().to_byte()
  bytes[1] = (timestamp_ms >> 32).land(0xFFL).to_int().to_byte()
  bytes[2] = (timestamp_ms >> 24).land(0xFFL).to_int().to_byte()
  bytes[3] = (timestamp_ms >> 16).land(0xFFL).to_int().to_byte()
  bytes[4] = (timestamp_ms >> 8).land(0xFFL).to_int().to_byte()
  bytes[5] = timestamp_ms.land(0xFFL).to_int().to_byte()

  // Next 4 bytes: random
  let random_bytes = random_bytes(4)
  for i = 0; i < 4; i = i + 1 {
    bytes[6 + i] = random_bytes[i]
  }

  // Last 6 bytes: custom suffix
  for i = 0; i < 6; i = i + 1 {
    bytes[10 + i] = (custom_suffix >> ((5 - i) * 8)).land(0xFF).to_byte()
  }

  // Set version and variant bits
  set_variant_and_version(bytes, Version::V8)
  Uuid::new(bytes)
}

///|
/// Extract custom data from a version 8 UUID (excluding version/variant bits)
pub fn extract_custom_data(uuid : Uuid) -> FixedArray[Byte]? {
  match uuid.version() {
    Some(Version::V8) => {
      let bytes = uuid.bytes()
      let custom_data : FixedArray[Byte] = FixedArray::make(16, b'\x00')

      // Copy all bytes (caller can handle version/variant bits if needed)
      for i = 0; i < 16; i = i + 1 {
        custom_data[i] = bytes[i]
      }
      Some(custom_data)
    }
    _ => None
  }
}
