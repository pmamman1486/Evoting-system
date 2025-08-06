;; Reputation-Based Governance System
;; Tracks voter performance and adjusts voting influence based on track record

;; Error constants
(define-constant ERR_NOT_FOUND (err u300))
(define-constant ERR_UNAUTHORIZED (err u301))
(define-constant ERR_INVALID_SCORE (err u302))
(define-constant ERR_ALREADY_RECORDED (err u303))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u304))
(define-constant ERR_DECAY_TOO_RECENT (err u305))

;; Constants for reputation calculation
(define-constant CORRECT_VOTE_POINTS u10)
(define-constant PROPOSAL_SUCCESS_POINTS u25)
(define-constant PROPOSAL_FAILURE_PENALTY u5)
(define-constant MIN_REPUTATION_THRESHOLD u50)
(define-constant DECAY_RATE u2) ;; Points lost per decay period
(define-constant DECAY_PERIOD u1440) ;; Blocks between decay (roughly 24 hours)
(define-constant MAX_REPUTATION u1000)
(define-constant PARTICIPATION_BONUS u5)

;; Voter reputation tracking
(define-map voter-reputation principal
  {
    score: uint,
    votes-cast: uint,
    correct-votes: uint,
    proposals-created: uint,
    successful-proposals: uint,
    last-activity: uint,
    last-decay: uint,
    participation-streak: uint
  })

;; Proposal outcome tracking for reputation calculation
(define-map proposal-outcomes uint
  {
    final-status: (string-ascii 20),
    recorded-at: uint,
    reputation-distributed: bool
  })

;; Track which voters voted for which outcome on each proposal
(define-map voter-proposal-positions
  { voter: principal, proposal-id: uint }
  { voted-for-winner: bool, weight-used: uint })

;; Reputation-weighted delegation system
(define-map reputation-delegates
  { delegator: principal }
  { 
    delegate: principal,
    min-reputation-required: uint,
    expires-at: uint
  })

;; High-reputation voter registry for premium features
(define-map reputation-tiers principal
  {
    tier: (string-ascii 20),
    tier-since: uint,
    benefits-claimed: uint
  })

;; Initialize voter reputation with base score
(define-public (initialize-reputation)
  (let ((existing (map-get? voter-reputation tx-sender)))
    (if (is-some existing)
      (ok false) ;; Already initialized
      (begin
        (map-set voter-reputation tx-sender
          {
            score: u100, ;; Starting reputation
            votes-cast: u0,
            correct-votes: u0,
            proposals-created: u0,
            successful-proposals: u0,
            last-activity: stacks-block-height,
            last-decay: stacks-block-height,
            participation-streak: u0
          })
        (ok true)))))

;; Record a vote being cast (called by ProposalManager)
(define-public (record-vote-cast (voter principal) (proposal-id uint) (vote-weight uint))
  (let (
    (reputation (default-to 
      { score: u100, votes-cast: u0, correct-votes: u0, proposals-created: u0, 
        successful-proposals: u0, last-activity: u0, last-decay: stacks-block-height, participation-streak: u0 }
      (map-get? voter-reputation voter)))
  )
    ;; Update voting activity
    (map-set voter-reputation voter
      (merge reputation {
        votes-cast: (+ (get votes-cast reputation) u1),
        last-activity: stacks-block-height,
        participation-streak: (+ (get participation-streak reputation) u1)
      }))
    
    ;; Store the vote position for later reputation calculation
    (map-set voter-proposal-positions
      { voter: voter, proposal-id: proposal-id }
      { voted-for-winner: false, weight-used: vote-weight })
    
    (ok true)))

;; Record proposal creation (called when proposals are made)
(define-public (record-proposal-creation (creator principal) (proposal-id uint))
  (let (
    (reputation (default-to 
      { score: u100, votes-cast: u0, correct-votes: u0, proposals-created: u0, 
        successful-proposals: u0, last-activity: u0, last-decay: stacks-block-height, participation-streak: u0 }
      (map-get? voter-reputation creator)))
  )
    (map-set voter-reputation creator
      (merge reputation {
        proposals-created: (+ (get proposals-created reputation) u1),
        last-activity: stacks-block-height
      }))
    (ok true)))

;; Record final proposal outcome and distribute reputation
(define-public (finalize-proposal-reputation (proposal-id uint) (final-status (string-ascii 20)))
  (let (
    (outcome-check (map-get? proposal-outcomes proposal-id))
  )
    ;; Ensure proposal outcome hasn't been recorded yet
    (asserts! (is-none outcome-check) ERR_ALREADY_RECORDED)
    
    ;; Record the final outcome
    (map-set proposal-outcomes proposal-id
      {
        final-status: final-status,
        recorded-at: stacks-block-height,
        reputation-distributed: false
      })
    
    (ok true)))

;; Calculate and apply reputation changes for a specific voter on a proposal
(define-public (apply-reputation-for-vote (voter principal) (proposal-id uint))
  (let (
    (proposal-outcome (unwrap! (map-get? proposal-outcomes proposal-id) ERR_NOT_FOUND))
    (vote-position (unwrap! (map-get? voter-proposal-positions { voter: voter, proposal-id: proposal-id }) ERR_NOT_FOUND))
    (voter-rep (unwrap! (map-get? voter-reputation voter) ERR_NOT_FOUND))
    (proposal-data (unwrap! (contract-call? .ProposalManager get-proposal proposal-id) ERR_NOT_FOUND))
    (vote-data (unwrap! (contract-call? .ProposalManager get-vote proposal-id voter) ERR_NOT_FOUND))
  )
    ;; Check if voter voted for the winning side
    (let (
      (voted-correctly (is-eq 
        (is-eq (get final-status proposal-outcome) "passed")
        (get vote vote-data)))
      (new-score (if voted-correctly
        (+ (get score voter-rep) CORRECT_VOTE_POINTS)
        (get score voter-rep))) ;; No penalty for incorrect votes, just no bonus
    )
      ;; Update voter reputation
      (map-set voter-reputation voter
        (merge voter-rep {
          score: (if (> new-score MAX_REPUTATION) MAX_REPUTATION new-score),
          correct-votes: (if voted-correctly (+ (get correct-votes voter-rep) u1) (get correct-votes voter-rep))
        }))
      
      ;; Update the vote position record
      (map-set voter-proposal-positions
        { voter: voter, proposal-id: proposal-id }
        (merge vote-position { voted-for-winner: voted-correctly }))
      
      (ok voted-correctly))))

;; Apply reputation bonus/penalty for proposal creators
(define-public (apply-creator-reputation (creator principal) (proposal-id uint))
  (let (
    (proposal-outcome (unwrap! (map-get? proposal-outcomes proposal-id) ERR_NOT_FOUND))
    (creator-rep (unwrap! (map-get? voter-reputation creator) ERR_NOT_FOUND))
  )
    (let (
      (proposal-passed (is-eq (get final-status proposal-outcome) "passed"))
      (new-score (if proposal-passed
        (+ (get score creator-rep) PROPOSAL_SUCCESS_POINTS)
        (if (> (get score creator-rep) PROPOSAL_FAILURE_PENALTY)
          (- (get score creator-rep) PROPOSAL_FAILURE_PENALTY)
          u0)))
    )
      (map-set voter-reputation creator
        (merge creator-rep {
          score: (if (> new-score MAX_REPUTATION) MAX_REPUTATION new-score),
          successful-proposals: (if proposal-passed 
            (+ (get successful-proposals creator-rep) u1) 
            (get successful-proposals creator-rep))
        }))
      (ok proposal-passed))))

;; Apply time-based reputation decay
(define-public (apply-reputation-decay (voter principal))
  (let (
    (reputation (unwrap! (map-get? voter-reputation voter) ERR_NOT_FOUND))
    (blocks-since-decay (- stacks-block-height (get last-decay reputation)))
  )
    ;; Only apply decay if enough time has passed
    (asserts! (>= blocks-since-decay DECAY_PERIOD) ERR_DECAY_TOO_RECENT)
    
    (let (
      (decay-periods (/ blocks-since-decay DECAY_PERIOD))
      (total-decay (* decay-periods DECAY_RATE))
      (new-score (if (> (get score reputation) total-decay)
        (- (get score reputation) total-decay)
        u0))
    )
      (map-set voter-reputation voter
        (merge reputation {
          score: new-score,
          last-decay: stacks-block-height,
          participation-streak: (if (> blocks-since-decay (* DECAY_PERIOD u3)) u0 (get participation-streak reputation))
        }))
      (ok new-score))))

;; Get reputation-adjusted voting weight
(define-read-only (get-adjusted-voting-weight (voter principal) (base-weight uint))
  (let (
    (reputation (default-to 
      { score: u100, votes-cast: u0, correct-votes: u0, proposals-created: u0, 
        successful-proposals: u0, last-activity: u0, last-decay: u0, participation-streak: u0 }
      (map-get? voter-reputation voter)))
  )
    ;; Apply reputation multiplier: 50-150% of base weight based on reputation
    (let ((multiplier (+ u50 (/ (get score reputation) u10))))
      (/ (* base-weight multiplier) u100))))

;; Set up reputation-based delegation
(define-public (delegate-to-reputable-voter 
    (delegate principal) 
    (min-reputation uint) 
    (duration uint))
  (let (
    (delegate-rep (map-get? voter-reputation delegate))
  )
    ;; Ensure delegate meets reputation requirement
    (asserts! (is-some delegate-rep) ERR_NOT_FOUND)
    (asserts! (>= (get score (unwrap-panic delegate-rep)) min-reputation) ERR_INSUFFICIENT_REPUTATION)
    
    (map-set reputation-delegates
      { delegator: tx-sender }
      {
        delegate: delegate,
        min-reputation-required: min-reputation,
        expires-at: (+ stacks-block-height duration)
      })
    (ok true)))

;; Update reputation tier based on current score
(define-public (update-reputation-tier (voter principal))
  (let (
    (reputation (unwrap! (map-get? voter-reputation voter) ERR_NOT_FOUND))
    (current-tier (map-get? reputation-tiers voter))
  )
    (let (
      (new-tier (if (>= (get score reputation) u800)
        "platinum"
        (if (>= (get score reputation) u600)
          "gold"
          (if (>= (get score reputation) u400)
            "silver"
            (if (>= (get score reputation) u200)
              "bronze"
              "base")))))
    )
      (map-set reputation-tiers voter
        {
          tier: new-tier,
          tier-since: stacks-block-height,
          benefits-claimed: (if (is-some current-tier) (get benefits-claimed (unwrap-panic current-tier)) u0)
        })
      (ok new-tier))))

;; Check if delegation is still valid (delegate maintains required reputation)
(define-read-only (is-delegation-valid (delegator principal))
  (let (
    (delegation (map-get? reputation-delegates { delegator: delegator }))
  )
    (if (is-none delegation)
      false
      (let (
        (del-info (unwrap-panic delegation))
        (delegate-rep (map-get? voter-reputation (get delegate del-info)))
      )
        (and
          (< stacks-block-height (get expires-at del-info))
          (is-some delegate-rep)
          (>= (get score (unwrap-panic delegate-rep)) (get min-reputation-required del-info)))))))

;; Read-only functions for reputation data
(define-read-only (get-voter-reputation (voter principal))
  (map-get? voter-reputation voter))

(define-read-only (get-reputation-score (voter principal))
  (default-to u100 (get score (map-get? voter-reputation voter))))

(define-read-only (get-voting-accuracy (voter principal))
  (let (
    (reputation (map-get? voter-reputation voter))
  )
    (if (is-none reputation)
      u0
      (let ((rep-data (unwrap-panic reputation)))
        (if (> (get votes-cast rep-data) u0)
          (/ (* (get correct-votes rep-data) u100) (get votes-cast rep-data))
          u0)))))

(define-read-only (get-proposal-success-rate (creator principal))
  (let (
    (reputation (map-get? voter-reputation creator))
  )
    (if (is-none reputation)
      u0
      (let ((rep-data (unwrap-panic reputation)))
        (if (> (get proposals-created rep-data) u0)
          (/ (* (get successful-proposals rep-data) u100) (get proposals-created rep-data))
          u0)))))

(define-read-only (get-reputation-tier-info (voter principal))
  (map-get? reputation-tiers voter))

(define-read-only (is-high-reputation-voter (voter principal))
  (>= (get-reputation-score voter) MIN_REPUTATION_THRESHOLD))


