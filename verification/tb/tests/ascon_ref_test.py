import os

from uvc.ascon.sequences import AsconRefEncSeq

from .ascon_base_test import AsconBaseTest


class AsconSingleRefEncTest(AsconBaseTest):
    async def run_phase(self):
        self.raise_objection()

        ad_size = int(os.getenv("AD_SIZE", "0"))
        di_size = int(os.getenv("DI_SIZE", "0"))

        self.start_clock()
        await self.reset_system()
        seq = AsconRefEncSeq.create(f"ref_enc_seq({ad_size}, {di_size})")
        assert isinstance(seq, AsconRefEncSeq)
        seq.randomize()
        seq.ad_size = ad_size
        seq.di_size = di_size
        await seq.start(self.sequencer)

        self.drop_objection()


class AsconFullRefEncTest(AsconBaseTest):
    async def run_phase(self):
        self.raise_objection()

        self.start_clock()
        await self.reset_system()

        seq_cls = AsconRefEncSeq
        for ad_size in range(32):
            for di_size in range(32):
                seq = seq_cls.create(f"ref_enc_seq({ad_size}, {di_size})")
                assert isinstance(seq, seq_cls)
                seq.randomize()
                seq.ad_size = ad_size
                seq.di_size = di_size
                await seq.start(self.sequencer)

        self.drop_objection()
