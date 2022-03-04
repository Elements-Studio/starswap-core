# Starswap-core

Starswap is a general purpose DEX on Starcoin. 


## Move Package Manager

### Compile Contract
```commandline
mpm package build
```

### Run Functional Tests
```commandline
mpm spectest 
```

---
## Move CLI (Old version)
### Compile Contracts

```commandline
move clean
move check 
move publish  --ignore-breaking-changes
```

### Run Functional Tests

```commandline
move functional-test
```

### Run Unit Tests

```commandline
move unit-test -g
```

