# Code Block Rendering Test

## Swift (Syntax Highlighted)

```swift
import Foundation

/// A generic result type for async operations.
protocol DataFetcher {
    associatedtype Output
    func fetch(from url: URL) async throws -> Output
}

@Observable
final class UserViewModel {
    var users: [String] = []
    private let baseURL = URL(string: "https://api.example.com")!

    func loadUsers() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: baseURL)
            let decoded = try JSONDecoder().decode([String].self, from: data)
            users = decoded
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - SwiftUI View

struct UserListView: View {
    @State private var viewModel = UserViewModel()
    @State private var searchText = ""

    var filteredUsers: [String] {
        guard !searchText.isEmpty else { return viewModel.users }
        return viewModel.users.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredUsers, id: \.self) { user in
            Text(user)
                .font(.body)
        }
        .searchable(text: $searchText)
        .task { await viewModel.loadUsers() }
    }
}

#Preview {
    UserListView()
}
```

## Python

```python
from dataclasses import dataclass
from typing import Optional
import asyncio

@dataclass
class Config:
    host: str = "localhost"
    port: int = 8080
    debug: bool = False
    max_retries: int = 3

class AsyncWorker:
    """Processes tasks asynchronously with retry logic."""

    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config()
        self._queue: asyncio.Queue[str] = asyncio.Queue()

    async def process(self, item: str) -> dict:
        for attempt in range(self.config.max_retries):
            try:
                await asyncio.sleep(0.1)  # simulate work
                return {"status": "ok", "item": item, "attempt": attempt}
            except Exception as e:
                if attempt == self.config.max_retries - 1:
                    raise RuntimeError(f"Failed after {attempt + 1} retries") from e

    async def run(self):
        while True:
            item = await self._queue.get()
            result = await self.process(item)
            print(f"Processed: {result}")
            self._queue.task_done()

if __name__ == "__main__":
    worker = AsyncWorker(Config(debug=True))
    asyncio.run(worker.run())
```

## JavaScript

```javascript
const debounce = (fn, delay) => {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
};

class EventEmitter {
  #listeners = new Map();

  on(event, callback) {
    if (!this.#listeners.has(event)) {
      this.#listeners.set(event, []);
    }
    this.#listeners.get(event).push(callback);
    return () => this.off(event, callback);
  }

  emit(event, ...args) {
    const handlers = this.#listeners.get(event) ?? [];
    handlers.forEach(fn => fn(...args));
  }
}

// Usage
const bus = new EventEmitter();
const unsub = bus.on("resize", debounce((w, h) => {
  console.log(`Window: ${w}x${h}`);
}, 250));
```

## TypeScript

```typescript
interface ApiResponse<T> {
  data: T;
  status: number;
  headers: Record<string, string>;
}

type HttpMethod = "GET" | "POST" | "PUT" | "DELETE";

async function request<T>(
  url: string,
  method: HttpMethod = "GET",
  body?: unknown
): Promise<ApiResponse<T>> {
  const response = await fetch(url, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });

  return {
    data: await response.json() as T,
    status: response.status,
    headers: Object.fromEntries(response.headers),
  };
}
```

## Rust

```rust
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Debug, Clone)]
pub struct Cache<V: Clone> {
    store: Arc<RwLock<HashMap<String, V>>>,
    max_size: usize,
}

impl<V: Clone + Send + Sync + 'static> Cache<V> {
    pub fn new(max_size: usize) -> Self {
        Self {
            store: Arc::new(RwLock::new(HashMap::new())),
            max_size,
        }
    }

    pub async fn get(&self, key: &str) -> Option<V> {
        let store = self.store.read().await;
        store.get(key).cloned()
    }

    pub async fn insert(&self, key: String, value: V) -> bool {
        let mut store = self.store.write().await;
        if store.len() >= self.max_size && !store.contains_key(&key) {
            return false;
        }
        store.insert(key, value);
        true
    }
}
```

## Go

```go
package main

import (
    "context"
    "fmt"
    "sync"
    "time"
)

type Result struct {
    Value string
    Err   error
}

func fanOut(ctx context.Context, inputs []string, workers int) <-chan Result {
    results := make(chan Result, len(inputs))
    work := make(chan string, len(inputs))

    var wg sync.WaitGroup
    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for input := range work {
                select {
                case <-ctx.Done():
                    return
                default:
                    time.Sleep(100 * time.Millisecond)
                    results <- Result{Value: fmt.Sprintf("processed: %s", input)}
                }
            }
        }()
    }

    for _, input := range inputs {
        work <- input
    }
    close(work)

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

## Bash

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/deploy-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

check_deps() {
    local missing=()
    for cmd in git docker curl jq; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR: Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

deploy() {
    local env="${1:?Usage: deploy <environment>}"
    local tag="${2:-latest}"

    log "Deploying $tag to $env..."
    docker build -t "app:$tag" "$SCRIPT_DIR" 2>&1 | tee -a "$LOG_FILE"
    docker push "registry.example.com/app:$tag"
    log "Deploy complete"
}

check_deps
deploy "$@"
```

## JSON

```json
{
  "name": "mkdn",
  "version": "0.1.0",
  "description": "Mac-native Markdown viewer",
  "repository": {
    "type": "git",
    "url": "https://github.com/example/mkdn"
  },
  "features": [
    { "name": "markdown", "status": "active" },
    { "name": "mermaid", "status": "active" },
    { "name": "find-bar", "status": "active" }
  ],
  "config": {
    "theme": "solarized-dark",
    "fontSize": 14,
    "lineNumbers": true,
    "wordWrap": false
  }
}
```

## YAML

```yaml
name: CI Pipeline
on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: macos-14
    strategy:
      matrix:
        xcode: ["16.0", "16.3"]
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode-${{ matrix.xcode }}.app
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

## SQL

```sql
CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    content     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    author_id   INTEGER REFERENCES users(id)
);

SELECT
    d.title,
    u.name AS author,
    COUNT(c.id) AS comment_count,
    MAX(c.created_at) AS last_comment
FROM documents d
JOIN users u ON u.id = d.author_id
LEFT JOIN comments c ON c.document_id = d.id
WHERE d.created_at >= NOW() - INTERVAL '30 days'
GROUP BY d.id, d.title, u.name
HAVING COUNT(c.id) > 0
ORDER BY last_comment DESC
LIMIT 20;
```

## CSS

```css
:root {
  --bg-primary: #002b36;
  --fg-primary: #839496;
  --accent: #268bd2;
  --radius: 6px;
}

.markdown-body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.6;
  color: var(--fg-primary);
  max-width: 48rem;
  margin: 0 auto;
  padding: 2rem;
}

.markdown-body code {
  font-family: "SF Mono", "Menlo", monospace;
  font-size: 0.875em;
  padding: 0.2em 0.4em;
  border-radius: var(--radius);
  background: rgba(0, 0, 0, 0.15);
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg-primary: #002b36;
    --fg-primary: #839496;
  }
}
```

## HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>mkdn Preview</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <main class="markdown-body">
        <h1>Document Title</h1>
        <p>Rendered content goes here.</p>
        <pre><code class="language-swift">let x = 42</code></pre>
    </main>
    <script type="module" src="app.js"></script>
</body>
</html>
```

## Plain (No Language)

```
This is a plain code block without any language specified.
It should render in monospace with a background but no syntax highlighting.
Line numbers should still appear if enabled.

    Indented content should preserve whitespace.
	Tab-indented content too.
```
