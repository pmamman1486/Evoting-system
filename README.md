
# Decentralized Voting System Project

This project implements a Decentralized Voting System using **Clarinet** and **Clarity**. Participants stake tokens to vote on community proposals. The system includes mechanisms for proposal creation, submission deadlines, token-based voting, and rewards/refunds for participants. Real-world applications for this project include DAO governance, community funding decisions, or university elections.

## Key Features
- **Proposal Creation**: Participants can submit proposals.
- **Submission Deadlines**: Deadlines are enforced for proposal submission and voting.
- **Token-Staked Voting**: Votes are tied to token stakes to reflect the participant’s commitment.
- **Rewards and Refunds**: Participants receive rewards or refunds after voting.
- **Governance Rules**: Prevents tampering and ensures transparency.

## Technology Stack
- **Language**: Clarity
- **Framework**: Clarinet
- **Testing Framework**: Vitest with TypeScript

## Setup and Installation
1. Install **Clarinet** from [Clarinet Documentation](https://clarinet.io/).
2. Clone this repository:
   ```bash
   git clone <repository-url>
   cd decentralized-voting-system
   ```
3. Install dependencies:
   ```bash
   npm install
   ```

## Usage
1. **Compile the Clarity Contracts**:
   ```bash
   clarinet check
   ```
2. **Deploy the Contract**:
   ```bash
   clarinet deploy
   ```
3. **Run Tests**:
   ```bash
   npm test
   ```

## Project Files
- **`savings-pool.clar`**: Handles token-locking mechanisms for timed access.
- **`event-tickets.clar`**: Manages NFT-based event ticketing, subscription services, and auctions.
- **Tests**: Test cases for the contracts are written in **Vitest** with TypeScript.

## Testing Strategy
The tests use the following structure:
```javascript
import { describe, it, beforeEach, expect } from 'vitest';
```

### **Proposal Contract Test Coverage**

1. **Proposal Creation**
   - ✅ Valid Proposal Creation: Ensures proposals with valid deadlines are created.
   - ✅ Invalid Deadline Handling: Throws an error when deadlines are too early.

2. **Voting Logic**
   - ✅ Voting on Active Proposals: Users can vote on open proposals.
   - ✅ Duplicate Vote Handling: Prevents a user from voting more than once on the same proposal.
   - ✅ Voting Closure: Throws an error when voting on closed proposals.

3. **Proposal Finalization**
   - ✅ Valid Proposal Finalization: Proposals are finalized correctly based on votes.
   - ✅ Prevent Early Finalization: Throws an error if the proposal is not yet closed.

4. **Rewards Management**
   - ✅ Reward Claim: Users can claim rewards proportional to their stake.
   - ✅ Block Unfinalized Proposal Reward Claims: Prevents rewards from being claimed before the proposal is finalized.

### **VotingToken Contract Test Coverage**

1. **Token Metadata Retrieval**
   - ✅ Name, Symbol, and Decimals Retrieval: Ensures token metadata (name, symbol, decimals) is returned correctly.

2. **Token Minting**
   - ✅ Mint Tokens: Allows authorized accounts to mint new tokens.
   - ✅ Unauthorized Mint Prevention: Prevents unauthorized accounts from minting tokens.
   - ✅ Balance and Total Supply Update on Mint: Verifies correct updates to balances and total supply.

3. **Token Burning**
   - ✅ Burn Tokens: Users can burn tokens to reduce supply.
   - ✅ Prevent Burning More Than Balance: Throws an error if the burn amount exceeds the balance.

4. **Token Staking and Unstaking**
   - ✅ Stake Tokens: Users can stake tokens, reducing available balance.
   - ✅ Prevent Staking Without Balance: Ensures users can’t stake more than they own.
   - ✅ Unstake Tokens: Users can unstake previously staked tokens.
   - ✅ Prevent Unstaking Beyond Stake: Throws an error if unstake amount exceeds staked balance.

5. **Token Ownership Management**
   - ✅ Change Owner: Allows changing the token owner.
   - ✅ Unauthorized Change Prevention: Throws an error if a non-owner attempts to change ownership.

6. **Token URI Management**
   - ✅ Token URI Retrieval: Ensures the token URI is correctly retrieved (assumed null initially).

### **Overall Test Coverage Analysis**

- **Proposal Contract:**  
  Covers core functionalities like creation, voting, finalization, and reward management. Some edge cases could be added for better robustness.

- **VotingToken Contract:**  
  Thorough testing of token logic, including minting, burning, staking, and ownership management. Edge cases for invalid amounts and partial staking could enhance coverage.

## How to Contribute
We encourage collaborative contributions. Please follow these guidelines:
1. Fork the repository and create a new branch for your feature.
2. Ensure your code follows our coding style and syntax.
3. Submit a pull request for review.

## Real-World Applications
- DAO Governance
- Community Funding Decisions
- University Elections

## License
This project is licensed under the MIT License..

