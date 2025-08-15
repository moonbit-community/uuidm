/// UUID Versions 3 and 5 (Name-based) implementation

/// Generate a UUID version 3 (name-based using MD5)
pub fn v3(ns : Uuid, name : String) -> Uuid {
  let combined = combine_namespace_and_name(ns, name)
  let hash = md5_hash(combined)
  
  // Take first 16 bytes of MD5 hash (MD5 produces exactly 16 bytes)
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  for i = 0; i < 16; i = i + 1 {
    bytes[i] = hash[i]
  }
  
  // Set version and variant bits
  set_variant_and_version(bytes, Version::V3)
  
  Uuid::new(bytes)
}

/// Generate a UUID version 5 (name-based using SHA-1)
pub fn v5(ns : Uuid, name : String) -> Uuid {
  let combined = combine_namespace_and_name(ns, name)
  let hash = sha1_hash(combined)
  
  // Take first 16 bytes of SHA-1 hash (SHA-1 produces 20 bytes)
  let bytes : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  for i = 0; i < 16; i = i + 1 {
    bytes[i] = hash[i]
  }
  
  // Set version and variant bits
  set_variant_and_version(bytes, Version::V5)
  
  Uuid::new(bytes)
}

/// Convenience function to generate v3 UUID with DNS namespace
pub fn v3_dns(name : String) -> Uuid {
  v3(ns_dns, name)
}

/// Convenience function to generate v3 UUID with URL namespace  
pub fn v3_url(name : String) -> Uuid {
  v3(ns_url, name)
}

/// Convenience function to generate v3 UUID with OID namespace
pub fn v3_oid(name : String) -> Uuid {
  v3(ns_oid, name)
}

/// Convenience function to generate v3 UUID with X500 namespace
pub fn v3_x500(name : String) -> Uuid {
  v3(ns_x500, name)
}

/// Convenience function to generate v5 UUID with DNS namespace
pub fn v5_dns(name : String) -> Uuid {
  v5(ns_dns, name)
}

/// Convenience function to generate v5 UUID with URL namespace
pub fn v5_url(name : String) -> Uuid {
  v5(ns_url, name)
}

/// Convenience function to generate v5 UUID with OID namespace
pub fn v5_oid(name : String) -> Uuid {
  v5(ns_oid, name)
}

/// Convenience function to generate v5 UUID with X500 namespace
pub fn v5_x500(name : String) -> Uuid {
  v5(ns_x500, name)
}