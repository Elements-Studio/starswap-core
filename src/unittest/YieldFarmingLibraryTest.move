address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
module YieldFarmingLibraryTest {

    #[test] use 0x1::Debug;
    #[test] use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::YieldFarmingLibrary;

    #[test] fun test_withdraw_amount() {
        let harvest_index = 1000000;
        let asset_total_weight = 100000000;
        let last_update_timestamp = 1;
        let now_seconds = 11;
        let release_per_second = 2;

        let new_index = YieldFarmingLibrary::calculate_harvest_index(harvest_index,asset_total_weight, last_update_timestamp, now_seconds, release_per_second);
        Debug::print(&new_index);
        assert(new_index == 200001000000, 10001);

        let amount = YieldFarmingLibrary::calculate_withdraw_amount(new_index, harvest_index, asset_total_weight);
        Debug::print(&amount);
        assert(amount == 20, 10002);
    }

    #[test] fun test_calc_harvest_index() {
        let harvest_index = 1499999999999999999;
        let asset_total_weight = 7000000000;
        let last_update_timestamp = 86443;
        let now_seconds = 86444;
        let release_per_second = 1000000000;

        let new_index = YieldFarmingLibrary::calculate_harvest_index(harvest_index,asset_total_weight, last_update_timestamp, now_seconds, release_per_second);
        Debug::print(&new_index);

        let amount = YieldFarmingLibrary::calculate_withdraw_amount(new_index, harvest_index, release_per_second * 2);
        Debug::print(&amount);
    }
}
}
