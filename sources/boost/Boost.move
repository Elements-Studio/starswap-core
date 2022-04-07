address SwapAdmin {

module Boost {

    /// The release amount follow the formular
    /// @param locked_time per seconds
    ///
    /// `veSTAR reward = UserLockedSTARAmount * UserLockedSTARDay / 365`
    public fun compute_issue_amount(locked_time_sec: u64, locked_amount: u128): u128 {
        let locked_day = locked_time_sec / 60 * 60 * 24;
        locked_amount * (locked_day as u128) / 365u128
    }
}
}
