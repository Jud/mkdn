# Table Rendering Verification

## Narrow Two-Column Table

| Key | Value |
|-----|-------|
| Name | Alice |
| Age | 30 |
| City | Portland |

## Wide Multi-Column Table

| ID | Name | Email | Department | Role | Status | Start Date | Location | Manager | Team | Phone | Notes |
|----|------|-------|------------|------|--------|------------|----------|---------|------|-------|-------|
| 1 | Alice Johnson | alice@example.com | Engineering | Senior | Active | 2022-01-15 | Portland | Bob | Platform | 555-0101 | Team lead |
| 2 | Bob Smith | bob@example.com | Engineering | Manager | Active | 2020-06-01 | Seattle | Carol | Platform | 555-0102 | Director reports |
| 3 | Carol Davis | carol@example.com | Product | VP | Active | 2019-03-20 | Portland | Dan | Leadership | 555-0103 | Executive team |

## Column Alignment

| Left Aligned | Center Aligned | Right Aligned |
|:-------------|:--------------:|--------------:|
| left | center | right |
| text | text | text |
| aligned | aligned | aligned |

## Long Text Wrapping

| Setting | Description |
|---------|-------------|
| max_connections | The maximum number of simultaneous database connections that can be maintained by the connection pool. When this limit is reached, new connection requests will be queued until an existing connection is released back to the pool. |
| timeout_seconds | Specifies how long (in seconds) the system will wait for a response from the upstream service before considering the request failed and triggering the retry mechanism with exponential backoff. |
| cache_ttl | Time-to-live for cached entries in the distributed cache layer. After this duration expires, entries are marked as stale and will be refreshed on the next access. |

## Many Rows Table

| # | Item | Category | Price |
|---|------|----------|------:|
| 1 | Widget A | Hardware | 9.99 |
| 2 | Widget B | Hardware | 14.99 |
| 3 | Gadget X | Electronics | 29.99 |
| 4 | Gadget Y | Electronics | 34.99 |
| 5 | Tool Alpha | Tools | 19.99 |
| 6 | Tool Beta | Tools | 24.99 |
| 7 | Part 001 | Components | 4.99 |
| 8 | Part 002 | Components | 5.99 |
| 9 | Part 003 | Components | 6.99 |
| 10 | Part 004 | Components | 7.99 |
| 11 | Assembly Kit | Kits | 49.99 |
| 12 | Assembly Kit Pro | Kits | 79.99 |
| 13 | Connector A | Cables | 3.99 |
| 14 | Connector B | Cables | 4.99 |
| 15 | Connector C | Cables | 5.99 |

## Empty Cells

| Header A | Header B | Header C |
|----------|----------|----------|
| data | | data |
| | data | |
| data | data | |
