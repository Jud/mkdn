# API Endpoints

## Authentication

### `POST /auth/token`

Request a new access token.

```swift
struct TokenRequest: Codable {
    let clientId: String
    let clientSecret: String
    let grantType: GrantType
}
```

### `DELETE /auth/token`

Revoke an existing token.

---

## Pipelines

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/pipelines` | List all pipelines |
| `POST` | `/pipelines` | Create pipeline |
| `GET` | `/pipelines/:id` | Get pipeline details |
| `PUT` | `/pipelines/:id` | Update pipeline |
| `DELETE` | `/pipelines/:id` | Delete pipeline |

> Rate limit: 1000 requests per minute per API key.
