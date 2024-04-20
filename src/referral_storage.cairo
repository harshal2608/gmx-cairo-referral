use starknet::{ContractAddress,ClassHash};
use zeroable::Zeroable;


#[starknet::interface]
trait IReferralStorage<TContractState> {
    fn get_trader_referral_code(
         self: @TContractState,
        _account: ContractAddress,
    ) -> felt252;

    fn get_code_owner(
         self: @TContractState,
        _code: felt252,
    ) -> ContractAddress;

    fn get_user_code(
         self: @TContractState,
        _account: ContractAddress,
    ) -> felt252;

    fn set_trader_referral_code(
        ref self: TContractState,
        _code: felt252,
    );

    fn register_code(
        ref self: TContractState,
        _code: felt252,
    );

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

}


#[starknet::contract]
mod ReferralStorage {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use starknet::ClassHash;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;


    component!(path: UpgradeableComponent, storage: upgradeable_storage, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    /// Ownable
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SetTraderReferralCode: SetTraderReferralCode,
        RegisterCode: RegisterCode,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
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
        // @notice Maps the referral code to the owner
        code_owner: LegacyMap::<felt252, ContractAddress>,

        // @notice Maps the owner to the referral code
        // @dev To ensure that the trader can set the code only once
        user_code: LegacyMap::<ContractAddress, felt252>,

        // @notice Maps the trader to the referee code
        trader_referral_codes: LegacyMap::<ContractAddress, felt252>,
        
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable_storage: UpgradeableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ReferralStorage of super::IReferralStorage<ContractState> {

        fn get_trader_referral_code(
             self: @ContractState,
            _account: ContractAddress,
        ) -> felt252 {
             self.trader_referral_codes.read(_account)
        }

        fn get_code_owner(
             self: @ContractState,
            _code: felt252,
        ) -> ContractAddress {
            self.code_owner.read(_code)
        }

        fn get_user_code(
             self: @ContractState,
            _account: ContractAddress,
        ) -> felt252 {
            self.user_code.read(_account)
        }


        // @notice Sets the code to be referred by the trader
        // @param _code The code to set
        // @dev Trader can set the code only once
        // @dev Code must be registered
        // @dev Code owner cannot set the code for himself
        fn set_trader_referral_code(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(!self.trader_referral_codes.read(get_caller_address()).is_non_zero(), "ReferralStorage: trader already has a code");
            assert!(self.code_owner.read(_code).is_non_zero(), "ReferralStorage: code not found");
            assert!(self.code_owner.read(_code) != get_caller_address(), "ReferralStorage: code owner cannot set code for himself");

            let _account = get_caller_address();
            self.trader_referral_codes.write(_account, _code);
            self.emit(SetTraderReferralCode{account:_account, code: _code});  
        }

        // @notice Sets the referral code for the caller
        // @param _code The code to set
        // @dev User can set the code only once
        // @dev Code must bre unique
        fn register_code(
            ref self: ContractState,
            _code: felt252,
        ){
            assert!(!self.user_code.read(get_caller_address()).is_non_zero(), "ReferralStorage: user already has a code");

            assert!(!self.code_owner.read(_code).is_non_zero(), "ReferralStorage: code already registered");

            self.code_owner.write(_code, get_caller_address());
            self.user_code.write(get_caller_address(), _code);

            self.emit(RegisterCode{code:_code, account: get_caller_address()});
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();

            self.upgradeable_storage._upgrade(new_class_hash);
        }
    }



}

