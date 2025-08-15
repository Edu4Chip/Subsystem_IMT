from dataclasses import dataclass
from typing import List

from . import ascon


@dataclass
class AsconRoundRecord:
    index: int
    round: int
    add_state: int
    sub_state: int
    diff_state: int


class AsconModel:
    def __init__(self):
        self._rounds: List[AsconRoundRecord] = []
        self._backup = None
        self._index = 0

    @staticmethod
    def _state_to_int(state: List[int]) -> int:
        value = state[4]
        value = (value << 64) | state[3]
        value = (value << 64) | state[2]
        value = (value << 64) | state[1]
        value = (value << 64) | state[0]
        return value

    def _add_round(self, round: int, add_state: int, sub_state: int, diff_state: int):
        """Translate value from the ref. imp. to the SV representation."""
        self._rounds.append(
            AsconRoundRecord(
                index=self._index,
                round=round + 4,
                add_state=add_state,
                sub_state=sub_state,
                diff_state=diff_state,
            )
        )
        self._index += 1

    def _ascon_permutation(self, S, rounds=1):
        """
        Ascon core permutation for the sponge construction - internal helper function.
        S: Ascon state, a list of 5 64-bit integers
        rounds: number of rounds to perform
        returns nothing, updates S
        """
        assert rounds <= 12
        if ascon.debugpermutation:
            ascon.printwords(S, "permutation input:")
        for r in range(12 - rounds, 12):
            # --- add round constants ---
            S[2] ^= 0xF0 - r * 0x10 + r * 0x1
            if ascon.debugpermutation:
                ascon.printwords(S, "round constant addition:")
            __add_state = self._state_to_int(S)
            # --- substitution layer ---
            S[0] ^= S[4]
            S[4] ^= S[3]
            S[2] ^= S[1]
            T = [(S[i] ^ 0xFFFFFFFFFFFFFFFF) & S[(i + 1) % 5] for i in range(5)]
            for i in range(5):
                S[i] ^= T[(i + 1) % 5]
            S[1] ^= S[0]
            S[0] ^= S[4]
            S[3] ^= S[2]
            S[2] ^= 0xFFFFFFFFFFFFFFFF
            if ascon.debugpermutation:
                ascon.printwords(S, "substitution layer:")
            __sub_state = self._state_to_int(S)
            # --- linear diffusion layer ---
            S[0] ^= ascon.rotr(S[0], 19) ^ ascon.rotr(S[0], 28)
            S[1] ^= ascon.rotr(S[1], 61) ^ ascon.rotr(S[1], 39)
            S[2] ^= ascon.rotr(S[2], 1) ^ ascon.rotr(S[2], 6)
            S[3] ^= ascon.rotr(S[3], 10) ^ ascon.rotr(S[3], 17)
            S[4] ^= ascon.rotr(S[4], 7) ^ ascon.rotr(S[4], 41)
            if ascon.debugpermutation:
                ascon.printwords(S, "linear diffusion layer:")
            __diff_state = self._state_to_int(S)
            self._add_round(r, __add_state, __sub_state, __diff_state)

    def ascon_encrypt(self, key, nonce, ad, di, variant="Ascon-AEAD128"):
        res = ascon.ascon_encrypt(key, nonce, ad, di, variant=variant)
        do, tag = res[: len(di)], res[len(di) :]
        return do, tag

    def ascon_decrypt(self, key, nonce, ad, di, variant="Ascon-AEAD128"):
        """
        Ascon decryption.
        key: a bytes object of size 16 (for Ascon-AEAD128; 128-bit security)
        nonce: a bytes object of size 16 (must not repeat for the same key!)
        associateddata: a bytes object of arbitrary length
        ciphertext: a bytes object of arbitrary length (also contains tag)
        variant: "Ascon-AEAD128"
        returns a bytes object containing the plaintext or None if verification fails
        """
        versions = {"Ascon-AEAD128": 1}
        assert variant in versions.keys()
        assert len(key) == 16 and len(nonce) == 16
        S = [0, 0, 0, 0, 0]
        k = len(key) * 8  # bits
        a = 12  # rounds
        b = 8  # rounds
        rate = 16  # bytes

        ascon.ascon_initialize(S, k, rate, a, b, versions[variant], key, nonce)
        ascon.ascon_process_associated_data(S, b, rate, ad)
        do = ascon.ascon_process_ciphertext(S, b, rate, di)
        tag = ascon.ascon_finalize(S, rate, a, key)
        return do, tag

    def get_rounds(self) -> List[AsconRoundRecord]:
        return self._rounds.copy()

    def __enter__(self):
        if self._backup is None:
            self._backup = ascon.ascon_permutation
            ascon.ascon_permutation = self._ascon_permutation
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._backup is not None:
            ascon.ascon_permutation = self._backup
            self._backup = None
        return False
