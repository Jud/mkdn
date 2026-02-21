# Getting Started

## Prerequisites

- macOS 14.0 or later
- Swift 5.9+
- Xcode 15+

## Installation

```bash
brew install lumen
```

Or add to your Swift package:

```swift
.package(url: "https://github.com/lumen/lumen.git", from: "2.0.0")
```

## Your First Pipeline

Create a new file called `main.swift`:

```swift
import Lumen

@main
struct App {
    static func main() async throws {
        let pipeline = Pipeline {
            Transform<String, Int> { str in
                str.count
            }
            Filter { $0 > 5 }
        }

        let results = try await pipeline.process(["hello", "beautiful", "world"])
        print(results) // [9, 5]
    }
}
```

## Next Steps

- Read the [API Reference](../api/endpoints.md)
- Check the [Architecture Notes](../notes/architecture-decisions.md)
