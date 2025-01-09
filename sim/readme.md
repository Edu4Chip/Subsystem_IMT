# Simulation

This folder would keep in it scripts and makefiles for managing sim build and sim running.

## Functional test of the Ascon submodule

Functional verifications of the Ascon AEAD hardware implementation using cocotb.
The Python script load Known Answer Test (KAT) vectors from a text file and check the result of the encryption against expected values.

### Getting started

First ensure that a SystemVerilog simulator is installed on your machine. The testbench has been simulated with verilator and modelsim. A working cocotb simulation environment can be setup with the following steps.

1. Clone the project repository.

```
git clone git@github.com/edu4chip/subsystem_imt.git subsystem_imt
```

2. Create a Python virtualenv to manage the project dependencies.

```
python3 -m venv venv
```

3.  Activate the virtualenv and install the package **cocotb**:

```
source venv/bin/activate
python -m pip install cocotb
```

4. Simulate the testbench in batch mode with `make`.

```
cd subsystem_imt/sim/apb_ascon
SIM=modelsim make
```

5. Alternatively, compile the testbench and load it in modelsim GUI.

```
make clean
SIM=modelsim GUI=1 make
```

### Build options and environment variables

#### Description

The test is parametrized with the following build options and environment variables:

- `SIM`: the name of the simulator, tested with `verilator` (default) and `modelsim`
- `TESTCASE`: the test case to execute, either `test_sample` (default) or `test_vector`
- `GUI`: set to 1 to start modelsim GUI, 0 otherwise
- `KAT_PATH`: optional path to a KAT file (default: `LWC_AEAD_KAT_128_128.txt`)
- `ID`: Count ID of a test vector to run when using `TESTCASE=test_vector`
- `SAMPLE_SIZE`: Size of the sample of vectors to test when using `TESTCASE=test_sample`

These parameters can be passed to the simulation environment as follows:

```
[parameter=value[ parameter=value[...]]] make
```

#### Use cases

Simulate the encryption of all KAT vectors:

```
make
```

Simulate the encryption of a single random vector:

```
SAMPLE_SIZE=1 make
```

Simulate the encryption of 10 random vectors:

```
SAMPLE_SIZE=10 make
```

Replay the encryption of the vector which count identifier is 105:

```
TESTCASE=test_vector ID=105 make
```

## Note on byte ordering

### TL;DR

Care must be taken in the simulation to choose a little-endian byte ordering convention when sending data to the Ascon peripheral. With cocotb, this can be done as follows:

```python
# simulate the following memory mapping:
# addr=0x00: value=0x00 -- memory[0]
# addr=0x04: value=0x01 -- memory[1]
# addr=0x08: value=0x02 -- memory[2]
# addr=0x0C: value=0x03 -- memory[3]

memory = bytes([0, 1, 2, 3])
dut.reg.value = int.from_bytes(memory, byteorder='little')
```

### Design rational

One possible use of Ascon AEAD is the authenticated encryption of network packets. The byte ordering of these packets follows the big-endian convention (MSB first). Similarly, the Ascon128 reference implementation operates on 64-bit blocks which byte ordering follows the big-endian convention. The algorithm can thus operate on fixed-sized chunks of a network packet without swapping endianness.

However, the 32-bit RISC-V CPU employs the little-endian convention (LSB first) to represent data stored in the system memories. Assuming the CPU only task is to copy the input data from a memory to the Ascon peripheral registers, the endianness of the data must be swapped *in hardware* to accomodate for the Ascon internal representation.