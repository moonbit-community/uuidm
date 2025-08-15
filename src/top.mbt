pub fn main() -> Unit {
  println("=== UUID Library Demo ===")
  println(@lib.demo())
  
  println("\n=== Additional Examples ===")
  
  // Generate some UUIDs of different versions
  let v4_uuid = @lib.v4()
  let v7_uuid = @lib.v7()
  
  println("Random UUID (v4): " + @lib.to_string(v4_uuid))
  println("Time-ordered UUID (v7): " + @lib.to_string(v7_uuid))
  
  // Name-based UUIDs
  let v3_uuid = @lib.v3(@lib.ns_dns, "example.com")
  let v5_uuid = @lib.v5(@lib.ns_dns, "example.com")
  
  println("Name-based UUID v3 (DNS + example.com): " + @lib.to_string(v3_uuid))
  println("Name-based UUID v5 (DNS + example.com): " + @lib.to_string(v5_uuid))
  
  // Custom UUID
  let custom_data : FixedArray[Byte] = FixedArray::make(16, 0x42b)
  let v8_uuid = @lib.v8(custom_data)
  println("Custom UUID (v8): " + @lib.to_string(v8_uuid))
  
  println("\n=== Testing String Parsing ===")
  let uuid_str = @lib.to_string(v4_uuid)
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
