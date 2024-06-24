# IMT subsystem

This read me would contain brief intro and links to detailed documentation in doc/ folder.

This subsystem describes a crypto-accelerator for the Ascon AEAD family of lightweight authenticated ciphers.

The subsystem is connected to the staff area via the APB bus.
The accelerator uses a key, an associated data and a plaintext to generate a ciphertext and an authentication tag.
Additionally, An interrupt request can be generated upon the completion of a computation.

This subsystem is designed to facilitate practical experiments during hardware security lectures.
To this end, the computation can be triggered either by writing in the control register of the subsystem, or by asserting an external start signal.
A programmable delay between a trigger event and the start of the computation can also be configured in a control register of the subsystem.
Last but not least, a synchronisation signal is generated during the critical parts of the cipher execution.


## Pin function table

| Name      | Direction | Function                   |
| --------- | --------- | -------------------------- |
| `clk_i`     | input     | clock                      |
| `resetb_i`  | input     | reset signal (active low)  |
| `P<signal>` | input     | APB interface              |
| `irq_en_i`  | input     | enable IRQ                 |
| `ss_ctrl_i` | input     | enable clock (active high) |
| `start_i`   | input     | start computation          |
| `irq_o`     | output    | IRQ (active high)          |
| `sync_o`    | output    | synchronisation signal     |

