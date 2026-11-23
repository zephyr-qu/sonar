# LocalSend Signaling Server

A signaling server for LocalSend. Using Rust and WebSockets.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `SERVER_IP` | `0.0.0.0` | Address to bind. |
| `SERVER_PORT` | `3000` | Port to bind. |
| `MAX_CONNECTIONS_PER_IP` | `10` | Concurrent WebSocket connections per IP group. |
| `MAX_REQUESTS_PER_IP_PER_HOUR` | `1000` | Client messages per IP group per hour. |
| `TRUSTED_PROXIES` | *(empty)* | Comma-separated CIDR ranges of reverse proxies whose `X-Forwarded-For` is trusted. |

Clients are grouped by IP. A group only sees, and can only send offers to, peers
in the same group, and each group has its own connection and request budget.

`X-Forwarded-For` is ignored unless the TCP peer is inside `TRUSTED_PROXIES`,
because anyone who can reach the port directly can forge the header. When it is
trusted, the address is taken from the right-most hop that is not itself a
trusted proxy; entries further left are whatever the client sent. Behind nginx or
Caddy on the same host:

```
TRUSTED_PROXIES=127.0.0.1/32,::1/128
```

Without it, every client behind the proxy lands in the proxy's own group and
shares its budget.
