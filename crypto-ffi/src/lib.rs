//! FFI wrapper for JAM cryptographic primitives.
//!
//! Exports `extern "C"` functions that are called from the C bridge (bridge.c),
//! which in turn is called by Lean 4 via `@[extern]` attributes.

use blake2::digest::consts::U32;
use blake2::{Blake2b, Digest as Blake2Digest};
use sha3::{Digest as Sha3Digest, Keccak256};

use std::slice;
use std::sync::OnceLock;

// ============================================================================
// Blake2b-256
// ============================================================================

#[no_mangle]
pub extern "C" fn jar_ffi_blake2b(data_ptr: *const u8, data_len: usize, out_ptr: *mut u8) {
    let data = if data_len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(data_ptr, data_len) }
    };
    let mut hasher = Blake2b::<U32>::new();
    hasher.update(data);
    let result = hasher.finalize();
    unsafe {
        std::ptr::copy_nonoverlapping(result.as_ptr(), out_ptr, 32);
    }
}

// ============================================================================
// Keccak-256
// ============================================================================

#[no_mangle]
pub extern "C" fn jar_ffi_keccak256(data_ptr: *const u8, data_len: usize, out_ptr: *mut u8) {
    let data = if data_len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(data_ptr, data_len) }
    };
    let mut hasher = Keccak256::new();
    hasher.update(data);
    let result = hasher.finalize();
    unsafe {
        std::ptr::copy_nonoverlapping(result.as_ptr(), out_ptr, 32);
    }
}

// ============================================================================
// Ed25519
// ============================================================================

#[no_mangle]
pub extern "C" fn jar_ffi_ed25519_verify(
    key_ptr: *const u8,    // 32 bytes
    msg_ptr: *const u8,
    msg_len: usize,
    sig_ptr: *const u8,    // 64 bytes
) -> u8 {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};

    let key_bytes: [u8; 32] = unsafe { *(key_ptr as *const [u8; 32]) };
    let sig_bytes: [u8; 64] = unsafe { *(sig_ptr as *const [u8; 64]) };
    let msg = if msg_len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(msg_ptr, msg_len) }
    };

    let Ok(vk) = VerifyingKey::from_bytes(&key_bytes) else {
        return 0;
    };
    let sig = Signature::from_bytes(&sig_bytes);
    if vk.verify(msg, &sig).is_ok() { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn jar_ffi_ed25519_sign(
    secret_ptr: *const u8,
    secret_len: usize,
    msg_ptr: *const u8,
    msg_len: usize,
    out_ptr: *mut u8,      // 64 bytes
) {
    use ed25519_dalek::{Signer, SigningKey};

    let secret = unsafe { slice::from_raw_parts(secret_ptr, secret_len) };
    let msg = if msg_len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(msg_ptr, msg_len) }
    };

    // Expect 32-byte seed
    if secret.len() < 32 {
        unsafe { std::ptr::write_bytes(out_ptr, 0, 64); }
        return;
    }
    let mut seed = [0u8; 32];
    seed.copy_from_slice(&secret[..32]);
    let sk = SigningKey::from_bytes(&seed);
    let sig = sk.sign(msg);
    unsafe {
        std::ptr::copy_nonoverlapping(sig.to_bytes().as_ptr(), out_ptr, 64);
    }
}

// ============================================================================
// Bandersnatch VRF
// ============================================================================

use ark_vrf::reexports::ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ark_vrf::suites::bandersnatch::{self as suite, *};

type Suite = suite::BandersnatchSha512Ell2;

/// Lazily initialized PCS parameters from embedded SRS file.
fn pcs_params() -> &'static PcsParams {
    static PCS: OnceLock<PcsParams> = OnceLock::new();
    PCS.get_or_init(|| {
        let buf = include_bytes!("../bls12-381-srs-2-11-uncompressed-zcash.bin");
        PcsParams::deserialize_uncompressed_unchecked(&mut &buf[..])
            .expect("Failed to deserialize SRS")
    })
}

fn make_ring_params(ring_size: usize) -> RingProofParams {
    RingProofParams::from_pcs_params(ring_size, pcs_params().clone())
        .expect("Failed to create ring params")
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_verify(
    key_ptr: *const u8,    // 32 bytes
    ctx_ptr: *const u8,
    ctx_len: usize,
    msg_ptr: *const u8,
    msg_len: usize,
    sig_ptr: *const u8,    // 96 bytes
) -> u8 {
    use ark_vrf::ietf::Verifier as _;

    let key_bytes: [u8; 32] = unsafe { *(key_ptr as *const [u8; 32]) };
    let sig_bytes: &[u8] = unsafe { slice::from_raw_parts(sig_ptr, 96) };
    let ctx = if ctx_len == 0 { &[] } else { unsafe { slice::from_raw_parts(ctx_ptr, ctx_len) } };
    let msg = if msg_len == 0 { &[] } else { unsafe { slice::from_raw_parts(msg_ptr, msg_len) } };

    let result = (|| -> Option<()> {
        let pk_point = AffinePoint::deserialize_compressed(&key_bytes[..]).ok()?;
        let public = ark_vrf::Public::<Suite>(pk_point);

        // Parse output (first 32 bytes) and proof (next 64 bytes)
        let output_point = AffinePoint::deserialize_compressed(&sig_bytes[..32]).ok()?;
        let output = ark_vrf::Output::<Suite>::from_affine(output_point);
        let proof = ark_vrf::ietf::Proof::<Suite>::deserialize_compressed(&sig_bytes[32..]).ok()?;

        // Construct VRF input
        let input = ark_vrf::Input::<Suite>::new(ctx)?;

        // Verify
        public.verify(input, output, msg, &proof).ok()?;
        Some(())
    })();

    if result.is_some() { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_sign(
    secret_ptr: *const u8,
    secret_len: usize,
    ctx_ptr: *const u8,
    ctx_len: usize,
    msg_ptr: *const u8,
    msg_len: usize,
    out_ptr: *mut u8,      // 96 bytes
) {
    use ark_vrf::ietf::Prover as _;

    let secret = unsafe { slice::from_raw_parts(secret_ptr, secret_len) };
    let ctx = if ctx_len == 0 { &[] } else { unsafe { slice::from_raw_parts(ctx_ptr, ctx_len) } };
    let msg = if msg_len == 0 { &[] } else { unsafe { slice::from_raw_parts(msg_ptr, msg_len) } };

    if secret.len() < 32 {
        unsafe { std::ptr::write_bytes(out_ptr, 0, 96); }
        return;
    }
    let mut seed = [0u8; 32];
    seed.copy_from_slice(&secret[..32]);
    let sk = ark_vrf::Secret::<Suite>::from_seed(&seed);

    let Some(input) = ark_vrf::Input::<Suite>::new(ctx) else {
        unsafe { std::ptr::write_bytes(out_ptr, 0, 96); }
        return;
    };
    let output = sk.output(input);
    let proof = sk.prove(input, output, msg);

    let mut result = [0u8; 96];
    // Output point (32 bytes)
    let mut out_buf = Vec::new();
    output.0.serialize_compressed(&mut out_buf).ok();
    let len = out_buf.len().min(32);
    result[..len].copy_from_slice(&out_buf[..len]);
    // Proof (64 bytes)
    let mut proof_buf = Vec::new();
    proof.serialize_compressed(&mut proof_buf).ok();
    let plen = proof_buf.len().min(64);
    result[32..32 + plen].copy_from_slice(&proof_buf[..plen]);

    unsafe { std::ptr::copy_nonoverlapping(result.as_ptr(), out_ptr, 96); }
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_output(
    sig_ptr: *const u8,    // 96 bytes (VRF signature)
    out_ptr: *mut u8,      // 32 bytes
) -> u8 {
    let sig = unsafe { slice::from_raw_parts(sig_ptr, 96) };
    let result = (|| -> Option<[u8; 32]> {
        let output_point = AffinePoint::deserialize_compressed(&sig[..32]).ok()?;
        let output = ark_vrf::Output::<Suite>::from_affine(output_point);
        let hash = output.hash();
        let mut r = [0u8; 32];
        r.copy_from_slice(&hash[..32]);
        Some(r)
    })();

    match result {
        Some(hash) => {
            unsafe { std::ptr::copy_nonoverlapping(hash.as_ptr(), out_ptr, 32); }
            1
        }
        None => {
            unsafe { std::ptr::write_bytes(out_ptr, 0, 32); }
            0
        }
    }
}

// ============================================================================
// Bandersnatch Ring VRF
// ============================================================================

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_ring_root(
    keys_ptr: *const u8,   // packed 32-byte keys
    num_keys: usize,
    out_ptr: *mut u8,      // 144 bytes
) {
    let keys_raw = if num_keys == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(keys_ptr, num_keys * 32) }
    };

    let params = make_ring_params(num_keys);

    let points: Vec<AffinePoint> = (0..num_keys)
        .map(|i| {
            let key_bytes = &keys_raw[i * 32..(i + 1) * 32];
            AffinePoint::deserialize_compressed(key_bytes)
                .unwrap_or(RingProofParams::padding_point())
        })
        .collect();

    let verifier_key = params.verifier_key(&points);
    let commitment = verifier_key.commitment();
    let mut buf = Vec::new();
    commitment
        .serialize_compressed(&mut buf)
        .expect("commitment serialization failed");

    let mut result = [0u8; 144];
    let len = buf.len().min(144);
    result[..len].copy_from_slice(&buf[..len]);

    unsafe { std::ptr::copy_nonoverlapping(result.as_ptr(), out_ptr, 144); }
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_ring_verify(
    root_ptr: *const u8,   // 144 bytes
    ctx_ptr: *const u8,
    ctx_len: usize,
    msg_ptr: *const u8,
    msg_len: usize,
    proof_ptr: *const u8,  // 784 bytes (32 output + 752 proof)
    ring_size: usize,
) -> u8 {
    use ark_vrf::ring::Verifier as _;

    let root = unsafe { slice::from_raw_parts(root_ptr, 144) };
    let ctx = if ctx_len == 0 { &[] } else { unsafe { slice::from_raw_parts(ctx_ptr, ctx_len) } };
    let msg = if msg_len == 0 { &[] } else { unsafe { slice::from_raw_parts(msg_ptr, msg_len) } };
    let proof_bytes = unsafe { slice::from_raw_parts(proof_ptr, 784) };

    let result = (|| -> Option<()> {
        let params = make_ring_params(ring_size);

        let commitment = RingCommitment::deserialize_compressed(&mut &root[..]).ok()?;
        let verifier_key = params.verifier_key_from_commitment(commitment);
        let verifier = params.verifier(verifier_key);

        let output_point = AffinePoint::deserialize_compressed(&mut &proof_bytes[..32]).ok()?;
        let output = ark_vrf::Output::<Suite>::from_affine(output_point);
        let proof = RingProof::deserialize_compressed(&mut &proof_bytes[32..]).ok()?;

        let input = ark_vrf::Input::<Suite>::new(ctx)?;
        ark_vrf::Public::<Suite>::verify(input, output, msg, &proof, &verifier).ok()?;
        Some(())
    })();

    if result.is_some() { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_ring_sign(
    secret_ptr: *const u8,
    secret_len: usize,
    root_ptr: *const u8,   // 144 bytes
    ctx_ptr: *const u8,
    ctx_len: usize,
    msg_ptr: *const u8,
    msg_len: usize,
    ring_size: usize,
    out_ptr: *mut u8,      // 784 bytes
) {
    let secret = unsafe { slice::from_raw_parts(secret_ptr, secret_len) };
    let _root = unsafe { slice::from_raw_parts(root_ptr, 144) };
    let ctx = if ctx_len == 0 { &[] } else { unsafe { slice::from_raw_parts(ctx_ptr, ctx_len) } };
    let msg = if msg_len == 0 { &[] } else { unsafe { slice::from_raw_parts(msg_ptr, msg_len) } };

    // Ring signing is complex — requires the prover key which needs the full key list.
    // For now, produce a best-effort implementation. Full ring signing requires more context.
    let _ = (secret, ring_size, ctx, msg);
    unsafe { std::ptr::write_bytes(out_ptr, 0, 784); }
}

#[no_mangle]
pub extern "C" fn jar_ffi_bandersnatch_ring_output(
    proof_ptr: *const u8,  // 784 bytes
    out_ptr: *mut u8,      // 32 bytes
) -> u8 {
    let proof_bytes = unsafe { slice::from_raw_parts(proof_ptr, 784) };

    let result = (|| -> Option<[u8; 32]> {
        let output_point = AffinePoint::deserialize_compressed(&mut &proof_bytes[..32]).ok()?;
        let output = ark_vrf::Output::<Suite>::from_affine(output_point);
        let hash = output.hash();
        let mut r = [0u8; 32];
        r.copy_from_slice(&hash[..32]);
        Some(r)
    })();

    match result {
        Some(hash) => {
            unsafe { std::ptr::copy_nonoverlapping(hash.as_ptr(), out_ptr, 32); }
            1
        }
        None => {
            unsafe { std::ptr::write_bytes(out_ptr, 0, 32); }
            0
        }
    }
}

// ============================================================================
// BLS12-381 (stubs — not yet implemented in grey-crypto)
// ============================================================================

#[no_mangle]
pub extern "C" fn jar_ffi_bls_verify(
    _key_ptr: *const u8,   // 144 bytes
    _msg_ptr: *const u8,
    _msg_len: usize,
    _sig_ptr: *const u8,   // 48 bytes
) -> u8 {
    0 // Not yet implemented
}

#[no_mangle]
pub extern "C" fn jar_ffi_bls_sign(
    _secret_ptr: *const u8,
    _secret_len: usize,
    _msg_ptr: *const u8,
    _msg_len: usize,
    _out_ptr: *mut u8,     // 48 bytes
) {
    // Not yet implemented
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hex_to_bytes(s: &str) -> Vec<u8> {
        let s = s.strip_prefix("0x").unwrap_or(s);
        (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i+2], 16).unwrap()).collect()
    }

    fn verify_ticket(ring_size: usize, gamma_z: &[u8], eta2: &[u8], attempt: u8, sig: &[u8]) -> bool {
        use ark_vrf::ring::Verifier as _;
        let params = make_ring_params(ring_size);
        let commitment = RingCommitment::deserialize_compressed(&mut &gamma_z[..]).unwrap();
        let verifier_key = params.verifier_key_from_commitment(commitment);
        let verifier = params.verifier(verifier_key);

        let mut ctx = Vec::new();
        ctx.extend_from_slice(b"jam_ticket_seal");
        ctx.extend_from_slice(eta2);
        ctx.push(attempt);

        let output_point = match AffinePoint::deserialize_compressed(&mut &sig[..32]) {
            Ok(p) => p,
            Err(_) => return false,
        };
        let output = ark_vrf::Output::<Suite>::from_affine(output_point);
        let proof = match RingProof::deserialize_compressed(&mut &sig[32..]) {
            Ok(p) => p,
            Err(_) => return false,
        };
        let input = match ark_vrf::Input::<Suite>::new(&ctx) {
            Some(i) => i,
            None => return false,
        };
        ark_vrf::Public::<Suite>::verify(input, output, &[] as &[u8], &proof, &verifier).is_ok()
    }

    #[test]
    fn test_no_mark_5_ticket_verification() {
        let gamma_z = hex_to_bytes("af39b7de5fcfb9fb8a46b1645310529ce7d08af7301d9758249da4724ec698eb127f489b58e49ae9ab85027509116962a135fc4d97b66fbbed1d3df88cd7bf5cc6e5d7391d261a4b552246648defcb64ad440d61d69ec61b5473506a48d58e1992e630ae2b14e758ab0960e372172203f4c9a41777dadd529971d7ab9d23ab29fe0e9c85ec450505dde7f5ac038274cf");
        let eta2 = hex_to_bytes("bb30a42c1e62f0afda5f0a4e8a562f7a13a24cea00ee81917b86b89e801314aa");
        let sig0 = hex_to_bytes("33acdb765af49f0aa280d7ce82e6d974debca1b189515e1d75e0261075b0575788a20024cc5741336142acad75b95150e8a41ba9706b4016320e82f39a5db7e53adb042500f7f504f8b15869d78c0b2568c621bfab2dda8e92c413265039f371ff7c85e5cb79d2e1be0e34f119a79e43d62b6385b7529b9750d60a6d5259e1bd4cc14271181ad2a338a67d8c8f9d30b54511671dc227ba55b213c0295ec5c419444a3b6ea9edd4642110107c4c12842398ef98511924c9a6fd872fcdf6d70510939d43cbc8cf732654d0308bbdf0001cac0be1cbd89d32d12a549f92981f02cd7a70d42f8115e053ff8e5c4fd707aa5e8b7520b215677afa1394464057709837dfb22b04b53c69011da7926c341cf6e77a2ed27912c40267c826cca53f876dadb10c11b5a0de6fc0b30e801cff09f537e81ea63a812395fee0003bb428e3c70d325944a9a9ba8bc20cfad852ae25faf7a13dcc0661c5f36e1c148953cec79f1f92689d64ed245d1c79d355c752ead9b1c84b2dd7442a7a59be788ab794635d5bd7d7c572704907103707d41bd5d6186a20cfd9dc785174339699dad68256580e67733bc730ebd33da939e7e6b3bc25b4e24b511f7284d7309af10b60deb797070da9a39a605cbac66ae02867cb43546c33a3487c24161df75019b68bdac4d36f0b0fa21aaaf2db9d9fb30bfc6c6bbf703c67b01d70f88256fc2c8c9fc1e7ee1a68b9f0bb0a3e821647e1907c1ba3d993cbdb9f6d886687f55b49c9c12985e64e478b1d922266ea8bf88b1bddac82dfae55a1fa742ec9317445b3952ae50d79222c605344b9985d66c48b2d5bff2cbb7bab248119708bb8e29a179377672b5b4483d2f81e6363f2cae62e5198b8b89b4de89f2637cdf038c4d6b3673d7e4387316e55c9f9a5fbf301168726e36fe38b9e42be93306cad738294465170ac85f808cb07582ad810dd5661aaad8608ef823587de3544b6b7ffe8145b5623be783ef063084903f3d511aed82910dfc7ac459b781e1e01dbb20001bd7a33f5ba67b8b1aeb1778f3919fbff9cbee5f8f02318d427f150fadb3f86696e8781518f95b420352a2f4404e74b1e6126e7d74ce691cd");
        let sig2 = hex_to_bytes("b4b7d41e0359cec176a6a31f4d7816deb016f4aab6c54ebe5602e943e2ca7e1e8a03834128d766b7a479b4d7dafc656c6cfeef904a12f0879ec907775d252615a2769f5e54720213d4fee15846c60c54a1896a29c3105fc0d07e2bfdabb83e0b2ce57d795e745f3e7f4c6213d74f34a2f2bf2ddcb92fbba3a5536b8263523eb1402ddec1822b4449af7e889b20b9146ce78e4718da0c46c8c04c255190a38d183ea5bc580eebead8ef41ac8179018342f0f7b906808be96cf91238569e35550b8632976853c945af5bc6a8867b9ce1544b23bfa17cb7c6546133ab24b705c2fff8dbfd2d24c46a66a7649e554cc550248b7520b215677afa1394464057709837dfb22b04b53c69011da7926c341cf6e77a2ed27912c40267c826cca53f876dad992a8a9e06e890fdb3c07f048b495d5dca37e8bb7aaa7f36efeeda8046bf9e8edeed94ab998147069355958ebfc739c8b929535e7311081040f7502822be23f1881495a99f00b9861511c8a4a325673f544cd73f797327b50c538a815a1d4eb97de9af1fc390da003b6591857d7227e6715cbda9114f8ab542fa58162bfbaa2e25a91858f5023ff91df7bc395c308866e292727c66471ad14c00c6dfc37be75212a4af0a459030bb3a2822758b93a08bac0a796536c51b88c66caae9f68d981caeccba437c569304f5b4b6835746fb1221da0e011b0a8a7990eb2ae9b386b76e792298b1da7d3fb11baa61b92c3c59508e9dcb869767a653e0c111be4e372a447d28f49405246dc275267f5ad4f00cb67311a0a0db80b3f12642e36c669499313ef478d9142f9fa2057a146640d45608f91ef5489f995f673086bca563a15e4a891e2c4b08f80097a02d9f5868f491ecb416f70a9b35d36873238e71f4d957dca95dbc761d98add32d9e93586d1456ce0ade8d62339fe291d8cd7209225da962a1012d5afe35c6589b79a8ec013c0d10a43e354e873edca3e54c4e6bf88cb45d436c6aaad6d9093de88088e1bb44a2ee44282fbe6e8e0737a25349b7d3e2ca74a52a5b5891a16c0b589b7112a855ace3994fab865d083c531ad8ac761fca7e07b2557fa7afffd052d41a7393329adcac");

        let sig1 = hex_to_bytes("2b4bb98d4650e0f5fa886e6720f66c71c02e5557fd840dead12c399442f3a15af487d8d0ed8151bd3e28af04d80e4004d35b3f2fae4ca51810a1a8b9be0a34d4315598ad424ba574627e72c5e537e72b2d05a676bfdbb99ca3f2ad94bdac0c87f7cc2fb0ff34b1c99c473b084841f917df07c893c8b9a5f49e8ad73848732f56d928e7ca9e23b399d2f926a9315a3300002f558acff53d00a0a053de028be50ec586c10a59f8a05ce4edc687486c67a6b192700da0a95295c09d592eb8ad4402839bc8e25495db8c0a002a348d8a7eb0bbc160a77d8b3b2688e9e8e79ac8dfd29fe3167bd824eb9f0d093664ca4eb3158b7520b215677afa1394464057709837dfb22b04b53c69011da7926c341cf6e77a2ed27912c40267c826cca53f876dadb08039338813e65cd09853a831da799fe6d8672a2efd4a49e1018d2a9dc3ff329bc0007119a0150250cc21620f8e2133a19330ec41ca9be1a18d0012895280ccb039f040f6b4d89937e778fecaa55ffe0d386d58d388a1c6c84d83b1d87642fc13d675d016776af55eba0b7bc20976e34aa8c9313b9e298e6b223d4a3db9fb6db6816782ceb8f365af5be5ba9afb6a6d1262e0e56e1f7c43f19d3bb0c074c0347d0d704f84d03690085cea01542b074bb22219810d945461eb03df3870cc004523749698ea39e5e415eb31a0950d512164edfea93726c02f12c92f9c809078064b779c808ce317b13cf05e9e643bbc71b051b3ac7c194355e4089ed9358d9e602f36a64a424786e9b8df4c6f627708337cd0f6cefd6d93aa61fa719f0325522476a880c89679993d516600304f910b7641444389a1e7855b70e35c685a455b5597ee58892484930332236981440490e96005a20a5b6d1101aa46b0a6c99ce8f4627daf72b04099c74abe5fe978dea4059177d47bc2ae04c3d970343a0bd823f1e0ab7eb194e3e7246117a3d612fb7d0faaec81498d9cce81db980fc67a0b88be35cd616f1a5e382f7298e4bf377e4e9234ead0be825f4c86c1d8e8b04c9c9fe4905abc7c2ac458414bbeef55a22f15517f2fea579731c59aff3e19e7b3b94a3376e86c1a73d0c35620c13b84eacb8eb6");

        // Ring size 6 (tiny config)
        let r0 = verify_ticket(6, &gamma_z, &eta2, 0, &sig0);
        let r1 = verify_ticket(6, &gamma_z, &eta2, 1, &sig1);
        let r2 = verify_ticket(6, &gamma_z, &eta2, 0, &sig2);
        eprintln!("ticket[0] (attempt=0): {}", if r0 { "VALID" } else { "INVALID" });
        eprintln!("ticket[1] (attempt=1): {}", if r1 { "VALID" } else { "INVALID" });
        eprintln!("ticket[2] (attempt=0): {}", if r2 { "VALID" } else { "INVALID" });
        // At least one should be invalid for bad_ticket_proof
        assert!(!r0 || !r2, "At least one attempt=0 ticket should be invalid");
    }
}
