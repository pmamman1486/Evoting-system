(define-constant ERR_PROPOSAL_NOT_FOUND (err u100))
(define-constant ERR_VOTING_CLOSED (err u101))
(define-constant ERR_ALREADY_VOTED (err u102))
(define-constant ERR_INSUFFICIENT_STAKE (err u103))
(define-constant ERR_INVALID_DEADLINE (err u104))
(define-constant ERR_UNAUTHORIZED (err u105))
(define-constant ERR_PROPOSAL_ACTIVE (err u106))
(define-constant ERR_PROPOSAL_NOT_FINALIZED (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))

(define-map proposals uint 
  {
    creator: principal, 
    description: (string-utf8 500), 
    deadline: uint, 
    total-votes: uint,
    for-votes: uint,
    against-votes: uint,
    status: (string-ascii 20),
    reward-pool: uint
  })

(define-map votes 
  { proposal-id: uint, voter: principal } 
  { weight: uint, vote: bool })

(define-data-var token-owner principal tx-sender)
(define-data-var next-proposal-id uint u1)
(define-data-var min-proposal-duration uint u1440) ;; Minimum 1 day (assuming 1 block per minute)

(define-public (create-proposal (description (string-utf8 500)) (deadline uint) (reward-amount uint))
  (let (
    (proposal-id (var-get next-proposal-id))
    (min-deadline (+ block-height (var-get min-proposal-duration)))
  )
    (asserts! (>= deadline min-deadline) (err ERR_INVALID_DEADLINE))
    (match (contract-call? .VotingToken transfer reward-amount tx-sender (as-contract tx-sender) none)
      success (begin
        (map-set proposals proposal-id 
          {
            creator: tx-sender, 
            description: description, 
            deadline: deadline, 
            total-votes: u0,
            for-votes: u0,
            against-votes: u0,
            status: "active",
            reward-pool: reward-amount
          })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id))
      error (err ERR_TRANSFER_FAILED))))

(define-public (vote-on-proposal (proposal-id uint) (amount uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (staked-balance (unwrap! (contract-call? .VotingToken get-staked-balance tx-sender) ERR_INSUFFICIENT_STAKE))
    (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
  )
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! (<= block-height (get deadline proposal)) ERR_VOTING_CLOSED)
    (asserts! (>= staked-balance amount) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
    
    ;; Record the vote
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } { weight: amount, vote: vote-for })
    
    ;; Update the proposal votes
    (map-set proposals proposal-id 
      (merge proposal { 
        total-votes: (+ (get total-votes proposal) amount),
        for-votes: (if vote-for (+ (get for-votes proposal) amount) (get for-votes proposal)),
        against-votes: (if (not vote-for) (+ (get against-votes proposal) amount) (get against-votes proposal))
      }))
    (ok amount)))

(define-public (finalize-vote (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (> block-height (get deadline proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (map-set proposals proposal-id 
      (merge proposal { 
        status: (if (> (get for-votes proposal) (get against-votes proposal)) "passed" "rejected")
      }))
    (ok (get total-votes proposal))))

(define-public (claim-reward (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (user-vote (unwrap! (map-get? votes { proposal-id: proposal-id, voter: tx-sender }) ERR_UNAUTHORIZED))
  )
    (asserts! (not (is-eq (get status proposal) "active")) ERR_PROPOSAL_NOT_FINALIZED)
    (asserts! (is-eq (get vote user-vote) (is-eq (get status proposal) "passed")) ERR_UNAUTHORIZED)
    (let (
      (reward (/ (* (get weight user-vote) (get reward-pool proposal)) (get total-votes proposal)))
    )
      (match (contract-call? .VotingToken transfer reward (as-contract tx-sender) tx-sender none)
        success (ok reward)
        error (err reward) ;; Make sure the error response matches the type (uint, uint)
      )
    )
  )
)



(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter }))

(define-public (set-min-proposal-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender (var-get token-owner)) ERR_UNAUTHORIZED)
    (var-set min-proposal-duration new-duration)
    (ok true)))

(define-read-only (get-min-proposal-duration)
  (ok (var-get min-proposal-duration)))