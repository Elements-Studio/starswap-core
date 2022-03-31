address SwapAdmin {

module VToken {
    use StarcoinFramework::Token;

    struct VToken<phantom TokenT> has key {
        token: Token::Token<TokenT>
    }

    public fun from_token<TokenT: store>(t: Token::Token<TokenT>) : VToken<TokenT> {
        VToken<TokenT> {
            token: t
        }
    }

    public fun balance<TokenT: store>(vt: &VToken<TokenT>) : u128 {
        Token::value<TokenT>(&vt.token)
    }
}

}

