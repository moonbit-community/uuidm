# Uuidm — Universally unique identifiers (UUIDs) for MoonBit

Uuidm is a MoonBit library implementing 128 bits universally unique identifiers (UUIDs) versions 3, 4, 5, 7, and 8 according to [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562).

This is a port of the original [OCaml uuidm library](https://github.com/dbuenzli/uuidm) by Daniel Bünzli.

## Features

- **UUID v3**: Name-based UUIDs using MD5 hashing
- **UUID v4**: Random or pseudo-random UUIDs  
- **UUID v5**: Name-based UUIDs using SHA-1 hashing
- **UUID v7**: Time-ordered UUIDs with random component
- **UUID v8**: Custom format UUIDs
- **String conversion**: To/from standard UUID string representations
- **Standard namespaces**: DNS, URL, OID, and X.500 namespaces
- **No external dependencies**: Pure MoonBit implementation

## Installation

This library is designed to work with the MoonBit compiler. Add it to your `moon.mod.json`:

```json
{
  "name": "your-project",
  "version": "0.1.0",
  "deps": {
    "uuidm": "0.1.0"
  }
}
```

## Quick Start

```moonbit
// Generate a random UUID (version 4)
let uuid = v4()
println(uuid.to_string()) // e.g., "550e8400-e29b-41d4-a716-446655440000"

// Generate time-ordered UUID (version 7)
let time_uuid = v7()
println(time_uuid.to_string())

// Generate name-based UUID (version 5)
let name_uuid = v5(ns_dns, "example.com")
println(name_uuid.to_string())

// Parse UUID from string
match from_string("550e8400-e29b-41d4-a716-446655440000") {
  Some(uuid) => println("Parsed: " + uuid.to_string())
  None => println("Invalid UUID")
}
```

## API Reference

### Core Types

```moonbit
// UUID type
struct Uuid {
  bytes : FixedArray[Byte]
}

// UUID variants
enum Variant {
  Ncs | Rfc9562 | Microsoft | Reserved
}

// UUID versions  
enum Version {
  V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8
}
```

### UUID Generation

```moonbit
// Version 4 (Random)
pub fn v4() -> Uuid
pub fn v4_bulk(count : Int) -> Array[Uuid]

// Version 3 (Name-based with MD5)
pub fn v3(namespace : Uuid, name : String) -> Uuid
pub fn v3_dns(name : String) -> Uuid
pub fn v3_url(name : String) -> Uuid

// Version 5 (Name-based with SHA-1)
pub fn v5(namespace : Uuid, name : String) -> Uuid
pub fn v5_dns(name : String) -> Uuid
pub fn v5_url(name : String) -> Uuid

// Version 7 (Time-ordered)
pub fn v7() -> Uuid
pub fn v7_with_timestamp(timestamp_ms : Int64) -> Uuid
pub fn v7_sequence(count : Int) -> Array[Uuid]

// Version 8 (Custom)
pub fn v8(custom_data : FixedArray[Byte]) -> Uuid
pub fn v8_counter(counter : Int64, node_id : Int, application_id : Int) -> Uuid
pub fn v8_mixed(timestamp_ms : Int64, custom_suffix : Int) -> Uuid
```

### String Conversion

```moonbit
// Convert to string
pub fn to_string(uuid : Uuid) -> String          // With hyphens
pub fn to_string_simple(uuid : Uuid) -> String   // Without hyphens
pub fn to_urn(uuid : Uuid) -> String             // URN format

// Parse from string
pub fn from_string(s : String) -> Uuid?          // Safe parsing
pub fn from_string_exn(s : String) -> Uuid       // Panics on error
pub fn from_urn(s : String) -> Uuid?             // Parse URN format
```

### UUID Properties

```moonbit
// Get UUID properties
pub fn variant(uuid : Uuid) -> Variant
pub fn version(uuid : Uuid) -> Option[Version]
pub fn bytes(uuid : Uuid) -> FixedArray[Byte]

// Special UUIDs
pub fn nil() -> Uuid                              // All zeros
pub fn max() -> Uuid                              // All ones
pub fn is_nil(uuid : Uuid) -> Bool
pub fn is_max(uuid : Uuid) -> Bool
```

### Standard Namespaces

```moonbit
pub let ns_dns : Uuid      // DNS namespace
pub let ns_url : Uuid      // URL namespace  
pub let ns_oid : Uuid      // OID namespace
pub let ns_x500 : Uuid     // X.500 namespace
```

## Examples

### Name-based UUIDs

```moonbit
// Using predefined namespaces
let dns_uuid = v5_dns("example.com")
let url_uuid = v5_url("https://example.com/path")

// Using custom namespace
let custom_ns = v4() // or any other UUID
let custom_uuid = v5(custom_ns, "my-resource")

// Version 3 vs Version 5 (different hash algorithms)
let v3_uuid = v3_dns("example.com") 
let v5_uuid = v5_dns("example.com")
// These will be different UUIDs
```

### Time-ordered UUIDs

```moonbit
// Generate sequence of time-ordered UUIDs
let sequence = v7_sequence(5)
// These will be in chronological order

// Extract timestamp from v7 UUID
match extract_timestamp(v7_uuid) {
  Some(timestamp) => println("Created at: " + timestamp.to_string())
  None => println("Not a v7 UUID")
}
```

### Custom UUIDs (Version 8)

```moonbit
// Counter-based UUID
let counter_uuid = v8_counter(12345L, 999, 888)

// Mixed timestamp + custom data
let mixed_uuid = v8_mixed(current_timestamp_ms(), 0x123456)

// Fully custom
let custom_data : FixedArray[Byte] = FixedArray::make(16, 0x42b)
let custom_uuid = v8(custom_data)
```

## Testing

The library includes comprehensive tests:

```bash
moon test
```

## Implementation Notes

- **Cryptographic hashing**: The MD5 and SHA-1 implementations are simplified for demonstration. In production, you may want to use proper cryptographic libraries.
- **Random number generation**: Uses a simple linear congruential generator. For cryptographic applications, consider using a cryptographically secure random number generator.
- **Performance**: This implementation prioritizes clarity and correctness over performance optimization.

## Compliance

This library implements UUIDs according to [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562) (formerly RFC 4122). It supports:

- ✅ UUID version 3 (name-based, MD5)
- ✅ UUID version 4 (random)  
- ✅ UUID version 5 (name-based, SHA-1)
- ✅ UUID version 7 (time-ordered)
- ✅ UUID version 8 (custom)
- ✅ Standard string representations
- ✅ Standard namespaces

## License

This library is distributed under the ISC license, same as the original OCaml implementation.

## Contributing

Contributions are welcome! Please ensure any changes include appropriate tests and documentation.

## Acknowledgments

This is a port of the excellent [uuidm](https://github.com/dbuenzli/uuidm) library by Daniel Bünzli. The original design and implementation patterns have been adapted for MoonBit while maintaining compatibility with RFC 9562.