/// A packaged Token type.
/// This type registers a Token type and encapsulates it within the structure of the VToken type.
/// It cannot be transferred in or out.
module swap_admin::VToken {

    use std::error;
    use std::signer;

    use starcoin_framework::coin;
    use starcoin_std::type_info;

    const EFAIL_ADMIN_SIGNER_CHECK: u64 = 1;

    struct VToken<phantom TokenT> has key, store {
        token: coin::Coin<TokenT>
    }

    struct OwnerCapability<phantom TokenT> has key, store {
        mint_cap: coin::MintCapability<TokenT>,
        burn_cap: coin::BurnCapability<TokenT>,
        freeze_cap: coin::FreezeCapability<TokenT>,
    }

    public fun register_token<TokenT: store>(signer: &signer, precision: u8) {
        let name = type_info::type_name<VToken<TokenT>>();
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TokenT>(
            signer,
            name,
            name,
            precision,
            true,
        );
        coin::register<TokenT>(signer);
        move_to(signer, OwnerCapability<TokenT> {
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
        VToken<TokenT> {
            token: coin::mint((amount as u64), &cap.mint_cap)
        }
    }

    public fun mint_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, amount: u128): VToken<TokenT> {
        let bared_token = coin::mint((amount as u64), &cap.mint_cap);
        VToken<TokenT> {
            token: bared_token
        }
    }

    public fun burn<TokenT: store>(signer: &signer, vt: VToken<TokenT>) acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<TokenT>>(signer::address_of(signer));
        burn_with_cap(cap, vt)
    }

    public fun burn_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, vt: VToken<TokenT>) {
        let VToken<TokenT> {
            token
        } = vt;
        coin::burn<TokenT>(token, &cap.burn_cap);
    }

    public fun value<TokenT: store>(vt: &VToken<TokenT>): u128 {
        (coin::value<TokenT>(&vt.token) as u128)
    }

    public fun deposit<TokenT: store>(lhs: &mut VToken<TokenT>, rhs: VToken<TokenT>) {
        let VToken<TokenT> {
            token
        } = rhs;
        coin::merge(&mut lhs.token, token);
    }

    /// Withdraw from a token
    public fun withdraw<TokenT: store>(src_token: &mut VToken<TokenT>, amount: u128): VToken<TokenT> {
        VToken<TokenT> {
            token: coin::extract(&mut src_token.token, (amount as u64))
        }
    }

    public entry fun freeze_token<TokenT: store>(
        admin_account: &signer,
        account_addr: address,
        freeze: bool
    ) acquires OwnerCapability {
        let admin_account_addr = signer::address_of(admin_account);
        assert!(admin_account_addr == @swap_admin, error::unauthenticated(EFAIL_ADMIN_SIGNER_CHECK));
        let owner_cap = borrow_global<OwnerCapability<TokenT>>(admin_account_addr);

        if (freeze) {
            coin::freeze_coin_store<TokenT>(account_addr, &owner_cap.freeze_cap);
        }
        else {
            coin::unfreeze_coin_store<TokenT>(account_addr, &owner_cap.freeze_cap);
        }
    }
}

