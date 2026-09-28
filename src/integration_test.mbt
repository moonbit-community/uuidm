///|
/// Integration tests for the UUID library
/// Testing end-to-end functionality and realistic usage scenarios
test "real_world_usage_scenario" {
  // Simulate a real application using UUIDs

  // 1. Generate user IDs (v4)
  let user_id = @uuidm.v4()
  let session_id = @uuidm.v4()
  inspect(user_id.is_nil(), content="false")
  inspect(user_id != session_id, content="true")

  // 2. Generate resource IDs based on names (v5)
  let api_endpoint = "https://api.example.com/users"
  let resource_id = @uuidm.v5(@uuidm.ns_url, api_endpoint)
  let same_resource_id = @uuidm.v5(@uuidm.ns_url, api_endpoint)
  inspect(resource_id == same_resource_id, content="true")
  inspect(
    resource_id.to_string(),
    content="af9d601c-4ce1-5c4e-af69-65bfb58c1968",
  )

  // 3. Generate time-ordered event IDs (v7)
  let event1 = @uuidm.v7()
  let event2 = @uuidm.v7()
  let event3 = @uuidm.v7()

  // Extract timestamps and check they exist
  let ts1 = @uuidm.extract_timestamp(event1)
  let ts2 = @uuidm.extract_timestamp(event2)
  let ts3 = @uuidm.extract_timestamp(event3)
  match (ts1, ts2, ts3) {
    (Some(_), Some(_), Some(_)) => inspect(true, content="true")
    _ => inspect(false, content="v7 UUIDs should have timestamps")
  }
}

///|
test "namespace_consistency_test" {
  // Test that different namespaces produce different UUIDs for same name
  let name = "example.resource"
  let dns_uuid = @uuidm.v3(@uuidm.ns_dns, name)
  let url_uuid = @uuidm.v3(@uuidm.ns_url, name)
  let oid_uuid = @uuidm.v3(@uuidm.ns_oid, name)
  let x500_uuid = @uuidm.v3(@uuidm.ns_x500, name)

  // All should be different
  inspect(dns_uuid != url_uuid, content="true")
  inspect(dns_uuid != oid_uuid, content="true")
  inspect(dns_uuid != x500_uuid, content="true")
  inspect(url_uuid != oid_uuid, content="true")
  inspect(url_uuid != x500_uuid, content="true")
  inspect(oid_uuid != x500_uuid, content="true")

  // But v3 and v5 for same namespace should be different
  let v3_dns_uuid = @uuidm.v3(@uuidm.ns_dns, name)
  let v5_dns_uuid = @uuidm.v5(@uuidm.ns_dns, name)
  inspect(v3_dns_uuid != v5_dns_uuid, content="true")
}

///|
test "string_format_consistency_test" {
  let uuid = @uuidm.v4_with_rng(@uuidm.SimpleRng::new(999L))
  let standard = uuid.to_string()
  let urn = uuid.to_urn()
  inspect(standard.length(), content="36")
  inspect(urn.length() >= 45, content="true") // "urn:uuid:" + 36 chars

  // URN should contain the uuid string
  inspect(urn.contains(standard), content="true")
}

///|
test "version_and_variant_correctness" {
  // Test that version and variant bits are set correctly

  let v3_uuid = @uuidm.v3(@uuidm.ns_dns, "test")
  let v4_uuid = @uuidm.v4()
  let v5_uuid = @uuidm.v5(@uuidm.ns_dns, "test")
  let v7_uuid = @uuidm.v7()
  let v8_uuid = @uuidm.v8(FixedArray::make(16, b'\x00'))

  // All should have some variant (we test the actual variant checking)
  inspect(v3_uuid.variant(), content="Rfc9562")
  inspect(v4_uuid.variant(), content="Rfc9562")
  inspect(v5_uuid.variant(), content="Rfc9562")
  inspect(v7_uuid.variant(), content="Rfc9562")
  inspect(v8_uuid.variant(), content="Rfc9562")

  // Versions should be correct
  match v3_uuid.version() {
    Some(_) => inspect(true, content="true")
    None => inspect(false, content="v3 should have version")
  }
  match v4_uuid.version() {
    Some(_) => inspect(true, content="true")
    None => inspect(false, content="v4 should have version")
  }
  match v5_uuid.version() {
    Some(_) => inspect(true, content="true")
    None => inspect(false, content="v5 should have version")
  }
  match v7_uuid.version() {
    Some(_) => inspect(true, content="true")
    None => inspect(false, content="v7 should have version")
  }
  match v8_uuid.version() {
    Some(_) => inspect(true, content="true")
    None => inspect(false, content="v8 should have version")
  }
}

///|
test "uuid_equality_and_comparison" {
  // Test UUID equality across different creation methods

  let nil1 = @uuidm.nil()
  let nil2 = @uuidm.nil()
  let max1 = @uuidm.max()
  let max2 = @uuidm.max()
  inspect(nil1 == nil2, content="true")
  inspect(max1 == max2, content="true")
  inspect(nil1 != max1, content="true")

  // Same name-based UUIDs should be equal
  let name = "consistent.test.example.com"
  let v3_1 = @uuidm.v3(@uuidm.ns_dns, name)
  let v3_2 = @uuidm.v3(@uuidm.ns_dns, name)
  let v5_1 = @uuidm.v5(@uuidm.ns_dns, name)
  let v5_2 = @uuidm.v5(@uuidm.ns_dns, name)
  inspect(v3_1 == v3_2, content="true")
  inspect(v5_1 == v5_2, content="true")
  inspect(v3_1 != v5_1, content="true")
}

///|
test "error_handling_and_edge_cases" {
  // Test various edge cases and error conditions

  // Empty string name
  let empty_name_uuid = @uuidm.v3(@uuidm.ns_dns, "")
  inspect(empty_name_uuid.variant(), content="Rfc9562")

  // Very long name
  let long_name = "this.is.a.very.long.domain.name.that.exceeds.normal.length.but.should.still.work.example.com"
  let long_name_uuid = @uuidm.v5(@uuidm.ns_dns, long_name)
  inspect(long_name_uuid.variant(), content="Rfc9562")

  // Unicode characters (if supported)
  let unicode_name = "тест.example.com"
  let unicode_uuid = @uuidm.v3(@uuidm.ns_dns, unicode_name)
  inspect(unicode_uuid.variant(), content="Rfc9562")

  // Special characters
  let special_name = "test-with_special.chars@example.com"
  let special_uuid = @uuidm.v5(@uuidm.ns_dns, special_name)
  inspect(special_uuid.variant(), content="Rfc9562")
}

///|
test "performance_consistency_test" {
  // Test that operations are consistent across multiple runs

  // Generate multiple UUIDs and check consistency
  let v4_uuids : Array[@uuidm.Uuid] = []
  for i = 0; i < 10; i = i + 1 {
    v4_uuids.push(@uuidm.v4())
  }
  inspect(v4_uuids.length(), content="10")

  // All should be different (very high probability)
  let mut unique_count = 0
  for i = 0; i < 10; i = i + 1 {
    let mut is_unique = true
    for j = 0; j < 10; j = j + 1 {
      if i != j && v4_uuids[i] == v4_uuids[j] {
        is_unique = false
      }
    }
    if is_unique {
      unique_count = unique_count + 1
    }
  }
  inspect(unique_count, content="10")

  // Name-based UUIDs should be consistent
  let base_name = "performance.test.example.org"
  let v3_results : Array[@uuidm.Uuid] = []
  let v5_results : Array[@uuidm.Uuid] = []
  for i = 0; i < 5; i = i + 1 {
    v3_results.push(@uuidm.v3(@uuidm.ns_dns, base_name))
    v5_results.push(@uuidm.v5(@uuidm.ns_dns, base_name))
  }

  // All v3 results should be identical
  let mut v3_consistent = true
  for i = 1; i < 5; i = i + 1 {
    if v3_results[i] != v3_results[0] {
      v3_consistent = false
    }
  }
  inspect(v3_consistent, content="true")

  // All v5 results should be identical  
  let mut v5_consistent = true
  for i = 1; i < 5; i = i + 1 {
    if v5_results[i] != v5_results[0] {
      v5_consistent = false
    }
  }
  inspect(v5_consistent, content="true")
}

///|
test "library_demo_output" {
  // Test the demo function output
  let demo_output = @uuidm.demo()
  // The v4 / v7 values are random; check the layout only.
  let lines = demo_output.split("\n").map(l => l.to_owned()).collect()
  inspect(lines.length(), content="3")
  inspect(lines[0].has_prefix("UUID v4: "), content="true")
  inspect(lines[1].has_prefix("UUID v7: 017e12ef-9c00-7"), content="true")
  inspect(lines[2], content="Nil UUID: 00000000-0000-0000-0000-000000000000")

  // The demo should include UUID examples
  inspect(demo_output.length() > 50, content="true")
  inspect(demo_output.contains("UUID"), content="true")
}
