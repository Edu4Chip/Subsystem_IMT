# IMT subsystem

This read me would contain brief intro and links to detailed documentation in doc/ folder.

## Ascon subsystem

This subsystem describes a crypto-accelerator for the Ascon AEAD family of lightweight authenticated ciphers.
It is driven by the RISC-V CPU embedded in the Didactic-SoC through a dedicated APB interface.
The accelerator can encrypt up to 128 bytes of associated data and 128 bytes of plaintext.
It generates up to 128 bytes of ciphertext as a result and a 128-bit tag.
For experimental purposes, a single pulse is generated on an output pin of the subsystem PMOD connector during the first round of every permutation.

See the module documentation for a detailed description of the APB registers.
