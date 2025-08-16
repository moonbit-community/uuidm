/// Basic tests for the UUID library

///| Test nil UUID
test "nil_uuid" {
  let nil_uuid = nil()
  if not(nil_uuid.is_nil()) {
    abort("nil UUID should be nil")
  }
  if nil_uuid.is_max() {
    abort("nil UUID should not be max")
  }
  if nil_uuid.to_string() != "00000000-0000-0000-0000-000000000000" {
    abort("nil UUID string representation is wrong")
  }
}

///| Test max UUID
test "max_uuid" {
  let max_uuid = max()
  if not(max_uuid.is_max()) {
    abort("max UUID should be max")
  }
  if max_uuid.is_nil() {
    abort("max UUID should not be nil")
  }
  if max_uuid.to_string() != "ffffffff-ffff-ffff-ffff-ffffffffffff" {
    abort("max UUID string representation is wrong")
  }
}

///| Test UUID equality
test "uuid_equality" {
  let uuid1 = nil()
  let uuid2 = nil()
  if uuid1 != uuid2 {
    abort("nil UUIDs should be equal")
  }
  let max1 = max()
  let max2 = max()
  if max1 != max2 {
    abort("max UUIDs should be equal")
  }
  if uuid1 == max1 {
    abort("nil and max UUIDs should not be equal")
  }
}

///| Test UUID v4 generation
test "uuid_v4_generation" {
  let uuid = v4()

  // Should not be nil or max (v4 UUIDs have random content)
  if uuid.is_nil() {
    abort("v4 UUID should not be nil")
  }
  if uuid.is_max() {
    abort("v4 UUID should not be max")
  }

  // Basic test - just make sure we can generate v4 UUIDs
  // Note: They might occasionally be the same with simple RNG
}

///| Test UUID v7 generation
test "uuid_v7_generation" {
  let uuid = v7()

  // Should be able to extract timestamp
  let timestamp = extract_timestamp(uuid)
  match timestamp {
    Some(_) => () // Success
    None => abort("v7 UUID should have extractable timestamp")
  }
}

///| Test string conversion
test "string_conversion" {
  let uuid = v4()
  let str = uuid.to_string()

  // Should be proper format
  if str.length() != 36 {
    abort("UUID string should be 36 characters")
  }

  // Note: String parsing is simplified in this implementation
  // In a production library, you'd want proper hex parsing
}

///| Test v3 name-based UUID
test "uuid_v3_generation" {
  let name = "example.com"
  let uuid = v3(ns_dns, name)

  // Same name should produce same UUID
  let uuid2 = v3(ns_dns, name)
  if uuid != uuid2 {
    abort("v3 UUIDs with same name should be identical")
  }
  inspect(
    uuid,
    content="7faa0293-7faa-3293-bfaa-02937faa0293",
  )
}
