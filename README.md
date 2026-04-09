# Starswap-core

Starswap is a general purpose DEX on Starcoin. 


## Move Package Manager

### Compile Contract
```commandline
mpm package build
```

### Run Integration Tests
```commandline
mpm integration-test 
```

### Run Unit Tests

> **Note**: The project uses StarcoinFramework v11 (`198d236f`) for compatibility with starcoin/mpm v1.13.20. However, v11's UnitTest module uses `Std::UnitTest` (uppercase), while mpm v1.13.20 expects v12's `std::unit_test` (lowercase). You need to patch the mpm cache before running tests:
>
> ```bash
> # First build to populate the cache, then patch
> mpm package build
> ./scripts/patch_v11_unittest.sh
> ```
>
> This only needs to be done once per machine (or after clearing `~/.move` cache).

```commandline
mpm package test
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
3. Add an integration test to [integration-tests](../integration-tests) dir, such as: `test_my_module.move`.
4. Run the integration test `mpm integration-test test_my_module.move `.
5. Run script `./script/build.sh` for build and generate documents.

