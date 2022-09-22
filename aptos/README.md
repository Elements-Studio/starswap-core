# Starswap-core

Starswap is a general purpose DEX on Move-based multi chain, include Starcoin/Aptos/Sui 


## Aptos Move CLI

### Compile Contract
```commandline
aptos move compile
```

### Run Transactional Tests
```commandline
aptos move transactional-test 
```

### Run Unit Tests

```commandline
aptos move test
```


## Contributing

First off, thanks for taking the time to contribute! Contributions are what makes the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.

Contributions in the following are welcome:

1. Report a bug.
2. Submit a feature request.
3. Implement feature or fix bug.

### How to add new module to starswap-core:

1. Add New Move module to `sources` dir, such as `MyModule.move`.
2. Write Move code and add unit test in the module file.
3. Add an transactional test to [transactional-tests](../transactional-tests) dir, such as: `test_my_module.move`.
4. Run the transactional test `mpm transactional-test test_my_module.move `.
5. Run script `./script/build.sh` for build and generate documents.

