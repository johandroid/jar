//! Tests for state serialization T(σ) against conformance trace data.

use grey_merkle::compute_state_root_from_kvs;
use grey_merkle::state_serial::{deserialize_state, serialize_state_with_opaque};
use grey_types::config::Config;

fn load_initialize_state() -> Vec<([u8; 31], Vec<u8>)> {
    let json_str = std::fs::read_to_string(
        "../../res/conformance/fuzz-proto/examples/0.7.2/no_forks/00000001_fuzzer_initialize.json",
    )
    .expect("failed to read initialize JSON");
    let data: serde_json::Value = serde_json::from_str(&json_str).unwrap();
    let state = data["initialize"]["state"].as_array().unwrap();

    state
        .iter()
        .map(|entry| {
            let key_hex = entry["key"].as_str().unwrap();
            let val_hex = entry["value"].as_str().unwrap();
            // Strip 0x prefix
            let key_bytes = hex::decode(&key_hex[2..]).unwrap();
            let val_bytes = hex::decode(&val_hex[2..]).unwrap();
            let mut key = [0u8; 31];
            key.copy_from_slice(&key_bytes);
            (key, val_bytes)
        })
        .collect()
}

#[test]
fn test_deserialize_initialize_state() {
    let kvs = load_initialize_state();
    let config = Config::tiny();

    let (state, opaque) = deserialize_state(&kvs, &config).expect("deserialization failed");

    // Verify basic properties
    assert_eq!(state.timeslot, 0);
    assert_eq!(state.auth_pool.len(), 2); // C=2 cores
    assert_eq!(state.auth_pool[0].len(), 8); // O=8 auth pool items
    assert_eq!(state.auth_queue.len(), 80); // Q=80
    assert_eq!(state.pending_validators.len(), 6); // V=6
    assert_eq!(state.current_validators.len(), 6);
    assert_eq!(state.previous_validators.len(), 6);
    assert_eq!(state.pending_reports.len(), 2); // C=2
    assert!(state.pending_reports[0].is_none());
    assert!(state.pending_reports[1].is_none());
    assert_eq!(state.recent_blocks.headers.len(), 1);
    assert_eq!(state.judgments.good.len(), 0);
    assert_eq!(state.judgments.bad.len(), 0);
    assert_eq!(state.services.len(), 1); // 1 bootstrap service
    assert!(state.services.contains_key(&0));
    assert_eq!(state.accumulation_queue.len(), 12); // E=12
    assert_eq!(state.accumulation_history.len(), 12);
    assert_eq!(state.accumulation_outputs.len(), 0);
    assert_eq!(state.privileged_services.manager, 0);
    assert_eq!(state.privileged_services.assigner.len(), 2); // C=2

    // Check service account for bootstrap service
    let svc = &state.services[&0];
    assert_eq!(svc.balance, u64::MAX);
    assert_eq!(svc.min_accumulate_gas, 10);
    assert_eq!(svc.min_on_transfer_gas, 10);

    // Should have 4 opaque service data entries
    assert_eq!(opaque.len(), 4);
}

#[test]
fn test_roundtrip_initialize_state() {
    let kvs = load_initialize_state();
    let config = Config::tiny();

    let (state, opaque) = deserialize_state(&kvs, &config).expect("deserialization failed");

    // Re-serialize
    let re_kvs = serialize_state_with_opaque(&state, &config, &opaque);

    // Compare key-value pairs
    assert_eq!(
        re_kvs.len(),
        kvs.len(),
        "KV count mismatch: got {} expected {}",
        re_kvs.len(),
        kvs.len()
    );

    for (i, ((re_key, re_val), (orig_key, orig_val))) in
        re_kvs.iter().zip(kvs.iter()).enumerate()
    {
        assert_eq!(
            re_key, orig_key,
            "Key mismatch at entry {i}: got {} expected {}",
            hex::encode(re_key),
            hex::encode(orig_key)
        );
        assert_eq!(
            re_val, orig_val,
            "Value mismatch at entry {i} (key {}): got {} bytes expected {} bytes\n  got: {}\n  exp: {}",
            hex::encode(re_key),
            re_val.len(),
            orig_val.len(),
            hex::encode(&re_val[..re_val.len().min(80)]),
            hex::encode(&orig_val[..orig_val.len().min(80)])
        );
    }
}

#[test]
fn test_state_root_matches_expected() {
    let kvs = load_initialize_state();

    // Expected state root from conformance trace
    let expected_hex = "591de2394a0d5f71af530a794c92c37847bddaefb78e33c0c3e76c58fbb139c8";
    let expected_bytes = hex::decode(expected_hex).unwrap();
    let mut expected = [0u8; 32];
    expected.copy_from_slice(&expected_bytes);

    // Compute state root from KV pairs
    let root = compute_state_root_from_kvs(&kvs);

    assert_eq!(
        root.0, expected,
        "State root mismatch:\n  computed: {}\n  expected: {}",
        hex::encode(root.0),
        expected_hex
    );
}
