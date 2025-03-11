module amoca_certificate_nft::token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID};
    use std::string::{Self, String};
    use sui::event;
    use sui::package;
    use sui::display;

    // One-Time-Witness for the module
    struct AMOCA_TOKEN has drop {}

    // Capability for managing staking
    struct StakingCapability has key {
        id: UID,
        admin: address
    }

    // Staking pool
    struct StakingPool has key {
        id: UID,
        total_staked: Balance<AMOCA_TOKEN>,
        reward_rate: u64,
        min_stake_duration: u64,
        admin: address
    }

    // User stake
    struct Stake has key, store {
        id: UID,
        owner: address,
        amount: Balance<AMOCA_TOKEN>,
        start_time: u64,
        end_time: u64,
        claimed: bool
    }

    // Governance proposal
    struct Proposal has key {
        id: UID,
        title: String,
        description: String,
        proposer: address,
        start_time: u64,
        end_time: u64,
        yes_votes: u64,
        no_votes: u64,
        executed: bool
    }

    // Data access rights token
    struct DataAccessRight has key, store {
        id: UID,
        data_id: String,
        owner: address,
        access_level: u8,
        expiration: u64
    }

    // Events
    struct TokensMinted has copy, drop {
        amount: u64,
        recipient: address
    }

    struct StakeCreated has copy, drop {
        stake_id: address,
        owner: address,
        amount: u64,
        duration: u64
    }

    struct RewardClaimed has copy, drop {
        stake_id: address,
        owner: address,
        reward_amount: u64
    }

    struct ProposalCreated has copy, drop {
        proposal_id: address,
        proposer: address,
        title: String
    }

    struct VoteCast has copy, drop {
        proposal_id: address,
        voter: address,
        vote: bool,
        weight: u64
    }

    struct DataAccessRightCreated has copy, drop {
        data_id: String,
        owner: address,
        access_level: u8
    }

    // === Functions ===

    // Initialize the module and create the AMOCA token
    fun init(witness: AMOCA_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, // decimals
            b"AMOCA", // symbol
            b"AMOCA Healthcare Token", // name
            b"Healthcare utility token for the AMOCA platform", // description
            option::none(), // icon url
            ctx
        );

        // Create staking capability
        let staking_cap = StakingCapability {
            id: object::new(ctx),
            admin: tx_context::sender(ctx)
        };

        // Create staking pool
        let staking_pool = StakingPool {
            id: object::new(ctx),
            total_staked: balance::zero<AMOCA_TOKEN>(),
            reward_rate: 5, // 5% annual reward rate
            min_stake_duration: 86400, // 1 day minimum stake
            admin: tx_context::sender(ctx)
        };

        // Transfer capabilities to the sender
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_transfer(metadata, tx_context::sender(ctx));
        transfer::public_transfer(staking_cap, tx_context::sender(ctx));
        transfer::share_object(staking_pool);
    }

    // Mint new tokens (admin only)
    public entry fun mint_tokens(
        treasury_cap: &mut TreasuryCap<AMOCA_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Only admin can mint tokens
        assert!(tx_context::sender(ctx) == treasury_cap.admin, 1);
        
        let coins = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coins, recipient);
        
        event::emit(TokensMinted {
            amount,
            recipient
        });
    }

    // Stake tokens
    public entry fun stake_tokens(
        pool: &mut StakingPool,
        tokens: Coin<AMOCA_TOKEN>,
        duration: u64,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch(ctx);
        
        // Ensure minimum stake duration
        assert!(duration >= pool.min_stake_duration, 1);
        
        // Create stake
        let stake = Stake {
            id: object::new(ctx),
            owner: sender,
            amount: coin::into_balance(tokens),
            start_time: now,
            end_time: now + duration,
            claimed: false
        };
        
        // Update pool
        balance::join(&mut pool.total_staked, stake.amount);
        
        // Transfer stake to sender
        transfer::transfer(stake, sender);
        
        event::emit(StakeCreated {
            stake_id: object::uid_to_address(&stake.id),
            owner: sender,
            amount,
            duration
        });
    }

    // Claim staking rewards
    public entry fun claim_rewards(
        pool: &mut StakingPool,
        stake: &mut Stake,
        treasury_cap: &mut TreasuryCap<AMOCA_TOKEN>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch(ctx);
        
        // Verify ownership
        assert!(stake.owner == sender, 1);
        // Verify not already claimed
        assert!(!stake.claimed, 2);
        // Verify stake period is over
        assert!(now >= stake.end_time, 3);
        
        // Calculate reward
        let stake_duration = stake.end_time - stake.start_time;
        let amount = balance::value(&stake.amount);
        let reward_amount = (amount * pool.reward_rate * stake_duration) / (100 * 365 * 86400);
        
        // Mint reward tokens
        let reward_coins = coin::mint(treasury_cap, reward_amount, ctx);
        transfer::public_transfer(reward_coins, sender);
        
        // Mark as claimed
        stake.claimed = true;
        
        event::emit(RewardClaimed {
            stake_id: object::uid_to_address(&stake.id),
            owner: sender,
            reward_amount
        });
    }

    // Unstake tokens
    public entry fun unstake_tokens(
        pool: &mut StakingPool,
        stake: Stake,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch(ctx);
        
        // Verify ownership
        assert!(stake.owner == sender, 1);
        // Verify stake period is over
        assert!(now >= stake.end_time, 2);
        
        // Unwrap stake
        let Stake { id, owner: _, amount, start_time: _, end_time: _, claimed: _ } = stake;
        object::delete(id);
        
        // Return tokens
        let coins = coin::from_balance(amount, ctx);
        transfer::public_transfer(coins, sender);
    }

    // Create governance proposal
    public entry fun create_proposal(
        title: vector<u8>,
        description: vector<u8>,
        duration: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch(ctx);
        
        let proposal = Proposal {
            id: object::new(ctx),
            title: string::utf8(title),
            description: string::utf8(description),
            proposer: sender,
            start_time: now,
            end_time: now + duration,
            yes_votes: 0,
            no_votes: 0,
            executed: false
        };
        
        // Share proposal object
        transfer::share_object(proposal);
        
        event::emit(ProposalCreated {
            proposal_id: object::uid_to_address(&proposal.id),
            proposer: sender,
            title: string::utf8(title)
        });
    }

    // Vote on proposal
    public entry fun vote_on_proposal(
        proposal: &mut Proposal,
        vote: bool,
        weight: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let now = tx_context::epoch(ctx);
        
        // Verify voting period
        assert!(now >= proposal.start_time && now <= proposal.end_time, 1);
        // Verify proposal not executed
        assert!(!proposal.executed, 2);
        
        // Record vote
        if (vote) {
            proposal.yes_votes = proposal.yes_votes + weight;
        } else {
            proposal.no_votes = proposal.no_votes + weight;
        };
        
        event::emit(VoteCast {
            proposal_id: object::uid_to_address(&proposal.id),
            voter: sender,
            vote,
            weight
        });
    }

    // Create data access right
    public entry fun create_data_access_right(
        data_id: vector<u8>,
        recipient: address,
        access_level: u8,
        expiration: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        let data_access = DataAccessRight {
            id: object::new(ctx),
            data_id: string::utf8(data_id),
            owner: recipient,
            access_level,
            expiration
        };
        
        // Transfer to recipient
        transfer::transfer(data_access, recipient);
        
        event::emit(DataAccessRightCreated {
            data_id: string::utf8(data_id),
            owner: recipient,
            access_level
        });
    }

    // Verify data access right
    public fun verify_data_access(
        access_right: &DataAccessRight,
        required_level: u8,
        ctx: &TxContext
    ): bool {
        let now = tx_context::epoch(ctx);
        
        // Verify ownership
        let is_owner = access_right.owner == tx_context::sender(ctx);
        // Verify not expired
        let not_expired = now <= access_right.expiration;
        // Verify sufficient access level
        let sufficient_access = access_right.access_level >= required_level;
        
        is_owner && not_expired && sufficient_access
    }
}