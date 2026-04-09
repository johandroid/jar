import Jar.Crypto

/-!
# Crypto Proofs

Properties of the Fisher-Yates shuffle and pseudorandom sequence generation:
length preservation and composition.
-/

namespace Jar.Proofs

-- ============================================================================
-- seqFromHash length
-- ============================================================================

/-- seqFromHash always produces exactly l elements. -/
theorem seqFromHash_size (l : Nat) (h : Hash) :
    (Jar.Crypto.seqFromHash l h).size = l := by
  unfold Jar.Crypto.seqFromHash
  simp [Array.size_ofFn]

/-- seqFromHash with 0 length produces an empty array. -/
theorem seqFromHash_zero (h : Hash) :
    Jar.Crypto.seqFromHash 0 h = #[] := by
  rfl

-- ============================================================================
-- shuffle composition
-- ============================================================================

/-- shuffle is fisherYatesShuffle composed with seqFromHash. -/
theorem shuffle_eq_compose [Inhabited α] (s : Array α) (h : Hash) :
    Jar.Crypto.shuffle s h = Jar.Crypto.fisherYatesShuffle s (Jar.Crypto.seqFromHash s.size h) := by
  rfl

end Jar.Proofs
