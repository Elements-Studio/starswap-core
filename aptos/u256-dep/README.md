# U256 

Pure Move language implementation of U256 numbers.

Would be nice to help with the `TODO` list, you can see it in the [header comment](sources/U256.move).

Supported features:
* mul
* div
* add
* sub
* shift left
* shift right
* bitwise and, xor, or
* compare
* if math overflows the contract crashes with abort code.

The audit still missed, so use at your own risk.

### Build

    aptos move build

### Test

    aptos move test


## Add as dependency

Add to `Move.toml`:

```toml
[dependencies.U256]
git = "https://github.com/pontem-network/U256.git"
rev = "v0.3.7"
```

And then use in code:

```move
use u256::u256;
...
let a = u256::from_u128(10);
let b = u256::from_u64(10);

let c = u256::add(a, b);
let z = u256::as_u128(c);
```

## License

Apache 2.0
