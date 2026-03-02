# FROST Signing Session

Two-round threshold signing over secp256k1. Each signer commits nonces, then produces a partial signature — the coordinator aggregates into a single BIP-340 Schnorr signature indistinguishable from a solo key.

```rust
let config = SigningConfig::new(msg_hash, execution_id, vec![1, 2])?
    .with_signing_mode(SigningMode::TaprootKeyPath);
let mut session = SigningSession::new(&key_share, config, None)?;

// Round 1 — broadcast nonce commitments
let commitments = session.generate_messages()?;
session.process_messages(&peer_commitments)?;

// Round 2 — broadcast partial signatures
let partials = session.generate_messages()?;
session.process_messages(&peer_partials)?;

let signature = session.finalize()?; // 64-byte BIP-340 Schnorr
```

## Nonce Safety

`SecNonceHolder` enforces single-use nonces at the type level — no `Clone`, no `Serialize`, consumed via `take()`. A reuse attempt returns an error before any cryptographic operation runs.

```rust
pub struct SecNonceHolder(Option<FrostSigningNonces>);

impl SecNonceHolder {
    pub const fn new(nonces: FrostSigningNonces) -> Self {
        Self(Some(nonces))
    }

    /// Consumes the nonces — the only way to access them for signing.
    /// After this call, the holder is empty and cannot produce nonces again.
    pub const fn take(&mut self) -> Option<FrostSigningNonces> {
        self.0.take()
    }
}

// No Clone, no Serialize — non-content-revealing Debug
impl fmt::Debug for SecNonceHolder {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SecNonceHolder")
            .field("status", if self.0.is_some() { &"available" } else { &"consumed" })
            .finish_non_exhaustive()
    }
}
```

## Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Curve | secp256k1 (Taproot) | `frost-secp256k1-tr` crate |
| Threshold | 2-of-3 | Any 2 signers produce a valid sig |
| Signing mode | Taproot key-path | tweak = `hashTapTweak(P.x)` |
| Nonce safety | `SecNonceHolder` | No Clone, no Serialize, single-use `take()` |
| Output | 64-byte Schnorr | Indistinguishable from solo key |
| Spec | RFC 9591 | FROST for Schnorr signatures |
