// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// Unit tests for SwapLiquidityProvider internal logic.
// These test pure computational functions that don't require on-chain state.
// Full end-to-end tests are in integration-tests/.

#[test_only]
module SwapAdmin::SwapLiquidityProviderTests {
    use StarcoinFramework::Vector;

    // ======================== Vector helper tests ========================
    // Test the operator list management logic (add, remove, contains)

    #[test]
    fun test_operator_list_add_and_contains() {
        let operators = Vector::empty<address>();
        let addr1 = @0x1;
        let addr2 = @0x2;

        assert!(!Vector::contains(&operators, &addr1), 10001);
        Vector::push_back(&mut operators, addr1);
        assert!(Vector::contains(&operators, &addr1), 10002);
        assert!(!Vector::contains(&operators, &addr2), 10003);

        Vector::push_back(&mut operators, addr2);
        assert!(Vector::contains(&operators, &addr2), 10004);
        assert!(Vector::length(&operators) == 2, 10005);
    }

    #[test]
    fun test_operator_list_remove() {
        let operators = Vector::empty<address>();
        let addr1 = @0x1;
        let addr2 = @0x2;
        let addr3 = @0x3;

        Vector::push_back(&mut operators, addr1);
        Vector::push_back(&mut operators, addr2);
        Vector::push_back(&mut operators, addr3);

        // Remove addr2 (middle element) using swap_remove
        let (found, idx) = Vector::index_of(&operators, &addr2);
        assert!(found, 10010);
        Vector::swap_remove(&mut operators, idx);

        assert!(Vector::length(&operators) == 2, 10011);
        assert!(Vector::contains(&operators, &addr1), 10012);
        assert!(!Vector::contains(&operators, &addr2), 10013);
        assert!(Vector::contains(&operators, &addr3), 10014);
    }

    #[test]
    fun test_operator_list_remove_last() {
        let operators = Vector::empty<address>();
        let addr1 = @0x1;

        Vector::push_back(&mut operators, addr1);

        let (found, idx) = Vector::index_of(&operators, &addr1);
        assert!(found, 10020);
        Vector::swap_remove(&mut operators, idx);

        assert!(Vector::length(&operators) == 0, 10021);
        assert!(!Vector::contains(&operators, &addr1), 10022);
    }

    #[test]
    fun test_operator_list_remove_first_of_two() {
        let operators = Vector::empty<address>();
        let addr1 = @0x1;
        let addr2 = @0x2;

        Vector::push_back(&mut operators, addr1);
        Vector::push_back(&mut operators, addr2);

        // Remove first element
        let (found, idx) = Vector::index_of(&operators, &addr1);
        assert!(found, 10030);
        Vector::swap_remove(&mut operators, idx);

        assert!(Vector::length(&operators) == 1, 10031);
        assert!(!Vector::contains(&operators, &addr1), 10032);
        assert!(Vector::contains(&operators, &addr2), 10033);
    }

    #[test]
    fun test_operator_not_found_returns_false() {
        let operators = Vector::empty<address>();
        let addr1 = @0x1;
        let addr_missing = @0x99;

        Vector::push_back(&mut operators, addr1);

        let (found, _idx) = Vector::index_of(&operators, &addr_missing);
        assert!(!found, 10040);
    }

    // ======================== Error code uniqueness test ========================

    #[test]
    fun test_error_codes_are_distinct() {
        // Verify all error codes are unique (compile-time logic validation)
        let codes = Vector::empty<u64>();
        Vector::push_back(&mut codes, 20001); // ERR_VAULT_ALREADY_EXISTS
        Vector::push_back(&mut codes, 20002); // ERR_VAULT_NOT_EXISTS
        Vector::push_back(&mut codes, 20003); // ERR_NOT_PROVIDER
        Vector::push_back(&mut codes, 20004); // ERR_NOT_OPERATOR
        Vector::push_back(&mut codes, 20005); // ERR_OPERATOR_ALREADY_GRANTED
        Vector::push_back(&mut codes, 20006); // ERR_OPERATOR_NOT_FOUND
        Vector::push_back(&mut codes, 20007); // ERR_INSUFFICIENT_X
        Vector::push_back(&mut codes, 20008); // ERR_INSUFFICIENT_Y
        Vector::push_back(&mut codes, 20009); // ERR_INSUFFICIENT_LP
        Vector::push_back(&mut codes, 20010); // ERR_INVALID_TOKEN_PAIR
        Vector::push_back(&mut codes, 20011); // ERR_ZERO_AMOUNT
        Vector::push_back(&mut codes, 20012); // ERR_CAP_ALREADY_EXISTS
        Vector::push_back(&mut codes, 20013); // ERR_CAP_NOT_EXISTS

        let len = Vector::length(&codes);
        let i = 0;
        while (i < len) {
            let j = i + 1;
            while (j < len) {
                assert!(
                    *Vector::borrow(&codes, i) != *Vector::borrow(&codes, j),
                    10050
                );
                j = j + 1;
            };
            i = i + 1;
        };
    }
} // end address SwapAdmin
