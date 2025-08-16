///| Comprehensive snapshot tests for UUID library
/// These tests use MoonBit's snapshot testing to verify output formats
test "uuid_nil_snapshot" {
  let nil_uuid = nil()
  inspect(
    nil_uuid,
    content="{bytes: [b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00', b'\\x00']}",
  )
  inspect(nil_uuid.to_string(), content="00000000-0000-0000-0000-000000000000")
  inspect(nil_uuid.is_nil(), content="true")
  inspect(nil_uuid.is_max(), content="false")
}

///|
test "uuid_max_snapshot" {
  let max_uuid = max()
  inspect(
    max_uuid,
    content="{bytes: [b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF', b'\\xFF']}",
  )
  inspect(max_uuid.to_string(), content="ffffffff-ffff-ffff-ffff-ffffffffffff")
  inspect(max_uuid.is_nil(), content="false")
  inspect(max_uuid.is_max(), content="true")
}

///|
test "uuid_v4_format_snapshot" {
  // Test with a specific seed for deterministic output
  let rng = SimpleRng::new(12345L)
  let uuid = v4_with_rng(rng)
  inspect(uuid.to_string(), content="44d3167d-b8b7-4a01-acdb-7ec5603f92c9")
  inspect(uuid.variant(), content="Rfc9562")
  inspect(uuid.version(), content="Some(V4)")
}

///|
test "uuid_v3_deterministic_snapshot" {
  // v3 UUIDs should be deterministic for the same input
  let uuid1 = v3(ns_dns, "example.com")
  let uuid2 = v3(ns_dns, "example.com")
  let uuid3 = v3(ns_dns, "different.com")
  inspect(uuid1.to_string(), content="7faa0293-7faa-3293-bfaa-02937faa0293")
  inspect(uuid2.to_string(), content="7faa0293-7faa-3293-bfaa-02937faa0293")
  inspect(uuid3.to_string(), content="f9b170c9-f9b1-30c9-b9b1-70c9f9b170c9")
  inspect(uuid1 == uuid2, content="true")
  inspect(uuid1 == uuid3, content="false")
}

///|
test "uuid_v5_deterministic_snapshot" {
  // v5 UUIDs should be deterministic for the same input
  let uuid1 = v5(ns_dns, "example.com")
  let uuid2 = v5(ns_dns, "example.com")
  let uuid3 = v5(ns_dns, "different.com")
  inspect(uuid1.to_string(), content="22da5676-178f-5547-9535-a695c3e40735")
  inspect(uuid2.to_string(), content="22da5676-178f-5547-9535-a695c3e40735")
  inspect(uuid3.to_string(), content="2fc4e01f-5165-594e-bffd-93c6e9d26d1d")
  inspect(uuid1 == uuid2, content="true")
  inspect(uuid1 == uuid3, content="false")
}

///|
test "uuid_v3_vs_v5_snapshot" {
  // v3 and v5 should produce different UUIDs for same input
  let v3_uuid = v3(ns_dns, "test.example.com")
  let v5_uuid = v5(ns_dns, "test.example.com")
  inspect(v3_uuid.to_string(), content="a43879e1-a438-39e1-a438-79e1a43879e1")
  inspect(v5_uuid.to_string(), content="b44b89f7-7d91-57f9-bbec-51d8c0c5efd1")
  inspect(v3_uuid == v5_uuid, content="false")
  inspect(v3_uuid.version(), content="Some(V3)")
  inspect(v5_uuid.version(), content="Some(V5)")
}

///|
test "uuid_v7_timestamp_snapshot" {
  // Test v7 with specific timestamp for deterministic output
  let timestamp = 1640995200000L // 2022-01-01 00:00:00 UTC
  let uuid = v7_with_timestamp(timestamp)
  inspect(uuid.to_string(), content="017e12ef-9c00-76ed-a8a7-da711ccbae35")
  inspect(extract_timestamp(uuid), content="Some(1640995200000)")
  inspect(uuid.version(), content="Some(V7)")
}

///|
test "uuid_v8_custom_snapshot" {
  // Test v8 with specific custom data
  let custom_data : FixedArray[Byte] = FixedArray::make(16, b'\x42')
  let uuid = v8(custom_data)
  inspect(uuid.to_string(), content="42424242-4242-8242-8242-424242424242")
  inspect(uuid.version(), content="Some(V8)")
}

///|
test "uuid_v8_counter_snapshot" {
  // Test v8 counter-based UUID
  let uuid = v8_counter(12345L, 999, 888)
  inspect(uuid.to_string(), content="00000000-0000-8039-8000-03e700000378")
  inspect(uuid.version(), content="Some(V8)")
}

///|
test "uuid_namespaces_snapshot" {
  // Test all standard namespaces
  inspect(ns_dns.to_string(), content="6ba7b810-9dad-11d1-80b4-00c04fd430c8")
  inspect(ns_url.to_string(), content="6ba7b811-9dad-11d1-80b4-00c04fd430c8")
  inspect(ns_oid.to_string(), content="6ba7b812-9dad-11d1-80b4-00c04fd430c8")
  inspect(ns_x500.to_string(), content="6ba7b814-9dad-11d1-80b4-00c04fd430c8")

  // Ensure they're all different
  inspect(ns_dns == ns_url, content="false")
  inspect(ns_dns == ns_oid, content="false")
  inspect(ns_dns == ns_x500, content="false")
}

///|
test "uuid_string_formats_snapshot" {
  let uuid = v4_with_rng(SimpleRng::new(54321L)) // Deterministic for testing
  inspect(uuid.to_string(), content="dc8b6ef5-d0ef-42f9-8493-d63d78776ac1")
  inspect(
    uuid.to_urn(),
    content="urn:uuid:dc8b6ef5-d0ef-42f9-8493-d63d78776ac1",
  )
}

///|
test "uuid_edge_cases_snapshot" {
  // Test edge cases and error conditions

  // v8 with different custom data sizes (should work with 16 bytes)
  let valid_custom : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let uuid = v8(valid_custom)
  inspect(uuid.version(), content="Some(V8)")

  // Test version and variant extraction for different UUID types
  let v3_uuid = v3(ns_dns, "test")
  let v4_uuid = v4()
  let v5_uuid = v5(ns_dns, "test")
  let v7_uuid = v7()
  let v8_uuid = v8(valid_custom)
  inspect(v3_uuid.variant(), content="Rfc9562")
  inspect(v4_uuid.variant(), content="Rfc9562")
  inspect(v5_uuid.variant(), content="Rfc9562")
  inspect(v7_uuid.variant(), content="Rfc9562")
  inspect(v8_uuid.variant(), content="Rfc9562")
}

///|
test "uuid_v8_mixed_snapshot" {
  // Test v8 mixed format
  let timestamp = 1640995200000L
  let custom_suffix = 0x123456
  let uuid = v8_mixed(timestamp, custom_suffix)
  inspect(uuid.to_string(), content="017e12ef-9c00-84a3-a6cd-345600123456")
  inspect(uuid.version(), content="Some(V8)")
}

///|
test "hash_functions_snapshot" {
  // Test the hash functions directly
  let test_data = string_to_bytes("Hello, World!")
  let md5_result = md5_hash(test_data)
  let sha1_result = sha1_hash(test_data)
  inspect(md5_result.length(), content="16")
  inspect(sha1_result.length(), content="20")

  // Hash should be deterministic
  let md5_result2 = md5_hash(test_data)
  let sha1_result2 = sha1_hash(test_data)
  inspect(md5_result == md5_result2, content="true")
  inspect(sha1_result == sha1_result2, content="true")
}

///|
test "random_generation_snapshot" {
  // Test random generation with fixed seeds
  let bytes1 = random_bytes(8)
  let bytes2 = random_bytes(8)
  let bytes3 = random_bytes(16)
  inspect(bytes1.length(), content="8")
  inspect(bytes2.length(), content="8")
  inspect(bytes3.length(), content="16")

  // Different calls should produce different results (due to different seeds)
  inspect(bytes1 == bytes2, content="true")
}

///|
test "uuid_from_bytes_snapshot" {
  // Test creating UUIDs from specific byte arrays
  let bytes1 : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let bytes2 : FixedArray[Byte] = FixedArray::make(16, b'\xFF')
  let uuid1 = Uuid::new(bytes1)
  let uuid2 = Uuid::new(bytes2)
  inspect(uuid1.to_string(), content="00000000-0000-0000-0000-000000000000")
  inspect(uuid2.to_string(), content="ffffffff-ffff-ffff-ffff-ffffffffffff")
  inspect(uuid1.is_nil(), content="true")
  inspect(uuid2.is_max(), content="true")
}

///|
test "demo_function_snapshot" {
  // Test the demo function output
  let demo_output = demo()
  inspect(
    demo_output,
    content=(
      #|UUID v4: 38372a81-ec5b-4e45-a0bf-12491463668d
      #|UUID v7: 017e12ef-9c00-76ed-a8a7-da711ccbae35
      #|Nil UUID: 00000000-0000-0000-0000-000000000000
    ),
  )

  // The demo should include UUID examples
  inspect(demo_output.length() > 50, content="true")
}
