import os

from uvc.ascon.sequences import AsconRandEncSeq

from .ascon_base_test import AsconBaseTest


class AsconRandomSampleEncTest(AsconBaseTest):
    async def run_phase(self):
        self.raise_objection()

        sample_size = int(os.getenv("SAMPLE_SIZE", "1"))

        self.start_clock()
        await self.reset_system()

        for i in range(sample_size):
            seq = AsconRandEncSeq.create(f"rand_enc_seq({i})")
            assert isinstance(seq, AsconRandEncSeq)
            seq.randomize()
            await seq.start(self.sequencer)

        self.drop_objection()
