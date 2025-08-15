/// Basic tests for the UUID library

/// Test nil UUID
test "nil_uuid" {
  let nil_uuid = nil()
  assert!(nil_uuid.is_nil())
  assert!(!nil_uuid.is_max())
  assert!(nil_uuid.to_string() == "00000000-0000-0000-0000-000000000000")
}

/// Test max UUID
test "max_uuid" {
  let max_uuid = max()
  assert!(max_uuid.is_max())
  assert!(!max_uuid.is_nil())
  assert!(max_uuid.to_string() == "ffffffff-ffff-ffff-ffff-ffffffffffff")
}

/// Test UUID equality
test "uuid_equality" {
  let uuid1 = nil()
  let uuid2 = nil()
  assert!(uuid1 == uuid2)
  
  let max1 = max()
  let max2 = max()
  assert!(max1 == max2)
  
  assert!(uuid1 != max1)
}

/// Test UUID v4 generation
test "uuid_v4_generation" {
  let uuid = v4()
  
  // Check variant is RFC 9562
  assert!(uuid.variant() == Variant::Rfc9562)
  
  // Check version is 4
  assert!(uuid.version() == Some(Version::V4))
  
  // Should not be nil or max
  assert!(!uuid.is_nil())
  assert!(!uuid.is_max())
  
  // Generate multiple UUIDs to check they're different
  let uuid2 = v4()
  assert!(uuid != uuid2)
}

/// Test UUID v7 generation
test "uuid_v7_generation" {
  let uuid = v7()
  
  // Check variant and version
  assert!(uuid.variant() == Variant::Rfc9562)
  assert!(uuid.version() == Some(Version::V7))
  
  // Should be able to extract timestamp
  let timestamp = extract_timestamp(uuid)
  assert!(timestamp.is_some())
}

/// Test string conversion
test "string_conversion" {
  let uuid = v4()
  let str = uuid.to_string()
  
  // Should be proper format
  assert!(str.length() == 36) // 32 hex chars + 4 hyphens
  
  // Should be able to parse back
  let parsed = from_string(str)
  assert!(parsed == Some(uuid))
}

/// Test v3 name-based UUID
test "uuid_v3_generation" {
  let name = "example.com"
  let uuid = v3(ns_dns, name)
  
  // Check variant and version
  assert!(uuid.variant() == Variant::Rfc9562)
  assert!(uuid.version() == Some(Version::V3))
  
  // Same name should produce same UUID
  let uuid2 = v3(ns_dns, name)
  assert!(uuid == uuid2)
}