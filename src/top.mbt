pub fn demo_uuid_library() -> Unit {
  println("=== UUID Library Demo ===")
  println(@lib.demo())
  
  println("\n=== Additional Examples ===")
  
  // Generate some UUIDs of different versions
  let v4_uuid = @lib.v4()
  let v7_uuid = @lib.v7()
  
  println("Random UUID (v4): " + v4_uuid.to_string())
  println("Time-ordered UUID (v7): " + v7_uuid.to_string())
  
  // Name-based UUIDs
  let v3_uuid = @lib.v3(@lib.ns_dns, "example.com")
  let v5_uuid = @lib.v5(@lib.ns_dns, "example.com")
  
  println("Name-based UUID v3 (DNS + example.com): " + v3_uuid.to_string())
  println("Name-based UUID v5 (DNS + example.com): " + v5_uuid.to_string())
  
  // Custom UUID
  let custom_data : FixedArray[Byte] = FixedArray::make(16, b'\x42')
  let v8_uuid = @lib.v8(custom_data)
  println("Custom UUID (v8): " + v8_uuid.to_string())
  
  println("\n=== Testing String Parsing ===")
  let uuid_str = v4_uuid.to_string()
  match @lib.from_string(uuid_str) {
    Some(parsed) => {
      if parsed == v4_uuid {
        println("✓ String parsing works correctly")
      } else {
        println("✗ String parsing failed")
      }
    }
    None => println("✗ Failed to parse UUID string")
  }
}
