module SwapAdmin::VToken {
    use aptos_framework::coin;

    use std::string;
    use std::signer;

    use SwapAdmin::CommonHelper;

    struct VToken<phantom CoinT> has key, store {
        token: coin::Coin<CoinT>
    }

    struct OwnerCapability<phantom CoinT> has key, store {
        mint_cap: coin::MintCapability<CoinT>,
        burn_cap: coin::BurnCapability<CoinT>,
        freeze_cap: coin::FreezeCapability<CoinT>,
    }

    public fun register_token<CoinT: store>(account: &signer, precision: u8) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinT>(
            account,
            string::utf8(b"VToken"),
            string::utf8(b"VToken"),
            precision,
            false,
        );
        CommonHelper::safe_accept_token<CoinT>(account);

        move_to(account, OwnerCapability<CoinT>{
            mint_cap,
            burn_cap,
            freeze_cap,
        });
    }

    public fun extract_cap<CoinT: store>(signer: &signer): OwnerCapability<CoinT> acquires OwnerCapability {
        move_from<OwnerCapability<CoinT>>(signer::address_of(signer))
    }

    /// Create a new VToken::VToken<CoinT> with a value of 0
    public fun zero<CoinT: store>(): VToken<CoinT> {
        VToken<CoinT> {
            token: coin::zero<CoinT>()
        }
    }

    public fun mint<CoinT: store>(signer: &signer, amount: u128): VToken<CoinT> acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<CoinT>>(signer::address_of(signer));
        VToken<CoinT>{
            token: coin::mint((amount as u64), &cap.mint_cap)
        }
    }

    public fun mint_with_cap<CoinT: store>(cap: &OwnerCapability<CoinT>, amount: u128): VToken<CoinT> {
        let bared_token = coin::mint((amount as u64), &cap.mint_cap);
        VToken<CoinT>{
            token: bared_token
        }
    }

    public fun burn<CoinT: store>(signer: &signer, vt: VToken<CoinT>) acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<CoinT>>(signer::address_of(signer));
        burn_with_cap(cap, vt)
    }

    public fun burn_with_cap<CoinT: store>(cap: &OwnerCapability<CoinT>, vt: VToken<CoinT>) {
        let VToken<CoinT>{
            token
        } = vt;
        coin::burn(token, &cap.burn_cap);
    }

    public fun value<CoinT: store>(vt: &VToken<CoinT>): u128 {
        (coin::value<CoinT>(&vt.token) as u128)
    }

    public fun deposit<CoinT: store>(lhs: &mut VToken<CoinT>, rhs: VToken<CoinT>) {
        let VToken<CoinT>{
            token
        } = rhs;
        coin::merge(&mut lhs.token, token);
    }

    /// Withdraw from a token
    public fun withdraw<CoinT: store>(src_token: &mut VToken<CoinT>, amount: u128): VToken<CoinT> {
        VToken<CoinT>{
            token: coin::extract(&mut src_token.token, (amount as u64))
        }
    }
}

