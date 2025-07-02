# Quadratic Voting Example

## Step 1: Create a Quadratic Proposal
```clarity
(contract-call? .QuadraticVoting create-quadratic-proposal 
  "Budget Allocation 2024"
  "How should we allocate the DAO treasury?"
  u1440  ;; 24 hours duration
  (list "Development (40%)" "Marketing (30%)" "Operations (20%)" "Reserves (10%)")
)
;; Returns: (ok u1) - proposal ID
```

## Step 2: Allocate Voting Credits
```clarity
;; Alice allocates 100 credits from her staked tokens
(contract-call? .QuadraticVoting allocate-voting-credits u1 u100)
;; Returns: (ok u100)
```

## Step 3: Cast Quadratic Votes
```clarity
;; Alice strongly supports development - 5 votes costs 25 credits
(contract-call? .QuadraticVoting cast-quadratic-vote u1 u0 u5)
;; Returns: (ok u5)

;; Alice moderately supports marketing - 3 votes costs 9 credits  
(contract-call? .QuadraticVoting cast-quadratic-vote u1 u1 u3)
;; Returns: (ok u3)

;; Remaining credits: 100 - 25 - 9 = 66
```

## Step 4: Check Results
```clarity
;; Get proposal details
(contract-call? .QuadraticVoting get-quadratic-proposal u1)

;; Get winning option
(contract-call? .QuadraticVoting get-winning-option u1)

;; Check remaining credits
(contract-call? .QuadraticVoting get-remaining-credits alice-principal u1)
```

## Quadratic Cost Examples
- 1 vote = 1 credit
- 2 votes = 4 credits  
- 3 votes = 9 credits
- 4 votes = 16 credits
- 5 votes = 25 credits
- 10 votes = 100 credits
