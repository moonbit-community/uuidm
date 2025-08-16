/// Public API for the uuidm library
/// Re-export all major functionality

///| Example usage and demo function
pub fn demo() -> String {
  let v4_uuid = v4()
  let v7_uuid = v7()
  "UUID v4: " +
  v4_uuid.to_string() +
  "\n" +
  "UUID v7: " +
  v7_uuid.to_string() +
  "\n" +
  "Nil UUID: " +
  nil().to_string()
}
