# Verification

This folder would contain source files for verification tests.

## Functional tests

The Ascon AEAD implementation is tested against known answer test (KAT) vectors.

### Getting started

First ensure that a SystemVerilog simulator is installed on your machine. The testbench has been simulated with verilator and modelsim. A working simulation environment can be setup with the following steps.

1. Clone the repository.

```
git clone git@github.com/edu4chip/subsystem_imt.git subsystem_imt
```

2. Create a Python virtualenv to manage the project dependencies.

```
python3 -m venv venv
```

3.  Activate the virtualenv and install the packages **cocotb** and **ascon_kat** in it:

```
source venv/bin/activate
python -m pip install cocotb subsystem_imt/verification/ascon_kat
```

4. Simulate the testbench in batch mode with `make`.

```
cd subsystem_imt/verification/apb_ascon
SIM=modelsim make
```

5. Alternatively, compile the testbench and load it in modelsim GUI.

```
SIM=modelsim GUI=1 make
```

### Build options and environment variables

#### Description

The test is parametrized with the following build options and environment variables:

```
SIM             the name of the simulator, tested with 'verilator' and 'modelsim'
TESTCASE        the test case to execute, either 'test_single' (default) or 'test_sequence'

AD_SIZE         the size of the associated data in bytes
PT_SIZE         the size of the plaintext in bytes
PROG_DELAY      the value of the programmable delay before the start of an encryption

# Options which are specific to the 'test_single' test case
SAMPLE_COUNT    the test vector to execute, identified by its 'count' attribute

# Options which are specific to the 'test_sequence' test case
SAMPLE_SIZE     the number of test vectors to process

# Options which are specific to simulator modelsim
GUI             set to 1 to start modelsim GUI, 0 otherwise
```

These parameters can be passed to the simulation environment as follows:

```
[parameter=value[ parameter=value[...]]] make
```

#### Use cases

Simulate the encryption of a single random vector:

```
make
```

Simulate the encryption of a single random vector without associated data:

```
AD_SIZE=0 make
```

Replay the encryption of the vector which count identifier is 105:

```
SAMPLE_COUNT=105 make
```

Simulate the encryption of 10 random vectors:

```
TESTCASE=test_sequence SAMPLE_SIZE=10 make
```

Simulate the encryption of 10 random vectors without associated data:

```
TESTCASE=test_sequence SAMPLE_SIZE=10 AD_SIZE=0 make
```

Simulate the encryption of all the test vectors:

```
TESTCASE=test_sequence make
```

