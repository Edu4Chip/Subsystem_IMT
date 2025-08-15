import os

from uvc.ascon.sequences import AsconSingleEncSeq

from .ascon_base_test import AsconBaseTest


class AsconSingleEncTest(AsconBaseTest):
    async def run_phase(self):
        self.raise_objection()

        hex_key = os.getenv("KEY", "000102030405060708090A0B0C0D0E0F")
        hex_nonce = os.getenv("NONCE", "101112131415161718191A1B1C1D1E1F")
        hex_ad = os.getenv("AD", "")
        hex_di = os.getenv("DI", "")

        self.start_clock()
        await self.reset_system()
        seq = AsconSingleEncSeq.create("single_enc_seq")
        assert isinstance(seq, AsconSingleEncSeq)
        seq.randomize()
        seq.key = bytes.fromhex(hex_key)
        seq.nonce = bytes.fromhex(hex_nonce)
        seq.ad = bytes.fromhex(hex_ad)
        seq.di = bytes.fromhex(hex_di)
        await seq.start(self.sequencer)

        self.drop_objection()
