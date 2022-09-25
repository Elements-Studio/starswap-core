module SwapAdmin::VToken {
    use aptos_framework::coin;

    use std::string;
    use std::signer;

    use SwapAdmin::CommonHelper;

    struct VToken<phantom TokenT> has key, store {
        token: coin::Coin<TokenT>
    }

    struct OwnerCapability<phantom TokenT> has key, store {
        mint_cap: coin::MintCapability<TokenT>,
        burn_cap: coin::BurnCapability<TokenT>,
        freeze_cap: coin::FreezeCapability<TokenT>,
    }

    public fun register_token<TokenT: store>(account: &signer, precision: u8) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TokenT>(
            account,
            string::utf8(b"VToken"),
            string::utf8(b"VToken"),
            precision,
            false,
        );
        CommonHelper::safe_accept_token<TokenT>(account);

        move_to(account, OwnerCapability<TokenT>{
            mint_cap,
            burn_cap,
            freeze_cap,
        });
    }

    public fun extract_cap<TokenT: store>(signer: &signer): OwnerCapability<TokenT> acquires OwnerCapability {
        move_from<OwnerCapability<TokenT>>(signer::address_of(signer))
    }

    /// Create a new VToken::VToken<TokenT> with a value of 0
    public fun zero<TokenT: store>(): VToken<TokenT> {
        VToken<TokenT> {
            token: coin::zero<TokenT>()
        }
    }

    public fun mint<TokenT: store>(signer: &signer, amount: u128): VToken<TokenT> acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<TokenT>>(signer::address_of(signer));
        VToken<TokenT>{
            token: coin::mint((amount as u64), &cap.mint_cap)
        }
    }

    public fun mint_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, amount: u128): VToken<TokenT> {
        let bared_token = coin::mint((amount as u64), &cap.mint_cap);
        VToken<TokenT>{
            token: bared_token
        }
    }

    public fun burn<TokenT: store>(signer: &signer, vt: VToken<TokenT>) acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<TokenT>>(signer::address_of(signer));
        burn_with_cap(cap, vt)
    }

    public fun burn_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, vt: VToken<TokenT>) {
        let VToken<TokenT>{
            token
        } = vt;
        coin::burn(token, &cap.burn_cap);
    }

    public fun value<TokenT: store>(vt: &VToken<TokenT>): u128 {
        (coin::value<TokenT>(&vt.token) as u128)
    }

    public fun deposit<TokenT: store>(lhs: &mut VToken<TokenT>, rhs: VToken<TokenT>) {
        let VToken<TokenT>{
            token
        } = rhs;
        coin::merge(&mut lhs.token, token);
    }

    /// Withdraw from a token
    public fun withdraw<TokenT: store>(src_token: &mut VToken<TokenT>, amount: u128): VToken<TokenT> {
        VToken<TokenT>{
            token: coin::extract(&mut src_token.token, (amount as u64))
        }
    }
}

