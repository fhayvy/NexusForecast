# Nexus Forecast

Nexus Forecast is a decentralized prediction market platform focused on policy outcomes. It allows users to create markets, place bets, and gain insights into potential policy impacts through crowd wisdom, with robust validation and safety measures to ensure fair and secure operation.

## Features

### Core Functionality
- Create prediction markets for various policy outcomes
- Place bets on market outcomes
- Resolve markets based on real-world results
- Claim winnings for successful predictions
- Refund mechanism for expired markets
- Market cleanup functionality

### Safety & Validation Features
- Strict input validation for all operations
- Time-based constraints for market creation and resolution
- Bet amount limits to prevent excessive exposure
- User bet limits to encourage distributed participation
- Expiry mechanisms to ensure market resolution
- Automated refund system for expired markets

## Smart Contract Functions

### Market Management
1. `create-market`: Create a new prediction market
   - Requires valid description (min 10 characters)
   - Close block must be between 1 day and 1 year from creation
   - Expiry must be set within reasonable bounds

2. `place-bet`: Place a bet on a specific market outcome
   - Enforces minimum and maximum bet amounts
   - Tracks per-user bet limits
   - Prevents betting on closed or resolved markets

3. `resolve-market`: Resolve a market with the actual outcome
   - Can only be done after close block
   - Must be done before expiry
   - Requires at least one bet placed

4. `claim-winnings`: Claim winnings for successful bets
   - Validates winning condition
   - Automatically updates user bet counts
   - Prevents double-claiming

### Safety Features
5. `refund-expired-bet`: Get refund for bets on expired markets
   - Available after market expiry
   - Only for unresolved markets
   - Automatic bet count adjustment

6. `cleanup-expired-market`: Remove expired market data
   - Only callable by market creator
   - Requires market to be expired
   - Helps maintain contract efficiency

### Configuration Management
7. Configuration setters (owner only):
   - `set-expiry-period`: Set market expiry period
   - `set-min-bet-amount`: Set minimum bet amount
   - `set-max-bet-amount`: Set maximum bet amount
   - `transfer-ownership`: Transfer contract ownership

### Getter Functions
8. Read-only functions:
   - `get-expiry-period`: Get current expiry period
   - `get-min-bet-amount`: Get minimum bet amount
   - `get-max-bet-amount`: Get maximum bet amount
   - `get-contract-owner`: Get current contract owner

## Technical Specifications

### Constants
- Minimum description length: 10 characters
- Maximum close block delay: ~1 year (52,560 blocks)
- Minimum close block delay: ~1 day (144 blocks)
- Maximum expiry delay: ~2 years (105,120 blocks)
- Maximum bets per user: 10
- Minimum blocks to expiry: ~5 days (720 blocks)

### Error Codes
- ERR-INVALID-CLOSE-BLOCK (u1): Invalid market close block
- ERR-MARKET-CLOSED (u2): Market is closed
- ERR-MARKET-ALREADY-RESOLVED (u3): Market already resolved
- ERR-INVALID-BET (u4): Invalid bet parameters
- ERR-MARKET-NOT-FOUND (u5): Market not found
- ERR-INSUFFICIENT-FUNDS (u6): Insufficient funds
- And more... (see contract for complete list)

## Getting Started

1. Deploy the smart contract to a Stacks-compatible blockchain:
```bash
clarinet contract publish nexus-forecast
```

2. Initialize contract configuration (as contract owner):
```clarity
;; Set minimum bet amount
(contract-call? .nexus-forecast set-min-bet-amount u10)

;; Set maximum bet amount
(contract-call? .nexus-forecast set-max-bet-amount u1000000)

;; Set expiry period
(contract-call? .nexus-forecast set-expiry-period u10000)
```

3. Create and interact with markets:
```clarity
;; Create a new market
(contract-call? .nexus-forecast create-market 
    "Will policy X be implemented by 2025?" 
    u100000)

;; Place a bet
(contract-call? .nexus-forecast place-bet u1 true u1000)

;; Resolve the market
(contract-call? .nexus-forecast resolve-market u1 true)

;; Claim winnings
(contract-call? .nexus-forecast claim-winnings u1)
```

## Security Considerations

- All functions include comprehensive input validation
- Time-based operations use block height for consistency
- Bet limits prevent excessive exposure
- User bet limits prevent market manipulation
- Automatic refund mechanism protects user funds
- Owner-only functions for sensitive operations

## Best Practices for Users

1. Verify market parameters before betting
2. Keep track of market expiry dates
3. Claim winnings before market expiry
4. Request refunds for expired markets
5. Stay within bet limits for better risk management

## Contributing

We welcome contributions to Nexus Forecast! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

### Development Guidelines

- Add comprehensive tests for new features
- Maintain or improve existing validation measures
- Document all new functions and parameters
- Follow existing code style and conventions

## Author

Favour Chiamaka Eze

## Support

For support or inquiries, please open an issue on our GitHub repository.