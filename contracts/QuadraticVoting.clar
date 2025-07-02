(define-constant ERR_PROPOSAL_NOT_FOUND (err u200))
(define-constant ERR_INSUFFICIENT_CREDITS (err u201))
(define-constant ERR_VOTING_ENDED (err u202))
(define-constant ERR_INVALID_VOTE_COUNT (err u203))
(define-constant ERR_ALREADY_ALLOCATED (err u204))
(define-constant ERR_UNAUTHORIZED (err u205))

(define-map quadratic-proposals uint
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    end-block: uint,
    total-votes: uint,
    active: bool
  })

(define-map voter-credits
  { voter: principal, proposal-id: uint }
  { total-credits: uint, used-credits: uint })

(define-map vote-allocations
  { voter: principal, proposal-id: uint, option-id: uint }
  { votes: uint, credits-spent: uint })

(define-map proposal-options
  { proposal-id: uint, option-id: uint }
  { description: (string-utf8 200), vote-count: uint })

(define-map proposal-option-count
  { proposal-id: uint }
  { count: uint })

(define-data-var next-proposal-id uint u1)

(define-public (create-quadratic-proposal 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (duration uint)
    (options (list 10 (string-utf8 200))))
  (let (
    (proposal-id (var-get next-proposal-id))
    (end-block (+ stacks-block-height duration))
  )
    (map-set quadratic-proposals proposal-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        end-block: end-block,
        total-votes: u0,
        active: true
      })
    
    (fold setup-option options { proposal-id: proposal-id, option-id: u0 })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))

(define-private (setup-option 
    (option-desc (string-utf8 200)) 
    (context { proposal-id: uint, option-id: uint }))
  (let ((option-id (get option-id context)))
    (map-set proposal-options
      { proposal-id: (get proposal-id context), option-id: option-id }
      { description: option-desc, vote-count: u0 })
    { proposal-id: (get proposal-id context), option-id: (+ option-id u1) }))

(define-public (allocate-voting-credits (proposal-id uint) (credits uint))
  (let (
    (proposal (unwrap! (map-get? quadratic-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (staked-balance (unwrap! (contract-call? .VotingToken get-staked-balance tx-sender) ERR_INSUFFICIENT_CREDITS))
    (existing-allocation (map-get? voter-credits { voter: tx-sender, proposal-id: proposal-id }))
  )
    (asserts! (get active proposal) ERR_VOTING_ENDED)
    (asserts! (< stacks-block-height (get end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (>= staked-balance credits) ERR_INSUFFICIENT_CREDITS)
    (asserts! (is-none existing-allocation) ERR_ALREADY_ALLOCATED)
    
    (map-set voter-credits
      { voter: tx-sender, proposal-id: proposal-id }
      { total-credits: credits, used-credits: u0 })
    (ok credits)))

(define-public (cast-quadratic-vote 
    (proposal-id uint) 
    (option-id uint) 
    (vote-count uint))
  (let (
    (proposal (unwrap! (map-get? quadratic-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (credits (unwrap! (map-get? voter-credits { voter: tx-sender, proposal-id: proposal-id }) ERR_INSUFFICIENT_CREDITS))
    (option (unwrap! (map-get? proposal-options { proposal-id: proposal-id, option-id: option-id }) ERR_PROPOSAL_NOT_FOUND))
    (credits-needed (* vote-count vote-count))
    (remaining-credits (- (get total-credits credits) (get used-credits credits)))
  )
    (asserts! (get active proposal) ERR_VOTING_ENDED)
    (asserts! (< stacks-block-height (get end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (> vote-count u0) ERR_INVALID_VOTE_COUNT)
    (asserts! (>= remaining-credits credits-needed) ERR_INSUFFICIENT_CREDITS)
    
    (map-set vote-allocations
      { voter: tx-sender, proposal-id: proposal-id, option-id: option-id }
      { votes: vote-count, credits-spent: credits-needed })
    
    (map-set voter-credits
      { voter: tx-sender, proposal-id: proposal-id }
      (merge credits { used-credits: (+ (get used-credits credits) credits-needed) }))
    
    (map-set proposal-options
      { proposal-id: proposal-id, option-id: option-id }
      (merge option { vote-count: (+ (get vote-count option) vote-count) }))
    
    (map-set quadratic-proposals proposal-id
      (merge proposal { total-votes: (+ (get total-votes proposal) vote-count) }))
    
    (ok vote-count)))

(define-public (finalize-quadratic-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? quadratic-proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_UNAUTHORIZED)
    (asserts! (> stacks-block-height (get end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (get active proposal) ERR_VOTING_ENDED)
    
    (map-set quadratic-proposals proposal-id
      (merge proposal { active: false }))
    (ok true)))

(define-read-only (get-quadratic-proposal (proposal-id uint))
  (map-get? quadratic-proposals proposal-id))

(define-read-only (get-voter-credits (voter principal) (proposal-id uint))
  (map-get? voter-credits { voter: voter, proposal-id: proposal-id }))

(define-read-only (get-vote-allocation (voter principal) (proposal-id uint) (option-id uint))
  (map-get? vote-allocations { voter: voter, proposal-id: proposal-id, option-id: option-id }))

(define-read-only (get-proposal-option (proposal-id uint) (option-id uint))
  (map-get? proposal-options { proposal-id: proposal-id, option-id: option-id }))

(define-read-only (calculate-quadratic-cost (votes uint))
  (* votes votes))

(define-read-only (get-winning-option (proposal-id uint))
  (let ((proposal (map-get? quadratic-proposals proposal-id)))
    (if (is-none proposal)
      none
      (some (fold find-max-option (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) 
        { proposal-id: proposal-id, max-option: u0, max-votes: u0 })))))

(define-private (find-max-option 
    (option-id uint) 
    (context { proposal-id: uint, max-option: uint, max-votes: uint }))
  (let (
    (option (map-get? proposal-options { proposal-id: (get proposal-id context), option-id: option-id }))
  )
    (if (is-some option)
      (let ((vote-count (get vote-count (unwrap-panic option))))
        (if (> vote-count (get max-votes context))
          { proposal-id: (get proposal-id context), max-option: option-id, max-votes: vote-count }
          context))
      context)))

(define-read-only (get-remaining-credits (voter principal) (proposal-id uint))
  (let ((credits (map-get? voter-credits { voter: voter, proposal-id: proposal-id })))
    (if (is-none credits)
      u0
      (let ((credit-data (unwrap-panic credits)))
        (- (get total-credits credit-data) (get used-credits credit-data))))))
