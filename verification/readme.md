# Verification

This folder would contain source files for verification tests.

## Functional tests

The Ascon AEAD implementation is tested against known answer test (KAT) vectors.

### Running the tests

First ensure that a SystemVerilog simulator is installed on your machine. The verification scripts have been tested with verilator and modelsim.

1. Clone the repository

```
git clone git@github.com/edu4chip/subsystem_imt.git subsystem_imt
```

2. Create a Python venv and activate it

```
python3 -m venv venv
source venv/bin/activate
```

3. Install the packages **cocotb** and **ascon_kat**:

```
python -m pip install cocotb subsystem_imt/verification/ascon_kat
```

4. Run the verification scripts with `make`

```
cd subsystem_imt/verification/apb_ascon
SIM=modelsim make
```

### Build options and environment variables

The test is parametrized with the following build options and environment variables:

```
SIM             the name of the simulator, tested with 'verilator' and 'modelsim'
TESTCASE        the test case to execute, either 'test_single' or 'test_sequence'

AD_SIZE         the size of the associated data in bytes
PT_SIZE         the size of the plaintext in bytes
PROG_DELAY      the value of the programmable delay before the start of an encryption

# Options which are specific to the 'test_single' test case
SAMPLE_COUNT    the specific test vector to execute, identified by its 'count' attribute

# Options which are specific to the 'test_sequence' test case
SAMPLE_SIZE     the number of test vectors to process
```

These parameters can be passed to the verification scripts as follows:

```
SIM=modelsim TESTCASE=test_sequence SAMPLE_SIZE=10 make
```
