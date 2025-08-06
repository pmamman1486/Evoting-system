# Reputation Governance System Usage Example

## Overview
The Reputation Governance System tracks voter performance and adjusts their influence based on decision-making track record.

## Step-by-Step Usage

### 1. Initialize Reputation
```clarity
;; New voters start with base reputation of 100
(contract-call? .ReputationGovernance initialize-reputation)
;; Returns: (ok true)
```

### 2. Record Voting Activity
```clarity
;; When a user votes on proposal #1 with weight 50
(contract-call? .ReputationGovernance record-vote-cast alice-principal u1 u50)
;; Tracks participation and updates activity streak
```

### 3. Record Proposal Creation
```clarity
;; When alice creates proposal #2
(contract-call? .ReputationGovernance record-proposal-creation alice-principal u2)
;; Increases proposal creation count
```

### 4. Finalize Proposal Outcomes
```clarity
;; After proposal #1 passes
(contract-call? .ReputationGovernance finalize-proposal-reputation u1 "passed")
;; Records final outcome for reputation calculation
```

### 5. Apply Reputation Updates
```clarity
;; Give reputation points for correct voting
(contract-call? .ReputationGovernance apply-reputation-for-vote alice-principal u1)
;; +10 points if voted for winning side

;; Reward proposal creators for success
(contract-call? .ReputationGovernance apply-creator-reputation alice-principal u2)
;; +25 points for successful proposals, -5 for failures
```

### 6. Get Reputation-Adjusted Voting Weight
```clarity
;; Calculate adjusted voting power based on reputation
(contract-call? .ReputationGovernance get-adjusted-voting-weight alice-principal u100)
;; Returns enhanced weight (50-150% of base) based on reputation score
```

### 7. Reputation-Based Delegation
```clarity
;; Delegate to high-reputation voter (minimum 300 reputation required)
(contract-call? .ReputationGovernance delegate-to-reputable-voter 
  bob-principal u300 u1440) ;; 24 hours duration
;; Only works if delegate maintains required reputation
```

### 8. Check Reputation Metrics
```clarity
;; Get current reputation score
(contract-call? .ReputationGovernance get-reputation-score alice-principal)

;; Check voting accuracy percentage
(contract-call? .ReputationGovernance get-voting-accuracy alice-principal)

;; Check proposal success rate
(contract-call? .ReputationGovernance get-proposal-success-rate alice-principal)
```

### 9. Update Reputation Tier
```clarity
;; Update tier based on current score
(contract-call? .ReputationGovernance update-reputation-tier alice-principal)
;; Assigns: base (0-199), bronze (200-399), silver (400-599), gold (600-799), platinum (800+)
```

### 10. Apply Time-Based Decay
```clarity
;; Reduce reputation over time for inactive users
(contract-call? .ReputationGovernance apply-reputation-decay alice-principal)
;; -2 points per day of inactivity
```

## Reputation Scoring System

### Points Earned:
- **Correct Vote**: +10 points
- **Successful Proposal**: +25 points
- **Participation Bonus**: +5 points (for consistent activity)

### Points Lost:
- **Failed Proposal**: -5 points
- **Time Decay**: -2 points per day of inactivity

### Voting Weight Adjustment:
- **Base Reputation (100)**: 100% voting weight
- **High Reputation (500)**: 150% voting weight  
- **Low Reputation (50)**: 55% voting weight

### Reputation Tiers:
- **Platinum (800+)**: Premium governance features
- **Gold (600-799)**: Advanced delegation options
- **Silver (400-599)**: Standard governance rights
- **Bronze (200-399)**: Basic participation
- **Base (0-199)**: Limited influence
