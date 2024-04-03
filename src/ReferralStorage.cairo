use starknet::{ContractAddress};

#[starknet::interface]
trait IReferralStorage<TContractState> {
    fn setTraderReferralCode(
        ref self: TContractState,
        _code: felt252,
    );

    fn registerCode(
        ref self: TContractState,
        _code: felt252,
    );
}


#[starknet::contract]
mod ReferralStorage {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use core::zeroable::Zeroable;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetTraderReferralCode: SetTraderReferralCode,
        RegisterCode: RegisterCode,
    }


    #[derive(Drop, starknet::Event)]
    struct SetTraderReferralCode {
        account: ContractAddress,
        code: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterCode {
        code: felt252,
        account: ContractAddress,
    }

    #[storage]
    struct Storage {
        code_owners: LegacyMap::<felt252, ContractAddress>,
        trader_referral_codes: LegacyMap::<ContractAddress, felt252>,
    }

    #[abi(embed_v0)]
    impl ReferralStorage of super::IReferralStorage<ContractState> {
        fn setTraderReferralCode(
            ref self: ContractState,
            _code: felt252,
        ){
            let _account = get_caller_address();
            self.trader_referral_codes.write(_account, _code);
            self.emit(SetTraderReferralCode{account:_account, code: _code});  
        }

        fn registerCode(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(!self.code_owners.read(_code).is_non_zero(), "ReferralStorage: code already registered");
            assert!(_code != 0, "ReferralStorage: invalid code");

            self.code_owners.write(_code, get_caller_address());

            self.emit(RegisterCode{code:_code, account: get_caller_address()});
        }
    }



}

