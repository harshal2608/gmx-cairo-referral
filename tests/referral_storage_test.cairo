use starknet::{ContractAddress,get_caller_address,contract_address_try_from_felt252};
use zeroable::Zeroable;
use gmx_referral_cairo::referral_storage::{ReferralStorage,IReferralStorageDispatcher,IReferralStorageDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, spy_events,
    SpyOn, EventSpy, EventFetcher, Event, EventAssertions
};
use gmx_referral_cairo::test_contracts::referral_storage_v2::{ReferralStorageV2,IReferralStorageV2Dispatcher,IReferralStorageV2DispatcherTrait};

fn setup_referral_storage_dispatcher() -> (ContractAddress,IReferralStorageDispatcher,ContractAddress) {
    let contract = declare("ReferralStorage");

    let mut contract_constructor_calldata = Default::default();
    let owner = contract_address_try_from_felt252('owner').unwrap();

    Serde::serialize(@owner, ref contract_constructor_calldata);
    let contract_address = contract.deploy(@contract_constructor_calldata).unwrap();

    (contract_address,IReferralStorageDispatcher { contract_address },owner)
}

#[test]
fn test_register_code() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);

    dispatcher.register_code('jonty');

    let code_owner = dispatcher.get_code_owner('jonty');
    assert_eq!(code_owner, user);
}

#[test]
#[should_panic(expected: ("ReferralStorage: user already has code",))]
fn test_user_register_code_again() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);

    dispatcher.register_code('jonty');
    dispatcher.register_code('monty');
}

#[test]
#[should_panic(expected: ("ReferralStorage: code already registered",))]
fn test_register_same_code() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);

    dispatcher.register_code('jonty');

    let user2 = 124.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user2);
    dispatcher.register_code('jonty');
}

#[test]
fn test_set_trader_referral_code() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);
    dispatcher.register_code('jonty');

    let user2 = 124.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user2);
    dispatcher.set_trader_referral_code('jonty');

    let user2_referral_code = dispatcher.get_trader_referral_code(user2);
    assert_eq!(user2_referral_code, 'jonty');
}

#[test]
#[should_panic(expected: ("ReferralStorage: code not found",))]
fn test_set_trader_referral_code_not_found() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);
    dispatcher.set_trader_referral_code('jonty');
}

#[test]
#[should_panic(expected: ("ReferralStorage: code owner cannot set code for himself",))]
fn test_set_trader_referral_code_self() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);
    dispatcher.register_code('jonty');

    dispatcher.set_trader_referral_code('jonty');
}

#[test]
#[should_panic(expected: ("ReferralStorage: trader already has a code",))]
fn test_set_trader_referral_code_already_has_code() {
    let (contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let user = 123.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user);
    dispatcher.register_code('jonty');

    let user2 = 124.try_into().unwrap();
    start_prank(CheatTarget::One(contract_address), user2);
    dispatcher.register_code('monty');

    dispatcher.set_trader_referral_code('jonty');
    dispatcher.set_trader_referral_code('monty');
}

#[test]
#[should_panic]
fn test_upgrade_referral_storage_by_not_onwer() {
    let (_contract_address,dispatcher,_owner) = setup_referral_storage_dispatcher();
    
    let new_pool_class_hash = declare("ReferralStorageV2").class_hash;
    dispatcher.upgrade(new_pool_class_hash);
}

#[test]
fn test_upgrade_referral_storage() {
    let (contract_address,dispatcher,owner) = setup_referral_storage_dispatcher();
    
    let new_pool_class_hash = declare("ReferralStorageV2").class_hash;
    start_prank(CheatTarget::One(contract_address), owner);
    dispatcher.upgrade(new_pool_class_hash);
}
