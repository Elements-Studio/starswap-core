address SwapAdmin {

module VToken {
    use StarcoinFramework::Token;

    struct VToken<phantom TokenT> has key, store {
        token: Token::Token<TokenT>
    }

    struct OwnerCapability<phantom TokenT> has key, store {
        mint_cap: Token::MintCapability<TokenT>,
        burn_cap: Token::BurnCapability<TokenT>,
    }

    public fun register_token<TokenT: store>(signer: &signer, precision: u8) {
        Token::register_token<TokenT>(signer, precision);
        Account::do_accept_token<TokenT>(account);
        move_to(signer, OwnerCapability<TokenT>{
            mint_cap: Token::remove_mint_capability<TokenT>(signer),
            burn_cap: Token::remove_burn_capability<TokenT>(signer),
        });
    }

    public fun extract_cap<TokenT: store>(signer: &signer): OwnerCapability<TokenT> acquires OwnerCapability {
        move_from<OwnerCapability<TokenT>>(Signer::address_of(signer))
    }

    public fun mint<TokenT: store>(signer: &signer, amount: u128): VToken<TokenT> acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<TokenT>>(Signer::address_of(signer));
        VToken<TokenT>{
            token: Token::mint_with_capability(&cap.mint_cap, amount)
        }
    }

    public fun mint_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, amount: u128): VToken<TokenT> {
        let bear_token = Token::mint_with_capability<TokenT>(&cap.mint_cap, amount);
        VToken<TokenT>{
            token: bear_token
        }
    }

    public fun burn<TokenT>(vt: VToken<TokenT>) acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<TokenT>>(Signer::address_of(signer));
        burn_with_cap(cap, vt)
    }

    public fun burn_with_cap<TokenT: store>(cap: &OwnerCapability<TokenT>, vt: VToken<TokenT>) {
        let VToken<TokenT>{
            token
        };
        burn_with_cap<TokenT>(cap, vt);
    }

    public fun value<TokenT: store>(vt: &VToken<TokenT>): u128 {
        Token::value<TokenT>(&vt.token)
    }

    public fun deposit<TokenT: store>(lhs: &mut VToken<TokenT>, rhs: VToken<TokenT>) {
        let VToken<TokenT>{
            token
        } = rhs;
        Token::deposit(&mut lhs.token, token);
    }
}
}

