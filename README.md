# WalkScape Smart Contract

A comprehensive blockchain-powered location-based exploration game built on Starknet using Cairo. This smart contract enables real-world exploration mechanics with digital rewards, pet breeding, social colonies, and decentralized staking.

## Contract Overview

WalkScape is a location-based game that bridges physical exploration with blockchain gaming. Players can:
- **Touch Grass**: Check-in at outdoor locations to earn XP and build streaks
- **Collect Artifacts**: Claim location-based NFTs (Mushrooms, Fossils, Graffiti, Pixel Plants)
- **Breed Digital Pets**: Mint, feed, and evolve pets with unique traits
- **Join Colonies**: Participate in social exploration communities
- **Stake for Growth**: Lock tokens to accelerate pet evolution and earn rewards

## Architecture

### Core Systems

#### 1. Player Management System
- Player registration and stats tracking
- XP progression with level calculation
- Health score monitoring
- Daily check-in streak management

#### 2. Touch Grass Mechanism
- Location-based check-ins using GPS coordinates
- Streak building with consecutive day rewards
- XP rewards (15 XP per successful check-in)
- Anti-cheat validation through location hashing

#### 3. Artifact Collection System (ERC721-like)
- Location-based artifact claiming
- Four artifact types: Mushroom, Fossil, Graffiti, Pixel Plant
- Rarity system (Common to Legendary)
- Ownership transfer capabilities
- Anti-duplicate location claiming

#### 4. Digital Pet System
- Pet minting with 100 XP cost
- Three pet types: Plant, Creature, Digital Companion
- Feeding and happiness mechanics
- Evolution stages with level progression
- Special traits system using bit flags

#### 5. Social Colony System
- Colony creation and management
- Player membership tracking
- Collective XP accumulation
- Weekly challenge participation
- Social bonuses and rewards

#### 6. Growth Staking System
- Token staking for pet growth acceleration
- Growth multipliers based on stake amount
- Reward harvesting mechanism
- Time-locked staking periods

## Contract Interface

### Player Management
```cairo
fn register_player(ref self: TContractState);
fn get_player_stats(self: @TContractState, player: ContractAddress) -> PlayerStats;
fn update_walk_xp(ref self: TContractState, player: ContractAddress, xp_gained: u256);
fn update_health_score(ref self: TContractState, player: ContractAddress, health_score: u256);
fn touch_grass_checkin(ref self: TContractState, location_hash: felt252);
```

### Artifact System
```cairo
fn claim_artifact(ref self: TContractState, location_hash: felt252, artifact_type: u8);
fn get_artifact_owner(self: @TContractState, artifact_id: u256) -> ContractAddress;
fn get_player_artifacts(self: @TContractState, player: ContractAddress) -> Array<u256>;
fn transfer_artifact(ref self: TContractState, to: ContractAddress, artifact_id: u256);
```

### Pet System
```cairo
fn mint_pet(ref self: TContractState, pet_type: u8) -> u256;
fn feed_pet(ref self: TContractState, pet_id: u256, nutrition_score: u256);
fn evolve_pet(ref self: TContractState, pet_id: u256);
fn get_pet_stats(self: @TContractState, pet_id: u256) -> PetStats;
fn get_player_pets(self: @TContractState, player: ContractAddress) -> Array<u256>;
```

### Colony System
```cairo
fn create_colony(ref self: TContractState, name: felt252) -> u256;
fn join_colony(ref self: TContractState, colony_id: u256);
fn leave_colony(ref self: TContractState);
fn get_colony_stats(self: @TContractState, colony_id: u256) -> ColonyStats;
```

### Staking System
```cairo
fn stake_for_growth(ref self: TContractState, amount: u256);
fn harvest_growth_reward(ref self: TContractState) -> u256;
fn get_stake_info(self: @TContractState, player: ContractAddress) -> StakeInfo;
```

## Data Structures

### PlayerStats
```cairo
pub struct PlayerStats {
    pub walks_xp: u256,              // Total XP earned from walking
    pub health_score: u256,          // Health rating (0-100)
    pub last_checkin: u64,           // Timestamp of last grass touch
    pub total_artifacts: u256,       // Number of artifacts collected
    pub current_colony: u256,        // Current colony membership
    pub pets_owned: u256,            // Number of pets owned
    pub grass_touch_streak: u256,    // Consecutive days of grass touching
}
```

### ArtifactData
```cairo
pub struct ArtifactData {
    pub location_hash: felt252,      // Unique location identifier
    pub artifact_type: u8,          // 0: mushroom, 1: fossil, 2: graffiti, 3: pixel_plant
    pub owner: ContractAddress,      // Current owner
    pub claimed_at: u64,             // Claim timestamp
    pub rarity: u8,                  // Rarity level (0-3)
}
```

### PetStats
```cairo
pub struct PetStats {
    pub owner: ContractAddress,      // Pet owner
    pub pet_type: u8,               // 0: plant, 1: creature, 2: digital_companion
    pub level: u256,                // Current level
    pub happiness: u256,            // Happiness score (0-100)
    pub evolution_stage: u8,        // Evolution stage (0-5)
    pub last_fed: u64,              // Last feeding timestamp
    pub special_traits: u256,       // Bit flags for special abilities
}
```

### ColonyStats
```cairo
pub struct ColonyStats {
    pub name: felt252,              // Colony name
    pub creator: ContractAddress,   // Colony founder
    pub member_count: u256,         // Number of members
    pub total_xp: u256,            // Collective XP
    pub created_at: u64,           // Creation timestamp
    pub weekly_challenge_score: u256, // Challenge performance
}
```

### StakeInfo
```cairo
pub struct StakeInfo {
    pub amount_staked: u256,        // Staked token amount
    pub stake_timestamp: u64,       // Staking start time
    pub growth_multiplier: u256,    // Growth acceleration factor
    pub last_harvest: u64,          // Last reward harvest time
}
```

## Game Mechanics

### XP and Leveling System
- **Base XP**: 15 XP per grass touch
- **Level Formula**: `sqrt(total_xp / 100) + 1`
- **Streak Bonuses**: Consecutive days provide multipliers
- **Activity Rewards**: Additional XP for pet care and artifact collection

### Artifact Rarity Calculation
```cairo
// Rarity based on player XP and location randomness
fn _calculate_artifact_rarity(player_xp: u256, location_hash: felt252) -> u8 {
    let base_rarity = (player_xp / 1000) % 4;
    let location_bonus = (location_hash.into() % 10);
    if location_bonus >= 8 { 3 } // Legendary
    else if location_bonus >= 6 { 2 } // Rare  
    else if location_bonus >= 3 { 1 } // Uncommon
    else { 0 } // Common
}
```

### Pet Evolution System
- **Level Requirements**: Evolution at levels 10, 25, 50, 100, 200
- **Happiness Threshold**: Minimum 70 happiness required
- **Evolution Benefits**: Increased stats and special trait unlocks
- **Special Traits**: Bit flag system for unique abilities

### Streak Management
- **Minimum Interval**: 4 hours between check-ins
- **Streak Reset**: After 48 hours of inactivity
- **Maximum Streak**: No upper limit for dedicated players
- **Bonus Rewards**: Streak multipliers for consecutive days

## Security Features

### Access Control
- **Player Registration**: One-time registration prevents duplicate accounts
- **Ownership Validation**: All operations verify caller permissions
- **Location Uniqueness**: Prevents multiple claims at same location
- **Time-based Restrictions**: Cooldowns prevent spam transactions

### Anti-Cheat Mechanisms
- **Location Hashing**: Cryptographic location verification
- **Time Validation**: Reasonable intervals between actions
- **Duplicate Prevention**: No repeated claims at same coordinates
- **Admin Oversight**: Administrative functions for edge cases

### Economic Safeguards
- **Pet Minting Cost**: 100 XP requirement prevents spam
- **Staking Limits**: Reasonable bounds on stake amounts
- **Reward Calculations**: Overflow protection in all calculations
- **Transfer Restrictions**: Ownership verification for all transfers

## Events

### Player Events
```cairo
PlayerRegistered { player: ContractAddress, timestamp: u64 }
GrassTouched { player: ContractAddress, location_hash: felt252, streak: u256, xp_gained: u256 }
```

### Artifact Events
```cairo
ArtifactClaimed { player: ContractAddress, artifact_id: u256, location_hash: felt252, artifact_type: u8, rarity: u8 }
```

### Pet Events
```cairo
PetMinted { owner: ContractAddress, pet_id: u256, pet_type: u8 }
PetEvolved { pet_id: u256, new_evolution_stage: u8, special_traits_unlocked: u256 }
```

### Colony Events
```cairo
ColonyCreated { colony_id: u256, creator: ContractAddress, name: felt252 }
PlayerJoinedColony { player: ContractAddress, colony_id: u256 }
```

### Staking Events
```cairo
StakeUpdated { player: ContractAddress, amount: u256, new_total: u256 }
RewardHarvested { player: ContractAddress, reward_id: u256, stake_duration: u64 }
```

## Development Setup

### Prerequisites
- **Cairo**: Version 2.11.4 or higher
- **Scarb**: Latest version for package management
- **Starknet Foundry**: For testing and deployment
- **OpenZeppelin Contracts**: v1.0.0 for security patterns

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd walkscape

# Install dependencies (handled by Scarb)
scarb build

# Run tests
scarb test
```

### Environment Configuration
```toml
# snfoundry.toml
[sncast.sepolia]
account = "myaccount"
accounts-file = "~/.starknet_accounts/starknet_open_zeppelin_accounts.json"
url = "https://starknet-sepolia.public.blastapi.io"
```

### Building and Testing
```bash
# Build the contract
scarb build

# Run unit tests
snforge test

# Run specific test
snforge test test_register_player

# Check test coverage
snforge test --coverage
```

## Deployment

### Build Contract
```bash
# Build for Sepolia testnet
scarb build --profile sepolia

# Build for mainnet
scarb build --profile release
```

### Deploy to Sepolia
```bash
# Declare contract class
sncast --profile sepolia declare --contract-name WalkScapeCore

# Deploy with admin address
sncast --profile sepolia deploy \
  --class-hash <CLASS_HASH> \
  --constructor-calldata <ADMIN_ADDRESS>
```

### Verify Deployment
```bash
# Test registration
sncast --profile sepolia invoke \
  --contract-address <CONTRACT_ADDRESS> \
  --function register_player

# Check player stats
sncast --profile sepolia call \
  --contract-address <CONTRACT_ADDRESS> \
  --function get_player_stats \
  --calldata <PLAYER_ADDRESS>
```

## Testing

### Unit Tests
```bash
# Run all tests
snforge test

# Test specific modules
snforge test test_player_management
snforge test test_artifact_system
snforge test test_pet_breeding
snforge test test_colony_features
snforge test test_staking_system
```

### Integration Tests
```bash
# End-to-end game flow tests
snforge test test_complete_game_flow
snforge test test_multi_player_scenarios
snforge test test_edge_cases
```

### Gas Optimization Tests
```bash
# Analyze gas usage
snforge test --gas-report

# Optimize critical functions
snforge test test_gas_optimization
```

## Security Considerations

### Audit Checklist
- [ ] **Access Control**: All functions properly validate caller permissions
- [ ] **Integer Overflow**: SafeMath patterns prevent overflow/underflow
- [ ] **Reentrancy**: No external calls in state-changing functions
- [ ] **Location Validation**: Cryptographic location verification
- [ ] **Economic Logic**: Reward calculations prevent exploitation
- [ ] **Time Dependencies**: Block timestamp usage is secure
- [ ] **Admin Functions**: Proper access control for administrative operations

### Known Limitations
- **GPS Accuracy**: Relies on client-side location accuracy
- **Network Latency**: Blockchain confirmation times affect UX
- **Storage Costs**: Large-scale adoption may require optimization
- **Scalability**: Consider L2 solutions for high transaction volume

## Performance Metrics

### Gas Usage (Approximate)
- **Player Registration**: ~50,000 gas
- **Touch Grass Check-in**: ~30,000 gas
- **Artifact Claiming**: ~45,000 gas
- **Pet Minting**: ~35,000 gas
- **Pet Feeding**: ~25,000 gas
- **Colony Creation**: ~40,000 gas
- **Staking Operations**: ~30,000 gas

### Scalability Considerations
- **State Management**: Efficient storage patterns minimize costs
- **Batch Operations**: Multiple actions can be batched
- **Event Optimization**: Minimal event data reduces gas
- **View Functions**: No gas cost for reading data

## Upgradability

### Current Version: 0.1.0
- **Architecture**: Modular design allows component upgrades
- **Storage Patterns**: Future-compatible storage layout
- **Interface Stability**: Core interfaces designed for long-term stability
- **Migration Path**: Clear upgrade path for future versions

### Future Enhancements
- **Layer 2 Integration**: Starknet scaling solutions
- **Cross-Chain Features**: Multi-chain artifact trading
- **Advanced AI**: On-chain AI for dynamic content
- **VR/AR Integration**: Immersive exploration experiences

## Contributing

### Development Guidelines
- **Code Style**: Follow Cairo best practices and patterns
- **Testing**: Comprehensive test coverage required
- **Documentation**: Clear function documentation with examples
- **Security**: Security-first development approach
- **Gas Optimization**: Efficient code patterns for cost reduction

### Contribution Process
1. **Fork Repository**: Create development branch
2. **Implement Changes**: Follow coding standards
3. **Write Tests**: Ensure all functionality is tested
4. **Submit PR**: Detailed description of changes
5. **Code Review**: Security and quality review process

## License

This project is part of the WalkScape ecosystem. See license files for specific terms.

## Resources

- **Starknet Documentation**: [docs.starknet.io](https://docs.starknet.io/)
- **Cairo Book**: [cairo-book.github.io](https://cairo-book.github.io/)
- **Starknet Foundry**: [foundry-rs.github.io/starknet-foundry](https://foundry-rs.github.io/starknet-foundry/)
- **OpenZeppelin Cairo**: [github.com/OpenZeppelin/cairo-contracts](https://github.com/OpenZeppelin/cairo-contracts)

---

**WalkScape Smart Contract** - Bringing real-world exploration to the blockchain.
