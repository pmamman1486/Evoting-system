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

;; (define-public (finalize-votee (proposal-id uint))
;;   (let (
;;     (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
;;   )
;;     (asserts! (> block-height (get deadline proposal)) ERR_PROPOSAL_ACTIVE)
;;     (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
;;     (map-set proposals proposal-id 
;;       (merge proposal { 
;;         status: (if (> (get for-votes proposal) (get against-votes proposal)) "passed" "rejected")
;;       }))
;;     (ok (get total-votes proposal))))

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

  (define-map delegations 
  { delegator: principal } 
  { delegate: principal })

(define-public (delegate-vote (delegate-to principal))
  (begin
    (map-set delegations 
      { delegator: tx-sender }
      { delegate: delegate-to })
    (ok true)))

(define-read-only (get-delegate (delegator principal))
  (map-get? delegations { delegator: delegator }))


(define-constant CATEGORY_GOVERNANCE "governance")
(define-constant CATEGORY_FUNDING "funding")
(define-constant CATEGORY_TECHNICAL "technical")

(define-map proposal-categories 
  { proposal-id: uint } 
  { category: (string-ascii 20) })

(define-public (set-proposal-category (proposal-id uint) (category (string-ascii 20)))
  (begin 
    (map-set proposal-categories 
      { proposal-id: proposal-id }
      { category: category })
    (ok true)))

(define-read-only (get-proposal-category (proposal-id uint))
  (map-get? proposal-categories { proposal-id: proposal-id }))


(define-map locked-proposals 
  { proposal-id: uint } 
  { unlock-height: uint })

(define-constant LOCK_PERIOD u1440) ;; 24 hours in blocks

(define-public (lock-proposal (proposal-id uint))
  (begin
    (map-set locked-proposals 
      { proposal-id: proposal-id }
      { unlock-height: (+ block-height LOCK_PERIOD) })
    (ok true)))

(define-read-only (is-proposal-unlocked (proposal-id uint))
  (let ((lock-info (map-get? locked-proposals { proposal-id: proposal-id })))
    (if (is-none lock-info)
      true
      (> block-height (get unlock-height (unwrap-panic lock-info))))))


(define-map user-reputation 
  { user: principal } 
  { score: uint })

(define-public (add-reputation (user principal) (points uint))
  (let ((current-score (default-to u0 (get score (map-get? user-reputation { user: user })))))
    (map-set user-reputation 
      { user: user }
      { score: (+ current-score points) })
    (ok true)))

(define-read-only (get-user-reputation (user principal))
  (default-to u0 (get score (map-get? user-reputation { user: user }))))


;; Add constant
(define-constant MINIMUM_QUORUM_PERCENTAGE u10) ;; 10% of total staked tokens

;; Modify finalize-vote function
(define-public (finalize-vote (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (total-staked (unwrap! (contract-call? .VotingToken get-staked-balance tx-sender) (err u0)))
    (quorum-met (>= (* (get total-votes proposal) u100) (* total-staked MINIMUM_QUORUM_PERCENTAGE)))
  )
    (asserts! (> block-height (get deadline proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (asserts! quorum-met (err u4))
    (map-set proposals proposal-id 
      (merge proposal { 
        status: (if (> (get for-votes proposal) (get against-votes proposal)) "passed" "rejected")
      }))
    (ok (get total-votes proposal))))


;; Add map
(define-map proposal-tags 
  { proposal-id: uint }
  { tags: (list 5 (string-ascii 20)) })

;; Add function
(define-public (add-proposal-tags (proposal-id uint) (tags (list 5 (string-ascii 20))))
  (begin
    (asserts! (is-some (map-get? proposals proposal-id)) ERR_PROPOSAL_NOT_FOUND)
    (map-set proposal-tags { proposal-id: proposal-id } { tags: tags })
    (ok true)))


;; Add function
(define-read-only (calculate-vote-weight (base-amount uint) (lock-duration uint))
  (let ((multiplier (+ u100 (/ lock-duration u100))))  ;; 1% bonus per day locked
    (/ (* base-amount multiplier) u100)))


(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get token-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "active") ERR_VOTING_CLOSED)
    (map-set proposals proposal-id 
      (merge proposal { status: "cancelled" }))
    (ok true)))


(define-map proposal-comments 
  { proposal-id: uint, commenter: principal } 
  { comment: (string-utf8 200) })

(define-public (add-comment (proposal-id uint) (comment (string-utf8 200)))
  (begin
    (map-set proposal-comments 
      { proposal-id: proposal-id, commenter: tx-sender }
      { comment: comment })
    (ok true)))


(define-map delegation-history
  { delegator: principal }
  { history: (list 10 principal) })

  (define-constant ERR_LIST_FULL (err u109))



(define-public (track-delegation (delegate-to principal))
  (let ((current-history (default-to (list) (get history (map-get? delegation-history { delegator: tx-sender })))))
    (map-set delegation-history
      { delegator: tx-sender }
      { history: (unwrap! (as-max-len? (append current-history delegate-to) u10) ERR_LIST_FULL) })
    (ok true)))


(define-map proposal-milestones 
  { proposal-id: uint }
  { milestones: (list 5 (string-utf8 100)) })

(define-public (add-milestone (proposal-id uint) (milestone (string-utf8 100)))
  (let ((current-milestones (default-to (list) (get milestones (map-get? proposal-milestones { proposal-id: proposal-id })))))
    (map-set proposal-milestones
      { proposal-id: proposal-id }
      { milestones: (unwrap! (as-max-len? (append current-milestones milestone) u5) ERR_LIST_FULL) })
    (ok true)))

