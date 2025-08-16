/// UUID Version 4 (Random) implementation

///| Generate a random UUID (version 4)
/// Uses random or pseudo-random numbers for all bits except version and variant
pub fn v4() -> Uuid {
  // Generate 16 random bytes
  let bytes = random_bytes(16)

  // Set version and variant bits according to RFC 9562
  set_variant_and_version(bytes, Version::V4)
  Uuid::new(bytes)
}

///| Generate a random UUID using a specific random number generator
pub fn v4_with_rng(rng : SimpleRng) -> Uuid {
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  rng.fill_bytes(bytes)

  // Set version and variant bits according to RFC 9562
  set_variant_and_version(bytes, Version::V4)
  Uuid::new(bytes)
}

///| Generate multiple random UUIDs
pub fn v4_bulk(count : Int) -> Array[Uuid] {
  let result : Array[Uuid] = []
  for i = 0; i < count; i = i + 1 {
    result.push(v4())
  }
  result
}
