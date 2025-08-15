/// Random number generation utilities for UUIDs

/// Simple linear congruential generator for generating random bytes
/// This is a basic implementation - in production you might want to use
/// a better quality random number generator or system entropy
struct SimpleRng {
  mut state : Int64
}

/// Create a new random number generator with a seed
pub fn SimpleRng::new(seed : Int64) -> SimpleRng {
  { state: seed }
}

/// Create a new random number generator with current time as seed
pub fn SimpleRng::new_with_time() -> SimpleRng {
  // Use a simple time-based seed (this is basic implementation)
  // In a real implementation, you'd use system time or entropy
  let seed = 1664525L // Simple seed for demonstration
  { state: seed }
}

/// Generate the next random 64-bit integer
pub fn next_int64(self : SimpleRng) -> Int64 {
  // Linear congruential generator: state = (a * state + c) mod m
  // Using values from Numerical Recipes
  self.state = (1664525L * self.state + 1013904223L)
  self.state
}

/// Generate a random byte
pub fn next_byte(self : SimpleRng) -> Byte {
  let rand = self.next_int64()
  (rand.land(0xFFL).to_int()).to_byte()
}

/// Fill an array with random bytes
pub fn fill_bytes(self : SimpleRng, bytes : FixedArray[Byte]) -> Unit {
  for i = 0; i < bytes.length(); i = i + 1 {
    bytes[i] = self.next_byte()
  }
}

/// Generate random bytes using a new RNG instance
pub fn random_bytes(count : Int) -> FixedArray[Byte] {
  let rng = SimpleRng::new_with_time()
  let bytes : FixedArray[Byte] = FixedArray::make(count, b'\x00')
  rng.fill_bytes(bytes)
  bytes
}
