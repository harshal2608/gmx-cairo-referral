use starknet::{ContractAddress, ClassHash};


#[starknet::interface]
trait IReferralStorage<TContractState> {
    fn is_gov(ref self: TContractState) -> bool;

    fn only_gov(ref self: TContractState);

    fn only_handler(ref self: TContractState);

    fn setHandler(
        ref self: TContractState,
        _handler: ContractAddress,
        _isActive: bool,
    );

    fn setTier(
        ref self: TContractState,
        _tierId: u8,
        _totalRebate: u256,
        _discountShare: u256,
    );

    fn setReferrerTier(
        ref self: TContractState,
        _referrer: ContractAddress,
        _tierId: u8,
    );

    fn setReferrerDiscountShare(
        ref self: TContractState,
        _referrer: ContractAddress,
        _discountShare: u256,
    );

    fn setTraderReferralCode(
        ref self: TContractState,
        _account: ContractAddress,
        _code: felt252,
    );

    fn setTraderReferralCodeByUser(
        ref self: TContractState,
        _code: felt252,
    );

    fn registerCode(
        ref self: TContractState,
        _code: felt252,
    );

    fn setCodeOwner(
        ref self: TContractState,
        _code: felt252,
        _newAccount: ContractAddress,
    );

    fn govSetCodeOwner(
        ref self: TContractState,
        _code: felt252,
        _newAccount: ContractAddress,
    );

    fn getTraderReferralInfo(
        ref self: TContractState,
        _account: ContractAddress,
    ) -> (felt252, ContractAddress);
}


#[starknet::contract]
mod ReferralStorage {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    const BASIS_POINTS:u256 = 10000;

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Tier {
        totalRebate: u256,
        discountShare: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetHandler: SetHandler,
        SetTraderReferralCode: SetTraderReferralCode,
        SetTier: SetTier,
        SetReferrerTier: SetReferrerTier,
        SetReferrerDiscountShare: SetReferrerDiscountShare,
        RegisterCode: RegisterCode,
        SetCodeOwner: SetCodeOwner,
        GovSetCodeOwner: GovSetCodeOwner,
    }

    #[derive(Drop, starknet::Event)]
    struct SetHandler {
        handler: ContractAddress,
        isActive: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct SetTraderReferralCode {
        account: ContractAddress,
        code: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct SetTier {
        tier: u8,
        totalRebate: u256,
        discountShare: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SetReferrerTier {
        referrer: ContractAddress,
        tierId: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct SetReferrerDiscountShare {
        referrer: ContractAddress,
        discountShare: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RegisterCode {
        code: felt252,
        account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SetCodeOwner {
        code: felt252,
        account: ContractAddress,
        newAccount: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct GovSetCodeOwner {
        code: felt252,
        newAccount: ContractAddress,
    }

    #[storage]
    struct Storage {
        referrer_discount_shares: LegacyMap::<ContractAddress, u256>,
        referrer_tiers: LegacyMap::<ContractAddress, u8>,
        tiers: LegacyMap::<u8, Tier>,
        is_handler: LegacyMap::<ContractAddress, bool>,
        code_owners: LegacyMap::<felt252, ContractAddress>,
        trader_referral_codes: LegacyMap::<ContractAddress, felt252>,
        gov: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState){
        self.gov.write(get_caller_address());
    }

    #[abi(embed_v0)]
    impl ReferralStorage of super::IReferralStorage<ContractState> {
        #[inline(always)]
        fn is_gov(ref self: ContractState) -> bool {
            self.gov.read() == get_caller_address()
        }
        #[inline(always)]
        fn only_gov(ref self: ContractState) {
            assert!(ReferralStorage::is_gov(ref self), "ReferralStorage: forbidden");
        }

        #[inline(always)]
        fn only_handler(ref self: ContractState) {
            let is_handler = self.is_handler.read(get_caller_address());
            assert!(is_handler, "ReferralStorage: forbidden");
        }

        fn setHandler(
            ref self: ContractState,
            _handler: ContractAddress,
            _isActive: bool,
        ){
             ReferralStorage::only_gov(ref self);
            self.is_handler.write(_handler, _isActive);
            self.emit(SetHandler{handler:_handler,isActive: _isActive});
        }

        fn setTier(
            ref self: ContractState,
            _tierId: u8,
            _totalRebate: u256,
            _discountShare: u256,
        ){
             ReferralStorage::only_gov(ref self);

            assert!(_totalRebate <= BASIS_POINTS, "ReferralStorage: invalid totalRebate");
            assert!(_discountShare <= BASIS_POINTS, "ReferralStorage: invalid discountShare");

            self.tiers.write(_tierId, Tier{totalRebate:_totalRebate, discountShare:_discountShare});
            self.emit(SetTier{tier:_tierId, totalRebate: _totalRebate, discountShare: _discountShare});
        }

        fn setReferrerTier(
            ref self: ContractState,
            _referrer: ContractAddress,
            _tierId: u8,
        ){
            ReferralStorage::only_gov(ref self);

            self.referrer_tiers.write(_referrer, _tierId);
            self.emit(SetReferrerTier{referrer:_referrer, tierId: _tierId});
        }

        fn setReferrerDiscountShare(
            ref self: ContractState,
            _referrer: ContractAddress,
            _discountShare: u256,
        ){
            assert!(_discountShare <= BASIS_POINTS, "ReferralStorage: invalid discountShare");

            self.referrer_discount_shares.write(_referrer, _discountShare);
            self.emit(SetReferrerDiscountShare{referrer:_referrer, discountShare: _discountShare});
        }

        fn setTraderReferralCode(
            ref self: ContractState,
            _account: ContractAddress,
            _code: felt252,
        ){
             ReferralStorage::only_handler(ref self);

            _set_trader_referral_code(ref self,_account, _code);
        }

        fn setTraderReferralCodeByUser(
            ref self: ContractState,
            _code: felt252,
        ){
            _set_trader_referral_code(ref self,get_caller_address(), _code);
        }

        fn registerCode(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(self.code_owners.read(_code).is_non_zero(), "ReferralStorage: code already registered");
            assert!(_code != 0, "ReferralStorage: invalid code");

            self.code_owners.write(_code, get_caller_address());

            self.emit(RegisterCode{code:_code, account: get_caller_address()});
        }

        fn setCodeOwner(
            ref self: ContractState,
            _code: felt252,
            _newAccount: ContractAddress,
        ){
            assert!(_code != 0, "ReferralStorage: invalid code");
            assert!(!self.code_owners.read(_code).is_non_zero(), "ReferralStorage: code not registered");

            let currentOwner = self.code_owners.read(_code);
            assert!(currentOwner == get_caller_address(), "ReferralStorage: forbidden");
            self.code_owners.write(_code, _newAccount);

            self.emit(SetCodeOwner{code:_code, account: currentOwner, newAccount: _newAccount});

        }

        fn govSetCodeOwner(
            ref self: ContractState,
            _code: felt252,
            _newAccount: ContractAddress,
        ){
             ReferralStorage::only_gov(ref self);
            assert!(_code != 0, "ReferralStorage: invalid code");

            self.code_owners.write(_code, _newAccount);

            self.emit(GovSetCodeOwner{code:_code, newAccount: _newAccount});
        }

        fn getTraderReferralInfo(
            ref self: ContractState,
            _account: ContractAddress,
        ) -> (felt252, ContractAddress){
            let code = self.trader_referral_codes.read(_account);
            let owner = self.code_owners.read(code);

            return (code, owner);
        }
    }

    fn _set_trader_referral_code(
        ref self: ContractState,
        _account: ContractAddress,
        _code: felt252,
    ){
        self.trader_referral_codes.write(_account, _code);
        self.emit(SetTraderReferralCode{account:_account, code: _code});
    }

}

