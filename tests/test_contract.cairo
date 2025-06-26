use starknet::ContractAddress;
use starknet::contract_address_const;

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address, 
    start_cheat_block_timestamp, stop_cheat_block_timestamp
};

use walkscape::{
    IWalkScapeCoreDispatcher, IWalkScapeCoreDispatcherTrait
};

fn deploy_walkscape_contract() -> (ContractAddress, IWalkScapeCoreDispatcher) {
    let admin = contract_address_const::<0x123>();
    let contract = declare("WalkScapeCore").unwrap().contract_class();
    let constructor_args = array![admin.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    let dispatcher = IWalkScapeCoreDispatcher { contract_address };
    (contract_address, dispatcher)
}

fn get_test_players() -> (ContractAddress, ContractAddress, ContractAddress) {
    let player1 = contract_address_const::<0x456>();
    let player2 = contract_address_const::<0x789>();
    let player3 = contract_address_const::<0xabc>();
    (player1, player2, player3)
}

#[test]
fn test_player_registration() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Test registering a new player
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Verify player stats
    let stats = dispatcher.get_player_stats(player1);
    assert(stats.walks_xp == 0, 'Initial XP should be 0');
    assert(stats.health_score == 100, 'Initial health should be 100');
    assert(stats.total_artifacts == 0, 'Initial artifacts should be 0');
    assert(stats.pets_owned == 0, 'Initial pets should be 0');
    assert(stats.grass_touch_streak == 0, 'Initial streak should be 0');
}

#[test]
#[should_panic(expected: ('Player already registered',))]
fn test_double_registration_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    // This should panic
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_walk_xp_update() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Update XP
    dispatcher.update_walk_xp(player1, 50);
    
    let stats = dispatcher.get_player_stats(player1);
    assert(stats.walks_xp == 50, 'XP should be updated');
}

#[test]
fn test_touch_grass_checkin() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Set initial timestamp before registration
    start_cheat_block_timestamp(contract_address, 1000);
    
    // Register player
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Wait 5 hours after registration before first grass touch
    start_cheat_block_timestamp(contract_address, 1000 + 18000); // +5 hours
    
    // First grass touch
    let location_hash = 'central_park_123';
    dispatcher.touch_grass_checkin(location_hash);
    
    let stats = dispatcher.get_player_stats(player1);
    assert(stats.grass_touch_streak == 1, 'Streak should be 1');
    assert(stats.walks_xp == 15, 'Should gain base + streak XP'); // 10 + (1 * 5)
    
    // Second grass touch after another 5 hours (should increase streak)
    start_cheat_block_timestamp(contract_address, 1000 + 36000); // +10 hours total
    dispatcher.touch_grass_checkin(location_hash);
    
    let stats2 = dispatcher.get_player_stats(player1);
    assert(stats2.grass_touch_streak == 2, 'Streak should be 2');
    assert(stats2.walks_xp == 35, 'Should gain 20 more XP'); // 15 + 10 + (2 * 5)
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_artifact_claiming() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 claims an artifact
    start_cheat_caller_address(contract_address, player1);
    let location_hash = 'museum_entrance_456';
    let artifact_type = 1; // fossil
    dispatcher.claim_artifact(location_hash, artifact_type);
    stop_cheat_caller_address(contract_address);
    
    // Verify artifact ownership
    let artifact_owner = dispatcher.get_artifact_owner(1);
    assert(artifact_owner == player1, 'Player1 should own artifact');
    
    // Verify player's artifact collection
    let player_artifacts = dispatcher.get_player_artifacts(player1);
    assert(player_artifacts.len() == 1, 'Player should have 1 artifact');
    assert(*player_artifacts.at(0) == 1, 'Should be artifact ID 1');
    
    // Verify player stats updated
    let stats = dispatcher.get_player_stats(player1);
    assert(stats.total_artifacts == 1, 'Total artifacts should be 1');
}

#[test]
#[should_panic(expected: ('Location already claimed',))]
fn test_double_claim_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    let location_hash = 'museum_entrance_456';
    let artifact_type = 1;
    
    // Player1 claims
    start_cheat_caller_address(contract_address, player1);
    dispatcher.claim_artifact(location_hash, artifact_type);
    stop_cheat_caller_address(contract_address);
    
    // Player2 tries to claim same location - should fail
    start_cheat_caller_address(contract_address, player2);
    dispatcher.claim_artifact(location_hash, artifact_type);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_artifact_transfer() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 claims an artifact
    start_cheat_caller_address(contract_address, player1);
    dispatcher.claim_artifact('location_123', 0);
    
    // Transfer to player2
    dispatcher.transfer_artifact(player2, 1);
    stop_cheat_caller_address(contract_address);
    
    // Verify transfer
    let new_owner = dispatcher.get_artifact_owner(1);
    assert(new_owner == player2, 'Player2 should now own artifact');
    
    let player2_artifacts = dispatcher.get_player_artifacts(player2);
    assert(player2_artifacts.len() == 1, 'Player2 should have 1 artifact');
}

#[test]
fn test_pet_minting_and_evolution() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Give player enough XP to mint pet
    stop_cheat_caller_address(contract_address);
    dispatcher.update_walk_xp(player1, 150);
    start_cheat_caller_address(contract_address, player1);
    
    // Mint a pet
    let pet_type = 0; // plant
    let pet_id = dispatcher.mint_pet(pet_type);
    assert(pet_id == 1, 'Pet ID should be 1');
    
    // Verify pet stats
    let pet_stats = dispatcher.get_pet_stats(pet_id);
    assert(pet_stats.owner == player1, 'Player should own pet');
    assert(pet_stats.pet_type == pet_type, 'Pet type should match');
    assert(pet_stats.level == 1, 'Initial level should be 1');
    assert(pet_stats.happiness == 100, 'Initial happiness should be 100');
    assert(pet_stats.evolution_stage == 0, 'Initial evolution should be 0');
    
    // Feed pet with good nutrition
    dispatcher.feed_pet(pet_id, 90);
    let updated_stats = dispatcher.get_pet_stats(pet_id);
    assert(updated_stats.happiness == 100, 'Happiness should remain 100'); // Already at max
    
    // Test evolution (need to manually set level to 10 for test)
    // In a real scenario, level would increase through gameplay
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Insufficient XP for pet',))]
fn test_pet_minting_insufficient_xp() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player (starts with 0 XP)
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to mint pet without enough XP - should fail
    dispatcher.mint_pet(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_colony_creation_and_joining() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player3);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 creates a colony
    start_cheat_caller_address(contract_address, player1);
    let colony_name = 'elite_walkers';
    let colony_id = dispatcher.create_colony(colony_name);
    assert(colony_id == 1, 'Colony ID should be 1');
    stop_cheat_caller_address(contract_address);
    
    // Verify colony stats
    let colony_stats = dispatcher.get_colony_stats(colony_id);
    assert(colony_stats.name == colony_name, 'Colony name should match');
    assert(colony_stats.creator == player1, 'Player1 should be creator');
    assert(colony_stats.member_count == 1, 'Should have 1 member');
    
    // Player2 joins the colony
    start_cheat_caller_address(contract_address, player2);
    dispatcher.join_colony(colony_id);
    stop_cheat_caller_address(contract_address);
    
    // Verify updated colony stats
    let updated_stats = dispatcher.get_colony_stats(colony_id);
    assert(updated_stats.member_count == 2, 'Should have 2 members');
    
    // Verify player2's stats
    let player2_stats = dispatcher.get_player_stats(player2);
    assert(player2_stats.current_colony == colony_id, 'Player2 should be in colony');
}

#[test]
fn test_colony_xp_accumulation() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players and create colony
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    let colony_id = dispatcher.create_colony('test_colony');
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    dispatcher.join_colony(colony_id);
    stop_cheat_caller_address(contract_address);
    
    // Give XP to colony members
    dispatcher.update_walk_xp(player1, 100);
    dispatcher.update_walk_xp(player2, 200);
    
    // Verify colony accumulated XP
    let colony_stats = dispatcher.get_colony_stats(colony_id);
    assert(colony_stats.total_xp == 300, 'Colony should have 300 total XP');
}

#[test]
fn test_staking_system() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Stake tokens
    let stake_amount = 500;
    dispatcher.stake_for_growth(stake_amount);
    
    // Verify stake info
    let stake_info = dispatcher.get_stake_info(player1);
    assert(stake_info.amount_staked == stake_amount, 'Stake amount should match');
    assert(stake_info.growth_multiplier == 200, 'Should get 2x multiplier'); // 500 tokens = 2x
    
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_harvest_growth_reward() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player and stake
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Set initial timestamp
    start_cheat_block_timestamp(contract_address, 1000);
    dispatcher.stake_for_growth(1000); // High stake for best multiplier
    
    // Wait 1 week
    start_cheat_block_timestamp(contract_address, 1000 + 604800); // +1 week
    
    // Harvest reward
    let reward_id = dispatcher.harvest_growth_reward();
    assert(reward_id == 1, 'Should get reward pet ID 1');
    
    // Verify pet was minted
    let pet_stats = dispatcher.get_pet_stats(reward_id);
    assert(pet_stats.owner == player1, 'Player should own reward pet');
    assert(pet_stats.pet_type == 2, 'Should be legendary pet type'); // Long stake + high amount
    assert(pet_stats.special_traits == 15, 'Legendary has special traits');
    
    stop_cheat_block_timestamp(contract_address);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Must stake for at least 1 day',))]
fn test_harvest_too_early_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Register player and stake
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    dispatcher.stake_for_growth(100);
    
    // Try to harvest immediately - should fail
    dispatcher.harvest_growth_reward();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_complex_gameplay_scenario() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Set initial timestamp
    start_cheat_block_timestamp(contract_address, 1000);
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 gameplay sequence
    start_cheat_caller_address(contract_address, player1);
    
    // 1. Touch grass daily for a week (spaced properly for streak)
    start_cheat_block_timestamp(contract_address, 1000);
    let mut i = 0;
    while i < 7 {
        // Each grass touch starts from day 1 to avoid timestamp conflict with registration
        let day_timestamp = 1000 + ((i + 1) * 86400); 
        start_cheat_block_timestamp(contract_address, day_timestamp);
        dispatcher.touch_grass_checkin('daily_park_location');
        i += 1;
    };
    
    // 2. Claim some artifacts during walks
    dispatcher.claim_artifact('artifact_location_1', 0); // mushroom
    dispatcher.claim_artifact('artifact_location_2', 1); // fossil
    
    // 3. Update walk XP from various activities
    stop_cheat_caller_address(contract_address);
    dispatcher.update_walk_xp(player1, 200);
    start_cheat_caller_address(contract_address, player1);
    
    // 4. Mint and care for a pet
    let pet_id = dispatcher.mint_pet(1); // creature type
    dispatcher.feed_pet(pet_id, 85); // Good nutrition
    
    // 5. Create and manage a colony
    let colony_id = dispatcher.create_colony('weekend_warriors');
    stop_cheat_caller_address(contract_address);
    
    // Player2 joins the colony
    start_cheat_caller_address(contract_address, player2);
    dispatcher.join_colony(colony_id);
    stop_cheat_caller_address(contract_address);
    
    // Add more XP to both players
    dispatcher.update_walk_xp(player1, 300);
    dispatcher.update_walk_xp(player2, 250);
    
    // 6. Start staking for long-term rewards
    start_cheat_caller_address(contract_address, player1);
    dispatcher.stake_for_growth(750);
    
    // Verify final state
    let final_stats = dispatcher.get_player_stats(player1);
    assert(final_stats.walks_xp >= 500, 'Should have significant XP');
    assert(final_stats.total_artifacts == 2, 'Should have 2 artifacts');
    assert(final_stats.pets_owned == 1, 'Should have 1 pet');
    assert(final_stats.current_colony == colony_id, 'Should be in colony');
    assert(final_stats.grass_touch_streak == 7, 'Should have 7-day streak');
    
    let colony_final = dispatcher.get_colony_stats(colony_id);
    assert(colony_final.member_count == 2, 'Colony should have 2 members');
    assert(colony_final.total_xp == 550, 'Colony should have combined XP');
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

// ADDITIONAL COMPREHENSIVE TESTS

#[test]
fn test_constructor_initialization() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    
    // Test that the contract is properly initialized
    // Since we don't have a direct getter for admin, we test indirectly
    // by ensuring the contract functions work properly
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    let stats = dispatcher.get_player_stats(player1);
    
    // Verify initial state
    assert(stats.walks_xp == 0, 'Initial XP not 0');
    assert(stats.health_score == 100, 'Initial health not 100');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Player not registered',))]
fn test_unregistered_player_operations_fail() {
    let (_contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    // Try to get stats without registering - should fail
    dispatcher.get_player_stats(player1);
}

#[test]
#[should_panic(expected: ('Player not registered',))]
fn test_unregistered_player_touch_grass_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.touch_grass_checkin('some_location');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Invalid artifact type',))]
fn test_invalid_artifact_type_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to claim artifact with invalid type (>3)
    dispatcher.claim_artifact('some_location', 5);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Invalid pet type',))]
fn test_invalid_pet_type_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Give enough XP
    stop_cheat_caller_address(contract_address);
    dispatcher.update_walk_xp(player1, 200);
    start_cheat_caller_address(contract_address, player1);
    
    // Try to mint pet with invalid type (>2)
    dispatcher.mint_pet(5);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Not artifact owner',))]
fn test_transfer_artifact_not_owner_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 claims artifact
    start_cheat_caller_address(contract_address, player1);
    dispatcher.claim_artifact('location_123', 0);
    stop_cheat_caller_address(contract_address);
    
    // Player2 tries to transfer player1's artifact - should fail
    start_cheat_caller_address(contract_address, player2);
    dispatcher.transfer_artifact(player2, 1);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Not pet owner',))]
fn test_feed_pet_not_owner_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, _player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Player1 mints pet
    dispatcher.update_walk_xp(player1, 200);
    start_cheat_caller_address(contract_address, player1);
    let pet_id = dispatcher.mint_pet(0);
    stop_cheat_caller_address(contract_address);
    
    // Player2 tries to feed player1's pet - should fail
    start_cheat_caller_address(contract_address, player2);
    dispatcher.feed_pet(pet_id, 80);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Already in a colony',))]
fn test_create_colony_already_in_colony_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Create first colony
    dispatcher.create_colony('first_colony');
    
    // Try to create second colony while in first - should fail
    dispatcher.create_colony('second_colony');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Colony does not exist',))]
fn test_join_nonexistent_colony_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to join non-existent colony
    dispatcher.join_colony(999);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Not in a colony',))]
fn test_leave_colony_not_in_colony_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to leave colony without being in one
    dispatcher.leave_colony();
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Cannot stake zero',))]
fn test_stake_zero_amount_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to stake zero amount
    dispatcher.stake_for_growth(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('No stake found',))]
fn test_harvest_without_stake_fails() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Try to harvest without staking
    dispatcher.harvest_growth_reward();
    stop_cheat_caller_address(contract_address);
}

// INTEGRATION TESTS

#[test]
fn test_full_game_ecosystem_integration() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, player3) = get_test_players();
    
    // === Phase 1: Player Registration ===
    start_cheat_block_timestamp(contract_address, 1000);
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player3);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // === Phase 2: Ecosystem Building ===
    start_cheat_block_timestamp(contract_address, 1000);
    
    // Player1 becomes the ecosystem leader
    start_cheat_caller_address(contract_address, player1);
    
    // Daily activities for 2 weeks (starting from day 1 to avoid timestamp conflict)
    let mut day = 1;
    while day <= 14 {
        let timestamp = 1000 + (day * 86400);
        start_cheat_block_timestamp(contract_address, timestamp);
        dispatcher.touch_grass_checkin('ecosystem_center');
        day += 1;
    };
    
    // Claim diverse artifacts
    dispatcher.claim_artifact('forest_mushroom_spot', 0); // mushroom
    dispatcher.claim_artifact('beach_fossil_site', 1);    // fossil
    dispatcher.claim_artifact('urban_graffiti_wall', 2);  // graffiti
    dispatcher.claim_artifact('garden_pixel_plant', 3);   // pixel_plant
    
    // === Phase 3: Colony and Social Features ===
    start_cheat_caller_address(contract_address, player1);
    
    // Create an elite colony FIRST
    let colony_id = dispatcher.create_colony('eco_warriors');
    
    stop_cheat_caller_address(contract_address);
    
    // External XP boosts from walking (now Player1 is in colony)
    dispatcher.update_walk_xp(player1, 500);
    
    start_cheat_caller_address(contract_address, player1);
    
    // Check XP before minting pets
    let pre_mint_stats = dispatcher.get_player_stats(player1);
    
    // Mint multiple pets (requires 100 XP each)
    let pet1 = dispatcher.mint_pet(0); // plant
    let pet2 = dispatcher.mint_pet(1); // creature
    let pet3 = dispatcher.mint_pet(2); // digital_companion
    
    // Check pets after minting
    let post_mint_stats = dispatcher.get_player_stats(player1);
    
    // Care for pets
    dispatcher.feed_pet(pet1, 95);
    dispatcher.feed_pet(pet2, 88);
    dispatcher.feed_pet(pet3, 92);
    
    stop_cheat_caller_address(contract_address);
    
    // === Phase 4: Other Players Join Ecosystem ===
    start_cheat_caller_address(contract_address, player2);
    dispatcher.join_colony(colony_id);
    
    // Player2 activities (start from day 2 to ensure proper time spacing)
    let mut day = 2;
    while day < 12 {
        let timestamp = 1000 + (day * 86400); // Start from day 2
        start_cheat_block_timestamp(contract_address, timestamp);
        dispatcher.touch_grass_checkin('riverside_path');
        day += 1;
    };
    
    dispatcher.claim_artifact('mountain_crystal_cave', 1);
    stop_cheat_caller_address(contract_address);
    
    dispatcher.update_walk_xp(player2, 350);
    
    start_cheat_caller_address(contract_address, player2);
    let player2_pet = dispatcher.mint_pet(1);
    dispatcher.feed_pet(player2_pet, 80);
    stop_cheat_caller_address(contract_address);
    
    // Player3 joins later
    start_cheat_caller_address(contract_address, player3);
    dispatcher.join_colony(colony_id);
    stop_cheat_caller_address(contract_address);
    
    // Give Player3 XP after joining colony so it counts toward colony total
    dispatcher.update_walk_xp(player3, 200);
    
    // === Phase 5: Long-term Staking and Rewards ===
    start_cheat_caller_address(contract_address, player1);
    dispatcher.stake_for_growth(1500); // Maximum tier staking
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.stake_for_growth(800);
    stop_cheat_caller_address(contract_address);
    
    // === Phase 6: Wait and Harvest ===
    // Fast forward 1 week from the last activity for harvesting
    start_cheat_block_timestamp(contract_address, 1000 + (21 * 86400)); // 3 weeks from start
    
    start_cheat_caller_address(contract_address, player1);
    let reward_pet1 = dispatcher.harvest_growth_reward();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    let _reward_pet2 = dispatcher.harvest_growth_reward();
    stop_cheat_caller_address(contract_address);
    
    // === Phase 7: Verification of Final State ===
    
    // Check Player1 final stats
    let player1_stats = dispatcher.get_player_stats(player1);
    assert(player1_stats.walks_xp >= 500, 'P1: Low XP');
    assert(player1_stats.total_artifacts == 4, 'P1: Wrong artifacts');
    assert(player1_stats.grass_touch_streak == 14, 'P1: Wrong streak');
    assert(player1_stats.current_colony == colony_id, 'P1: Wrong colony');
    
    // Player1 should have: 3 minted pets + 1 reward pet = 4 total
    assert(player1_stats.pets_owned == 4, 'P1: Should have 4 pets total');
    
    // Check Player2 final stats
    let player2_stats = dispatcher.get_player_stats(player2);
    assert(player2_stats.walks_xp >= 350, 'P2: Low XP');
    assert(player2_stats.total_artifacts == 1, 'P2: Wrong artifacts');
    assert(player2_stats.pets_owned == 2, 'P2: Wrong pet count'); // 1 minted + 1 reward
    assert(player2_stats.current_colony == colony_id, 'P2: Wrong colony');
    
    // Check colony final stats
    let final_colony = dispatcher.get_colony_stats(colony_id);
    assert(final_colony.member_count == 3, 'Colony: Wrong members');
    assert(final_colony.total_xp >= 1050, 'Colony: Low total XP'); // 500+350+200
    assert(final_colony.creator == player1, 'Colony: Wrong creator');
    
    // Check staking worked
    let player1_stake = dispatcher.get_stake_info(player1);
    assert(player1_stake.amount_staked == 1500, 'P1: Wrong stake');
    assert(player1_stake.growth_multiplier == 300, 'P1: Wrong multiplier');
    
    // Check reward pets are legendary
    let reward_pet1_stats = dispatcher.get_pet_stats(reward_pet1);
    assert(reward_pet1_stats.pet_type == 2, 'Reward1: Not legendary');
    assert(reward_pet1_stats.special_traits == 15, 'Reward1: No traits');
    
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_artifact_rarity_distribution() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    
    // Give different XP levels and claim artifacts to test rarity
    dispatcher.claim_artifact('low_xp_location_1', 0);
    
    stop_cheat_caller_address(contract_address);
    dispatcher.update_walk_xp(player1, 600); // Mid-tier XP
    start_cheat_caller_address(contract_address, player1);
    
    dispatcher.claim_artifact('mid_xp_location_2', 1);
    
    stop_cheat_caller_address(contract_address);
    dispatcher.update_walk_xp(player1, 500); // Total 1100, high tier
    start_cheat_caller_address(contract_address, player1);
    
    dispatcher.claim_artifact('high_xp_location_3', 2);
    
    // Verify artifacts exist (we can't easily test rarity without more complex setup)
    let artifacts = dispatcher.get_player_artifacts(player1);
    assert(artifacts.len() == 3, 'Should have 3 artifacts');
    
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_pet_happiness_and_feeding_mechanics() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, _player2, _player3) = get_test_players();
    
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    dispatcher.update_walk_xp(player1, 200);
    start_cheat_caller_address(contract_address, player1);
    
    let pet_id = dispatcher.mint_pet(0);
    let initial_stats = dispatcher.get_pet_stats(pet_id);
    assert(initial_stats.happiness == 100, 'Initial happiness wrong');
    
    // Test poor nutrition feeding
    dispatcher.feed_pet(pet_id, 30); // Poor nutrition
    let poor_stats = dispatcher.get_pet_stats(pet_id);
    assert(poor_stats.happiness == 90, 'Poor feeding happiness wrong');
    
    // Test good nutrition feeding
    dispatcher.feed_pet(pet_id, 85); // Good nutrition
    let good_stats = dispatcher.get_pet_stats(pet_id);
    assert(good_stats.happiness == 100, 'Good feeding happiness wrong');
    
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_stake_multiplier_tiers() {
    let (contract_address, dispatcher) = deploy_walkscape_contract();
    let (player1, player2, player3) = get_test_players();
    
    // Register players
    start_cheat_caller_address(contract_address, player1);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player3);
    dispatcher.register_player();
    stop_cheat_caller_address(contract_address);
    
    // Test different stake tiers
    start_cheat_caller_address(contract_address, player1);
    dispatcher.stake_for_growth(50); // Low tier
    let stake1 = dispatcher.get_stake_info(player1);
    assert(stake1.growth_multiplier == 100, 'Low tier multiplier wrong');
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player2);
    dispatcher.stake_for_growth(600); // Mid-high tier
    let stake2 = dispatcher.get_stake_info(player2);
    assert(stake2.growth_multiplier == 200, 'Mid tier multiplier wrong');
    stop_cheat_caller_address(contract_address);
    
    start_cheat_caller_address(contract_address, player3);
    dispatcher.stake_for_growth(1200); // Max tier
    let stake3 = dispatcher.get_stake_info(player3);
    assert(stake3.growth_multiplier == 300, 'Max tier multiplier wrong');
    stop_cheat_caller_address(contract_address);
}
