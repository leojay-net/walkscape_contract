use starknet::ContractAddress;

/// Main WalkScape game system combining all components
#[starknet::interface]
pub trait IWalkScapeCore<TContractState> {
    // Player Management
    fn register_player(ref self: TContractState);
    fn get_player_stats(self: @TContractState, player: ContractAddress) -> PlayerStats;
    fn update_walk_xp(ref self: TContractState, player: ContractAddress, xp_gained: u256);
    fn update_health_score(ref self: TContractState, player: ContractAddress, health_score: u256);
    fn touch_grass_checkin(ref self: TContractState, location_hash: felt252);
    
    // Collectibles System (ERC721-like)
    fn claim_artifact(ref self: TContractState, location_hash: felt252, artifact_type: u8);
    fn get_artifact_owner(self: @TContractState, artifact_id: u256) -> ContractAddress;
    fn get_player_artifacts(self: @TContractState, player: ContractAddress) -> Array<u256>;
    fn transfer_artifact(ref self: TContractState, to: ContractAddress, artifact_id: u256);
    
    // Biome Pet System
    fn mint_pet(ref self: TContractState, pet_type: u8) -> u256;
    fn feed_pet(ref self: TContractState, pet_id: u256, nutrition_score: u256);
    fn evolve_pet(ref self: TContractState, pet_id: u256);
    fn get_pet_stats(self: @TContractState, pet_id: u256) -> PetStats;
    
    // Colony System (Social Groups)
    fn create_colony(ref self: TContractState, name: felt252) -> u256;
    fn join_colony(ref self: TContractState, colony_id: u256);
    fn leave_colony(ref self: TContractState);
    fn get_colony_stats(self: @TContractState, colony_id: u256) -> ColonyStats;
    
    // Staking System
    fn stake_for_growth(ref self: TContractState, amount: u256);
    fn harvest_growth_reward(ref self: TContractState) -> u256;
    fn get_stake_info(self: @TContractState, player: ContractAddress) -> StakeInfo;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PlayerStats {
    pub walks_xp: u256,
    pub health_score: u256,
    pub last_checkin: u64,
    pub total_artifacts: u256,
    pub current_colony: u256,
    pub pets_owned: u256,
    pub grass_touch_streak: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ArtifactData {
    pub location_hash: felt252,
    pub artifact_type: u8, // 0: mushroom, 1: fossil, 2: graffiti, 3: pixel_plant
    pub owner: ContractAddress,
    pub claimed_at: u64,
    pub rarity: u8, // 1-5 stars
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PetStats {
    pub owner: ContractAddress,
    pub pet_type: u8, // 0: plant, 1: creature, 2: digital_companion
    pub level: u256,
    pub happiness: u256,
    pub evolution_stage: u8,
    pub last_fed: u64,
    pub special_traits: u256, // bit flags for special abilities
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ColonyStats {
    pub name: felt252,
    pub creator: ContractAddress,
    pub member_count: u256,
    pub total_xp: u256,
    pub created_at: u64,
    pub weekly_challenge_score: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct StakeInfo {
    pub amount_staked: u256,
    pub stake_timestamp: u64,
    pub growth_multiplier: u256,
    pub last_harvest: u64,
}

#[starknet::contract]
mod WalkScapeCore {
    use super::{PlayerStats, ArtifactData, PetStats, ColonyStats, StakeInfo};
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp,
        storage::{
            StoragePointerReadAccess, StoragePointerWriteAccess,
            Map, StoragePathEntry
        }
    };

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PlayerRegistered: PlayerRegistered,
        ArtifactClaimed: ArtifactClaimed,
        PetMinted: PetMinted,
        PetEvolved: PetEvolved,
        ColonyCreated: ColonyCreated,
        PlayerJoinedColony: PlayerJoinedColony,
        GrassTouched: GrassTouched,
        StakeUpdated: StakeUpdated,
        RewardHarvested: RewardHarvested,
    }

    #[derive(Drop, starknet::Event)]
    struct PlayerRegistered {
        #[key]
        player: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ArtifactClaimed {
        #[key]
        player: ContractAddress,
        artifact_id: u256,
        location_hash: felt252,
        artifact_type: u8,
        rarity: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct PetMinted {
        #[key]
        owner: ContractAddress,
        pet_id: u256,
        pet_type: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct PetEvolved {
        pet_id: u256,
        new_evolution_stage: u8,
        special_traits_unlocked: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ColonyCreated {
        colony_id: u256,
        #[key]
        creator: ContractAddress,
        name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PlayerJoinedColony {
        #[key]
        player: ContractAddress,
        colony_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct GrassTouched {
        #[key]
        player: ContractAddress,
        location_hash: felt252,
        streak: u256,
        xp_gained: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct StakeUpdated {
        #[key]
        player: ContractAddress,
        amount: u256,
        new_total: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardHarvested {
        #[key]
        player: ContractAddress,
        reward_id: u256,
        stake_duration: u64,
    }

    #[storage]
    struct Storage {
        // Player management
        players: Map<ContractAddress, PlayerStats>,
        registered_players: Map<ContractAddress, bool>,
        
        // Artifacts system (NFT-like)
        artifacts: Map<u256, ArtifactData>,
        artifact_counter: u256,
        location_claimed: Map<felt252, bool>,
        player_artifacts: Map<(ContractAddress, u256), u256>, // (player, index) -> artifact_id
        player_artifact_count: Map<ContractAddress, u256>,
        
        // Pets system
        pets: Map<u256, PetStats>,
        pet_counter: u256,
        player_pets: Map<(ContractAddress, u256), u256>, // (player, index) -> pet_id
        player_pet_count: Map<ContractAddress, u256>,
        
        // Colony system
        colonies: Map<u256, ColonyStats>,
        colony_counter: u256,
        colony_members: Map<(u256, ContractAddress), bool>, // (colony_id, member) -> is_member
        player_colony: Map<ContractAddress, u256>,
        
        // Staking system
        stakes: Map<ContractAddress, StakeInfo>,
        total_staked: u256,
        
        // Game configuration
        admin: ContractAddress,
        paused: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.artifact_counter.write(1);
        self.pet_counter.write(1);
        self.colony_counter.write(1);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl WalkScapeCoreImpl of super::IWalkScapeCore<ContractState> {
        fn register_player(ref self: ContractState) {
            let caller = get_caller_address();
            assert(!self.registered_players.entry(caller).read(), 'Player already registered');
            
            let player_stats = PlayerStats {
                walks_xp: 0,
                health_score: 100, // Start with base health
                last_checkin: get_block_timestamp(),
                total_artifacts: 0,
                current_colony: 0,
                pets_owned: 0,
                grass_touch_streak: 0,
            };
            
            self.players.entry(caller).write(player_stats);
            self.registered_players.entry(caller).write(true);
            
            self.emit(PlayerRegistered { player: caller, timestamp: get_block_timestamp() });
        }

        fn get_player_stats(self: @ContractState, player: ContractAddress) -> PlayerStats {
            assert(self.registered_players.entry(player).read(), 'Player not registered');
            self.players.entry(player).read()
        }

        fn update_walk_xp(ref self: ContractState, player: ContractAddress, xp_gained: u256) {
            self._only_registered_player(player);
            let mut stats = self.players.entry(player).read();
            stats.walks_xp += xp_gained;
            self.players.entry(player).write(stats);
            
            // Update colony XP if player is in a colony
            let colony_id = self.player_colony.entry(player).read();
            if colony_id > 0 {
                let mut colony_stats = self.colonies.entry(colony_id).read();
                colony_stats.total_xp += xp_gained;
                self.colonies.entry(colony_id).write(colony_stats);
            }
        }

        fn update_health_score(ref self: ContractState, player: ContractAddress, health_score: u256) {
            self._only_registered_player(player);
            let mut stats = self.players.entry(player).read();
            stats.health_score = health_score;
            self.players.entry(player).write(stats);
        }

        fn touch_grass_checkin(ref self: ContractState, location_hash: felt252) {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            
            let mut stats = self.players.entry(caller).read();
            let current_time = get_block_timestamp();
            
            // Check if it's been at least 4 hours since last checkin for streak
            let time_diff = current_time - stats.last_checkin;
            if time_diff >= 14400 { // 4 hours in seconds
                stats.grass_touch_streak += 1;
            } else if time_diff >= 86400 { // 24 hours, reset streak
                stats.grass_touch_streak = 1;
            }
            
            stats.last_checkin = current_time;
            
            // Calculate XP based on streak
            let xp_gained = 10 + (stats.grass_touch_streak * 5);
            stats.walks_xp += xp_gained;
            
            self.players.entry(caller).write(stats);
            
            self.emit(GrassTouched {
                player: caller,
                location_hash,
                streak: stats.grass_touch_streak,
                xp_gained
            });
        }

        fn claim_artifact(ref self: ContractState, location_hash: felt252, artifact_type: u8) {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            assert(!self.location_claimed.entry(location_hash).read(), 'Location already claimed');
            assert(artifact_type <= 3, 'Invalid artifact type');
            
            let artifact_id = self.artifact_counter.read();
            
            // Calculate rarity based on player stats and randomness
            let caller_stats = self.players.entry(caller).read();
            let rarity = self._calculate_artifact_rarity(caller_stats.walks_xp, location_hash);
            
            let artifact = ArtifactData {
                location_hash,
                artifact_type,
                owner: caller,
                claimed_at: get_block_timestamp(),
                rarity,
            };
            
            self.artifacts.entry(artifact_id).write(artifact);
            self.location_claimed.entry(location_hash).write(true);
            self.artifact_counter.write(artifact_id + 1);
            
            // Add to player's artifact collection
            let player_artifact_count = self.player_artifact_count.entry(caller).read();
            self.player_artifacts.entry((caller, player_artifact_count)).write(artifact_id);
            self.player_artifact_count.entry(caller).write(player_artifact_count + 1);
            
            // Update player stats
            let mut stats = self.players.entry(caller).read();
            stats.total_artifacts += 1;
            self.players.entry(caller).write(stats);
            
            self.emit(ArtifactClaimed {
                player: caller,
                artifact_id,
                location_hash,
                artifact_type,
                rarity
            });
        }

        fn get_artifact_owner(self: @ContractState, artifact_id: u256) -> ContractAddress {
            self.artifacts.entry(artifact_id).read().owner
        }

        fn get_player_artifacts(self: @ContractState, player: ContractAddress) -> Array<u256> {
            let mut artifacts = ArrayTrait::new();
            let count = self.player_artifact_count.entry(player).read();
            let mut i = 0;
            
            while i < count {
                let artifact_id = self.player_artifacts.entry((player, i)).read();
                artifacts.append(artifact_id);
                i += 1;
            };
            
            artifacts
        }

        fn transfer_artifact(ref self: ContractState, to: ContractAddress, artifact_id: u256) {
            let caller = get_caller_address();
            let mut artifact = self.artifacts.entry(artifact_id).read();
            assert(artifact.owner == caller, 'Not artifact owner');
            assert(self.registered_players.entry(to).read(), 'Recipient not registered');
            
            // Update artifact ownership
            artifact.owner = to;
            self.artifacts.entry(artifact_id).write(artifact);
            
            // Update recipient's collection
            let to_artifact_count = self.player_artifact_count.entry(to).read();
            self.player_artifacts.entry((to, to_artifact_count)).write(artifact_id);
            self.player_artifact_count.entry(to).write(to_artifact_count + 1);
            
            // Update recipient's stats
            let mut to_stats = self.players.entry(to).read();
            to_stats.total_artifacts += 1;
            self.players.entry(to).write(to_stats);
        }

        fn mint_pet(ref self: ContractState, pet_type: u8) -> u256 {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            assert(pet_type <= 2, 'Invalid pet type');
            
            let pet_id = self.pet_counter.read();
            let caller_stats = self.players.entry(caller).read();
            
            // Require minimum XP to mint pet
            assert(caller_stats.walks_xp >= 100, 'Insufficient XP for pet');
            
            let pet = PetStats {
                owner: caller,
                pet_type,
                level: 1,
                happiness: 100,
                evolution_stage: 0,
                last_fed: get_block_timestamp(),
                special_traits: 0,
            };
            
            self.pets.entry(pet_id).write(pet);
            self.pet_counter.write(pet_id + 1);
            
            // Add to player's pet collection
            let player_pet_count = self.player_pet_count.entry(caller).read();
            self.player_pets.entry((caller, player_pet_count)).write(pet_id);
            self.player_pet_count.entry(caller).write(player_pet_count + 1);
            
            // Update player stats
            let mut stats = self.players.entry(caller).read();
            stats.pets_owned += 1;
            self.players.entry(caller).write(stats);
            
            self.emit(PetMinted { owner: caller, pet_id, pet_type });
            
            pet_id
        }

        fn feed_pet(ref self: ContractState, pet_id: u256, nutrition_score: u256) {
            let caller = get_caller_address();
            let mut pet = self.pets.entry(pet_id).read();
            assert(pet.owner == caller, 'Not pet owner');
            
            // Update happiness based on nutrition
            if nutrition_score >= 80 {
                if pet.happiness <= 80 {
                    pet.happiness += 20;
                } else {
                    pet.happiness = 100;
                }
            } else if nutrition_score >= 50 {
                if pet.happiness <= 90 {
                    pet.happiness += 10;
                } else {
                    pet.happiness = 100;
                }
            } else {
                if pet.happiness > 10 {
                    pet.happiness -= 10;
                }
            }
            
            pet.last_fed = get_block_timestamp();
            self.pets.entry(pet_id).write(pet);
        }

        fn evolve_pet(ref self: ContractState, pet_id: u256) {
            let caller = get_caller_address();
            let mut pet = self.pets.entry(pet_id).read();
            assert(pet.owner == caller, 'Not pet owner');
            assert(pet.level >= 10, 'Pet level too low');
            assert(pet.happiness >= 80, 'Pet not happy enough');
            assert(pet.evolution_stage < 3, 'Max evolution reached');
            
            pet.evolution_stage += 1;
            pet.level = 1; // Reset level for new evolution
            
            // Unlock special traits based on evolution stage
            let new_traits = match pet.evolution_stage {
                0 => 1, // Basic trait
                1 => 3, // Two traits  
                2 => 7, // Three traits
                _ => 15, // Max traits
            };
            pet.special_traits = new_traits;
            
            self.pets.entry(pet_id).write(pet);
            
            self.emit(PetEvolved {
                pet_id,
                new_evolution_stage: pet.evolution_stage,
                special_traits_unlocked: new_traits
            });
        }

        fn get_pet_stats(self: @ContractState, pet_id: u256) -> PetStats {
            self.pets.entry(pet_id).read()
        }

        fn create_colony(ref self: ContractState, name: felt252) -> u256 {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            assert(self.player_colony.entry(caller).read() == 0, 'Already in a colony');
            
            let colony_id = self.colony_counter.read();
            let colony = ColonyStats {
                name,
                creator: caller,
                member_count: 1,
                total_xp: 0,
                created_at: get_block_timestamp(),
                weekly_challenge_score: 0,
            };
            
            self.colonies.entry(colony_id).write(colony);
            self.colony_counter.write(colony_id + 1);
            self.player_colony.entry(caller).write(colony_id);
            self.colony_members.entry((colony_id, caller)).write(true);
            
            // Update player stats
            let mut stats = self.players.entry(caller).read();
            stats.current_colony = colony_id;
            self.players.entry(caller).write(stats);
            
            self.emit(ColonyCreated { colony_id, creator: caller, name });
            
            colony_id
        }

        fn join_colony(ref self: ContractState, colony_id: u256) {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            assert(self.player_colony.entry(caller).read() == 0, 'Already in a colony');
            assert(colony_id < self.colony_counter.read(), 'Colony does not exist');
            
            let mut colony = self.colonies.entry(colony_id).read();
            assert(colony.member_count < 50, 'Colony is full'); // Max 50 members
            
            colony.member_count += 1;
            self.colonies.entry(colony_id).write(colony);
            self.player_colony.entry(caller).write(colony_id);
            self.colony_members.entry((colony_id, caller)).write(true);
            
            // Update player stats
            let mut stats = self.players.entry(caller).read();
            stats.current_colony = colony_id;
            self.players.entry(caller).write(stats);
            
            self.emit(PlayerJoinedColony { player: caller, colony_id });
        }

        fn leave_colony(ref self: ContractState) {
            let caller = get_caller_address();
            let colony_id = self.player_colony.entry(caller).read();
            assert(colony_id > 0, 'Not in a colony');
            
            let mut colony = self.colonies.entry(colony_id).read();
            colony.member_count -= 1;
            self.colonies.entry(colony_id).write(colony);
            
            self.player_colony.entry(caller).write(0);
            self.colony_members.entry((colony_id, caller)).write(false);
            
            // Update player stats
            let mut stats = self.players.entry(caller).read();
            stats.current_colony = 0;
            self.players.entry(caller).write(stats);
        }

        fn get_colony_stats(self: @ContractState, colony_id: u256) -> ColonyStats {
            assert(colony_id < self.colony_counter.read(), 'Colony does not exist');
            self.colonies.entry(colony_id).read()
        }

        fn stake_for_growth(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            self._only_registered_player(caller);
            assert(amount > 0, 'Cannot stake zero');
            
            let mut stake_info = self.stakes.entry(caller).read();
            stake_info.amount_staked += amount;
            stake_info.stake_timestamp = get_block_timestamp();
            stake_info.growth_multiplier = self._calculate_growth_multiplier(stake_info.amount_staked);
            
            self.stakes.entry(caller).write(stake_info);
            self.total_staked.write(self.total_staked.read() + amount);
            
            self.emit(StakeUpdated {
                player: caller,
                amount,
                new_total: stake_info.amount_staked
            });
        }

        fn harvest_growth_reward(ref self: ContractState) -> u256 {
            let caller = get_caller_address();
            let stake_info = self.stakes.entry(caller).read();
            assert(stake_info.amount_staked > 0, 'No stake found');
            
            let current_time = get_block_timestamp();
            let stake_duration = current_time - stake_info.stake_timestamp;
            assert(stake_duration >= 86400, 'Must stake for at least 1 day'); // 24 hours
            
            // Create a reward NFT (special pet or artifact)
            let reward_id = self._mint_growth_reward(caller, stake_duration, stake_info.growth_multiplier);
            
            // Update last harvest time
            let mut updated_stake = stake_info;
            updated_stake.last_harvest = current_time;
            self.stakes.entry(caller).write(updated_stake);
            
            self.emit(RewardHarvested { player: caller, reward_id, stake_duration });
            
            reward_id
        }

        fn get_stake_info(self: @ContractState, player: ContractAddress) -> StakeInfo {
            self.stakes.entry(player).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _only_registered_player(self: @ContractState, player: ContractAddress) {
            assert(self.registered_players.entry(player).read(), 'Player not registered');
        }

        fn _calculate_artifact_rarity(
            self: @ContractState, 
            player_xp: u256, 
            location_hash: felt252
        ) -> u8 {
            // Simple rarity calculation based on XP and location
            let base_rarity = if player_xp >= 1000 { 3_u8 } else if player_xp >= 500 { 2_u8 } else { 1_u8 };
            
            // Add some pseudo-randomness based on location hash
            let random_factor: u256 = location_hash.into() % 100;
            if random_factor < 5 { base_rarity + 2 } // 5% chance for +2 rarity
            else if random_factor < 20 { base_rarity + 1 } // 15% chance for +1 rarity
            else { base_rarity }
        }

        fn _calculate_growth_multiplier(self: @ContractState, staked_amount: u256) -> u256 {
            if staked_amount >= 1000 { 300 } // 3x multiplier
            else if staked_amount >= 500 { 200 } // 2x multiplier
            else if staked_amount >= 100 { 150 } // 1.5x multiplier
            else { 100 } // 1x multiplier
        }

        fn _mint_growth_reward(
            ref self: ContractState,
            player: ContractAddress,
            stake_duration: u64,
            multiplier: u256
        ) -> u256 {
            // Determine reward type based on stake duration and multiplier
            let reward_type = if stake_duration >= 604800 && multiplier >= 200 { // 1 week + high stake
                2_u8 // Legendary pet
            } else if stake_duration >= 259200 { // 3 days
                1_u8 // Rare artifact
            } else {
                0_u8 // Common reward
            };
            
            // For now, just mint a pet as reward
            let pet_id = self.pet_counter.read();
            let pet = PetStats {
                owner: player,
                pet_type: reward_type,
                level: 1,
                happiness: 100,
                evolution_stage: 0,
                last_fed: get_block_timestamp(),
                special_traits: if reward_type == 2 { 15 } else { 0 }, // Legendary gets special traits
            };
            
            self.pets.entry(pet_id).write(pet);
            self.pet_counter.write(pet_id + 1);
            
            // Add to player's collection
            let player_pet_count = self.player_pet_count.entry(player).read();
            self.player_pets.entry((player, player_pet_count)).write(pet_id);
            self.player_pet_count.entry(player).write(player_pet_count + 1);
            
            // Update player stats
            let mut player_stats = self.players.entry(player).read();
            player_stats.pets_owned += 1;
            self.players.entry(player).write(player_stats);
            
            pet_id
        }
    }
}
