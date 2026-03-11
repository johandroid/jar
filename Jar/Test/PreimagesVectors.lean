import Jar.Test.Preimages

/-! Auto-generated preimages test vectors. Do not edit. -/

namespace Jar.Test.PreimagesVectors

open Jar.Test.Preimages

def hexToBytes (s : String) : ByteArray :=
  let chars := s.toList
  let nibble (c : Char) : UInt8 :=
    if c.toNat >= 48 && c.toNat <= 57 then (c.toNat - 48).toUInt8
    else if c.toNat >= 97 && c.toNat <= 102 then (c.toNat - 87).toUInt8
    else if c.toNat >= 65 && c.toNat <= 70 then (c.toNat - 55).toUInt8
    else 0
  let rec go (cs : List Char) (acc : ByteArray) : ByteArray :=
    match cs with
    | hi :: lo :: rest => go rest (acc.push ((nibble hi <<< 4) ||| nibble lo))
    | _ => acc
  go chars ByteArray.empty

def hexSeq (s : String) : OctetSeq n := ⟨hexToBytes s, sorry⟩

-- ============================================================================
-- preimage_needed-1.json
-- ============================================================================

def preimage_needed_1_pre_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[37, 40] }]
}

def preimage_needed_1_pre : TPState := {
  accounts := #[preimage_needed_1_pre_acct_0]
}

def preimage_needed_1_post_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[37, 40] }]
}

def preimage_needed_1_post : TPState := {
  accounts := #[preimage_needed_1_post_acct_0]
}

def preimage_needed_1_input : TPInput := {
  preimages := #[],
  slot := 42
}

def preimage_needed_1_result : TPResult := .ok

-- ============================================================================
-- preimage_needed-2.json
-- ============================================================================

def preimage_needed_2_pre_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[37, 40] }]
}

def preimage_needed_2_pre : TPState := {
  accounts := #[preimage_needed_2_pre_acct_0]
}

def preimage_needed_2_post_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[43] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[37, 40] }]
}

def preimage_needed_2_post : TPState := {
  accounts := #[preimage_needed_2_post_acct_0]
}

def preimage_needed_2_input_preimage_0 : TPPreimage := {
  requester := 3,
  blob := hexToBytes "92cdf578c47085a5992256f0dcf97d0b19f1f1c9de4d5fe30c3ace6191b6e5dbcee1b3419782ad92ec2dffed6d3f" }

def preimage_needed_2_input : TPInput := {
  preimages := #[preimage_needed_2_input_preimage_0],
  slot := 43
}

def preimage_needed_2_result : TPResult := .ok

-- ============================================================================
-- preimage_not_needed-1.json
-- ============================================================================

def preimage_not_needed_1_pre_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[] }]
}

def preimage_not_needed_1_pre : TPState := {
  accounts := #[preimage_not_needed_1_pre_acct_0]
}

def preimage_not_needed_1_post_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[] }]
}

def preimage_not_needed_1_post : TPState := {
  accounts := #[preimage_not_needed_1_post_acct_0]
}

def preimage_not_needed_1_input_preimage_0 : TPPreimage := {
  requester := 3,
  blob := hexToBytes "31237cdb79ae1dfa7ffb87cde7ea8a80352d300ee5ac758a6cddd19d671925ec973d6a912166c954916057eb6a07d3e8" }

def preimage_not_needed_1_input_preimage_1 : TPPreimage := {
  requester := 3,
  blob := hexToBytes "92cdf578c47085a5992256f0dcf97d0b19f1f1c9de4d5fe30c3ace6191b6e5dbcee1b3419782ad92ec2dffed6d3f" }

def preimage_not_needed_1_input : TPInput := {
  preimages := #[preimage_not_needed_1_input_preimage_0, preimage_not_needed_1_input_preimage_1],
  slot := 42
}

def preimage_not_needed_1_result : TPResult := .err "preimage_unneeded"

-- ============================================================================
-- preimage_not_needed-2.json
-- ============================================================================

def preimage_not_needed_2_pre_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[39] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[] }]
}

def preimage_not_needed_2_pre : TPState := {
  accounts := #[preimage_not_needed_2_pre_acct_0]
}

def preimage_not_needed_2_post_acct_0 : TPServiceAccount := {
  serviceId := 3,
  blobHashes := #[hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9"],
  requests := #[
      { hash := hexSeq "9e0e7d324d129dfbd86462546e6c3aaa533bb6f2079c639f85943c95a53a70a9", length := 46, timeslots := #[39] },
      { hash := hexSeq "b9de73a1057386205aed59c4dbfda7fcfc1b83aa95ad20583dfa3611253f74c2", length := 48, timeslots := #[] }]
}

def preimage_not_needed_2_post : TPState := {
  accounts := #[preimage_not_needed_2_post_acct_0]
}

def preimage_not_needed_2_input_preimage_0 : TPPreimage := {
  requester := 3,
  blob := hexToBytes "31237cdb79ae1dfa7ffb87cde7ea8a80352d300ee5ac758a6cddd19d671925ec973d6a912166c954916057eb6a07d3e8" }

def preimage_not_needed_2_input_preimage_1 : TPPreimage := {
  requester := 3,
  blob := hexToBytes "92cdf578c47085a5992256f0dcf97d0b19f1f1c9de4d5fe30c3ace6191b6e5dbcee1b3419782ad92ec2dffed6d3f" }

def preimage_not_needed_2_input : TPInput := {
  preimages := #[preimage_not_needed_2_input_preimage_0, preimage_not_needed_2_input_preimage_1],
  slot := 42
}

def preimage_not_needed_2_result : TPResult := .err "preimage_unneeded"

-- ============================================================================
-- preimages_order_check-1.json
-- ============================================================================

def preimages_order_check_1_pre_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_1_pre_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_1_pre : TPState := {
  accounts := #[preimages_order_check_1_pre_acct_0, preimages_order_check_1_pre_acct_1]
}

def preimages_order_check_1_post_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_1_post_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_1_post : TPState := {
  accounts := #[preimages_order_check_1_post_acct_0, preimages_order_check_1_post_acct_1]
}

def preimages_order_check_1_input_preimage_0 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_1_input_preimage_1 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "41d18b0eedffee723a3800f3031d661f87b2a031ff7153b388331a0f901169f4f8190d6a7b67ac166ee75903cc2b83bbfc7cf95282a951c6cafdf202eeda0389" }

def preimages_order_check_1_input_preimage_2 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_1_input_preimage_3 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "bc890746a85a8f8becb88c8cce9517de85e9054d5ab8329a915535c8782ed4f2a4b85accb44577024e652afc240951effe40ace3d31fd2" }

def preimages_order_check_1_input_preimage_4 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "32c82fd887447c2af6cf43c6b2ff5686d00238bac1a3da0500a4cec53cc1255a84febbebbafa3da27e83e645065dbf68a2" }

def preimages_order_check_1_input : TPInput := {
  preimages := #[preimages_order_check_1_input_preimage_0, preimages_order_check_1_input_preimage_1, preimages_order_check_1_input_preimage_2, preimages_order_check_1_input_preimage_3, preimages_order_check_1_input_preimage_4],
  slot := 42
}

def preimages_order_check_1_result : TPResult := .err "preimages_not_sorted_unique"

-- ============================================================================
-- preimages_order_check-2.json
-- ============================================================================

def preimages_order_check_2_pre_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_2_pre_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_2_pre : TPState := {
  accounts := #[preimages_order_check_2_pre_acct_0, preimages_order_check_2_pre_acct_1]
}

def preimages_order_check_2_post_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_2_post_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_2_post : TPState := {
  accounts := #[preimages_order_check_2_post_acct_0, preimages_order_check_2_post_acct_1]
}

def preimages_order_check_2_input_preimage_0 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_2_input_preimage_1 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "bc890746a85a8f8becb88c8cce9517de85e9054d5ab8329a915535c8782ed4f2a4b85accb44577024e652afc240951effe40ace3d31fd2" }

def preimages_order_check_2_input_preimage_2 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "41d18b0eedffee723a3800f3031d661f87b2a031ff7153b388331a0f901169f4f8190d6a7b67ac166ee75903cc2b83bbfc7cf95282a951c6cafdf202eeda0389" }

def preimages_order_check_2_input_preimage_3 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_2_input_preimage_4 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "32c82fd887447c2af6cf43c6b2ff5686d00238bac1a3da0500a4cec53cc1255a84febbebbafa3da27e83e645065dbf68a2" }

def preimages_order_check_2_input : TPInput := {
  preimages := #[preimages_order_check_2_input_preimage_0, preimages_order_check_2_input_preimage_1, preimages_order_check_2_input_preimage_2, preimages_order_check_2_input_preimage_3, preimages_order_check_2_input_preimage_4],
  slot := 42
}

def preimages_order_check_2_result : TPResult := .err "preimages_not_sorted_unique"

-- ============================================================================
-- preimages_order_check-3.json
-- ============================================================================

def preimages_order_check_3_pre_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_3_pre_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_3_pre : TPState := {
  accounts := #[preimages_order_check_3_pre_acct_0, preimages_order_check_3_pre_acct_1]
}

def preimages_order_check_3_post_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3"],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[42] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[42] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[42] }]
}

def preimages_order_check_3_post_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2"],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[42] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[42] }]
}

def preimages_order_check_3_post : TPState := {
  accounts := #[preimages_order_check_3_post_acct_0, preimages_order_check_3_post_acct_1]
}

def preimages_order_check_3_input_preimage_0 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_3_input_preimage_1 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "41d18b0eedffee723a3800f3031d661f87b2a031ff7153b388331a0f901169f4f8190d6a7b67ac166ee75903cc2b83bbfc7cf95282a951c6cafdf202eeda0389" }

def preimages_order_check_3_input_preimage_2 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "bc890746a85a8f8becb88c8cce9517de85e9054d5ab8329a915535c8782ed4f2a4b85accb44577024e652afc240951effe40ace3d31fd2" }

def preimages_order_check_3_input_preimage_3 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_3_input_preimage_4 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "32c82fd887447c2af6cf43c6b2ff5686d00238bac1a3da0500a4cec53cc1255a84febbebbafa3da27e83e645065dbf68a2" }

def preimages_order_check_3_input : TPInput := {
  preimages := #[preimages_order_check_3_input_preimage_0, preimages_order_check_3_input_preimage_1, preimages_order_check_3_input_preimage_2, preimages_order_check_3_input_preimage_3, preimages_order_check_3_input_preimage_4],
  slot := 42
}

def preimages_order_check_3_result : TPResult := .ok

-- ============================================================================
-- preimages_order_check-4.json
-- ============================================================================

def preimages_order_check_4_pre_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_4_pre_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_4_pre : TPState := {
  accounts := #[preimages_order_check_4_pre_acct_0, preimages_order_check_4_pre_acct_1]
}

def preimages_order_check_4_post_acct_0 : TPServiceAccount := {
  serviceId := 36,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "cbf9cf279f782a3cafa94405ce2b3b1a1137d3fd6b44a371340476c385b434b3", length := 55, timeslots := #[] }]
}

def preimages_order_check_4_post_acct_1 : TPServiceAccount := {
  serviceId := 45,
  blobHashes := #[],
  requests := #[
      { hash := hexSeq "08a3ce25231d42c7568035069afebbba261f03a6385eedcdae053786f170fcad", length := 62, timeslots := #[] },
      { hash := hexSeq "23aabcb0edb291800d75e22318684d45f456c9993fd6451a87ae2267d8d375aa", length := 64, timeslots := #[] },
      { hash := hexSeq "b35ab4df967382c1c3744d681e8bfa1f62e9da21602266d1c9d3ecd3be0509d2", length := 49, timeslots := #[] }]
}

def preimages_order_check_4_post : TPState := {
  accounts := #[preimages_order_check_4_post_acct_0, preimages_order_check_4_post_acct_1]
}

def preimages_order_check_4_input_preimage_0 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_4_input_preimage_1 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "41d18b0eedffee723a3800f3031d661f87b2a031ff7153b388331a0f901169f4f8190d6a7b67ac166ee75903cc2b83bbfc7cf95282a951c6cafdf202eeda0389" }

def preimages_order_check_4_input_preimage_2 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "41d18b0eedffee723a3800f3031d661f87b2a031ff7153b388331a0f901169f4f8190d6a7b67ac166ee75903cc2b83bbfc7cf95282a951c6cafdf202eeda0389" }

def preimages_order_check_4_input_preimage_3 : TPPreimage := {
  requester := 36,
  blob := hexToBytes "bc890746a85a8f8becb88c8cce9517de85e9054d5ab8329a915535c8782ed4f2a4b85accb44577024e652afc240951effe40ace3d31fd2" }

def preimages_order_check_4_input_preimage_4 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "1ecde3797f16db94bf43546bd6c022ad0534d29ca8f696a43de5bdc95f3c80e5f18092b4bdc3e0ae426801db0331f60f26a8801d5226c5b05dec33729752" }

def preimages_order_check_4_input_preimage_5 : TPPreimage := {
  requester := 45,
  blob := hexToBytes "32c82fd887447c2af6cf43c6b2ff5686d00238bac1a3da0500a4cec53cc1255a84febbebbafa3da27e83e645065dbf68a2" }

def preimages_order_check_4_input : TPInput := {
  preimages := #[preimages_order_check_4_input_preimage_0, preimages_order_check_4_input_preimage_1, preimages_order_check_4_input_preimage_2, preimages_order_check_4_input_preimage_3, preimages_order_check_4_input_preimage_4, preimages_order_check_4_input_preimage_5],
  slot := 43
}

def preimages_order_check_4_result : TPResult := .err "preimages_not_sorted_unique"

-- ============================================================================
-- Test Runner
-- ============================================================================

end Jar.Test.PreimagesVectors

open Jar.Test.Preimages Jar.Test.PreimagesVectors in
def main : IO Unit := do
  IO.println "Running preimages test vectors..."
  let mut passed := (0 : Nat)
  let mut failed := (0 : Nat)
  if (← runTest "preimage_needed_1" preimage_needed_1_pre preimage_needed_1_input preimage_needed_1_result preimage_needed_1_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimage_needed_2" preimage_needed_2_pre preimage_needed_2_input preimage_needed_2_result preimage_needed_2_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimage_not_needed_1" preimage_not_needed_1_pre preimage_not_needed_1_input preimage_not_needed_1_result preimage_not_needed_1_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimage_not_needed_2" preimage_not_needed_2_pre preimage_not_needed_2_input preimage_not_needed_2_result preimage_not_needed_2_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimages_order_check_1" preimages_order_check_1_pre preimages_order_check_1_input preimages_order_check_1_result preimages_order_check_1_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimages_order_check_2" preimages_order_check_2_pre preimages_order_check_2_input preimages_order_check_2_result preimages_order_check_2_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimages_order_check_3" preimages_order_check_3_pre preimages_order_check_3_input preimages_order_check_3_result preimages_order_check_3_post)
  then passed := passed + 1
  else failed := failed + 1
  if (← runTest "preimages_order_check_4" preimages_order_check_4_pre preimages_order_check_4_input preimages_order_check_4_result preimages_order_check_4_post)
  then passed := passed + 1
  else failed := failed + 1
  IO.println s!"Preimages: {passed} passed, {failed} failed out of 8"
  if failed > 0 then
    IO.Process.exit 1
