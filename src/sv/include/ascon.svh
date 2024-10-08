`ifndef ASCON_SVH_
`define ASCON_SVH_

`define RROT64(__d, __n) {__d[__n-1:0], __d[63:__n]}

`define DIFF64(__q, __d, __n1, __n2)                        \
  always_comb begin                                         \
    __q = __d ^ `RROT64(__d, __n1) ^ `RROT64(__d, __n2);    \
  end

`define STATECOL(__d, __i) \
    {__d[0][__i], __d[1][__i], __d[2][__i], __d[3][__i], __d[4][__i]}

`define SBOX5(__q, __d, __sbox, __i)                        \
  always_comb begin                                         \
    `STATECOL(__q, __i) = __sbox[`STATECOL(__d, __i)];      \
  end

`endif