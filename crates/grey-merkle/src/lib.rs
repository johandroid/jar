//! State Merklization, Merkle tries, and Merkle Mountain Ranges (Appendices D & E).
//!
//! Implements:
//! - Binary Patricia Merkle Trie with 64-byte nodes
//! - State key construction C
//! - State serialization T(σ)
//! - Well-balanced binary Merkle tree MB
//! - Constant-depth binary Merkle tree M
//! - Merkle Mountain Ranges and Belts

pub mod mmr;
pub mod state_serial;
pub mod trie;

use grey_types::config::Config;
use grey_types::state::State;
use grey_types::Hash;

/// Compute the state Merklization Mσ(σ) — compose T(σ) with merkle_root.
pub fn compute_state_root(state: &State, config: &Config) -> Hash {
    let kvs = state_serial::serialize_state(state, config);
    compute_state_root_from_kvs(&kvs)
}

/// Compute the state root from pre-serialized KV pairs.
pub fn compute_state_root_from_kvs(kvs: &[([u8; 31], Vec<u8>)]) -> Hash {
    let refs: Vec<(&[u8], &[u8])> = kvs.iter().map(|(k, v)| (k.as_slice(), v.as_slice())).collect();
    trie::merkle_root(&refs)
}

/// Compute the well-balanced binary Merkle tree root MB (eq E.1).
///
/// MB: (⟦B⟧, B → H) → H
pub fn balanced_merkle_root(leaves: &[&[u8]], hash_fn: fn(&[u8]) -> Hash) -> Hash {
    if leaves.is_empty() {
        return Hash::ZERO;
    }
    if leaves.len() == 1 {
        return hash_fn(leaves[0]);
    }

    // Build tree bottom-up
    let mut current: Vec<Hash> = leaves.iter().map(|l| hash_fn(l)).collect();

    while current.len() > 1 {
        let mut next = Vec::with_capacity((current.len() + 1) / 2);
        for i in (0..current.len()).step_by(2) {
            if i + 1 < current.len() {
                let mut combined = Vec::with_capacity(64);
                combined.extend_from_slice(&current[i].0);
                combined.extend_from_slice(&current[i + 1].0);
                next.push(hash_fn(&combined));
            } else {
                // Odd element: pair with zero hash
                let mut combined = Vec::with_capacity(64);
                combined.extend_from_slice(&current[i].0);
                combined.extend_from_slice(&Hash::ZERO.0);
                next.push(hash_fn(&combined));
            }
        }
        current = next;
    }

    current[0]
}

/// State-key constructor C (eq D.1).
///
/// Maps state component indices (and optionally service IDs) to 31-byte keys.
pub fn state_key_from_index(index: u8) -> [u8; 31] {
    let mut key = [0u8; 31];
    key[0] = index;
    key
}

/// State-key constructor C for service account components (eq D.1).
pub fn state_key_for_service(index: u8, service_id: u32) -> [u8; 31] {
    let mut key = [0u8; 31];
    let s = service_id.to_le_bytes();
    key[0] = index;
    key[1] = s[0];
    key[2] = 0;
    key[3] = s[1];
    key[4] = 0;
    key[5] = s[2];
    key[6] = 0;
    key[7] = s[3];
    key
}

/// State-key constructor C for service storage items (eq D.1).
pub fn state_key_for_storage(service_id: u32, hash: &Hash) -> [u8; 31] {
    let s = service_id.to_le_bytes();
    let a = grey_crypto::blake2b_256(&hash.0);
    let mut key = [0u8; 31];
    key[0] = s[0];
    key[1] = a.0[0];
    key[2] = s[1];
    key[3] = a.0[1];
    key[4] = s[2];
    key[5] = a.0[2];
    key[6] = s[3];
    key[7] = a.0[3];
    key[8..31].copy_from_slice(&a.0[4..27]);
    key
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_state_key_from_index() {
        let key = state_key_from_index(6);
        assert_eq!(key[0], 6);
        assert!(key[1..].iter().all(|&b| b == 0));
    }

    #[test]
    fn test_balanced_merkle_root_single() {
        let leaf = b"hello";
        let root = balanced_merkle_root(&[leaf.as_ref()], grey_crypto::blake2b_256);
        assert_ne!(root, Hash::ZERO);
    }

    #[test]
    fn test_balanced_merkle_root_empty() {
        let root = balanced_merkle_root(&[], grey_crypto::blake2b_256);
        assert_eq!(root, Hash::ZERO);
    }
}
