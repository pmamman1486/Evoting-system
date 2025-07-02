(define-constant ERR_BOUNTY_NOT_FOUND (err u200))
(define-constant ERR_BOUNTY_EXPIRED (err u201))
(define-constant ERR_BOUNTY_CLAIMED (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))
(define-constant ERR_BOUNTY_ACTIVE (err u204))
(define-constant ERR_NOT_BOUNTY_CREATOR (err u205))
(define-constant ERR_PROPOSAL_NOT_ELIGIBLE (err u206))

(define-map bounties uint
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    total-pool: uint,
    expiry-block: uint,
    claimed: bool,
    winning-proposal: (optional uint)
  })

(define-map bounty-contributions
  { bounty-id: uint, contributor: principal }
  { amount: uint })

(define-map bounty-proposals
  { bounty-id: uint, proposal-id: uint }
  { submitted-by: principal, submission-block: uint })

(define-data-var next-bounty-id uint u1)

(define-public (create-bounty 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (initial-amount uint)
    (duration uint))
  (let (
    (bounty-id (var-get next-bounty-id))
    (expiry (+ stacks-block-height duration))
  )
    (try! (contract-call? .VotingToken transfer initial-amount tx-sender (as-contract tx-sender) none))
    
    (map-set bounties bounty-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        total-pool: initial-amount,
        expiry-block: expiry,
        claimed: false,
        winning-proposal: none
      })
    
    (map-set bounty-contributions
      { bounty-id: bounty-id, contributor: tx-sender }
      { amount: initial-amount })
    
    (var-set next-bounty-id (+ bounty-id u1))
    (ok bounty-id)))

(define-public (contribute-to-bounty (bounty-id uint) (amount uint))
  (let (
    (bounty (unwrap! (map-get? bounties bounty-id) ERR_BOUNTY_NOT_FOUND))
    (existing-contribution (default-to { amount: u0 } 
      (map-get? bounty-contributions { bounty-id: bounty-id, contributor: tx-sender })))
  )
    (asserts! (< stacks-block-height (get expiry-block bounty)) ERR_BOUNTY_EXPIRED)
    (asserts! (not (get claimed bounty)) ERR_BOUNTY_CLAIMED)
    
    (try! (contract-call? .VotingToken transfer amount tx-sender (as-contract tx-sender) none))
    
    (map-set bounties bounty-id
      (merge bounty { total-pool: (+ (get total-pool bounty) amount) }))
    
    (map-set bounty-contributions
      { bounty-id: bounty-id, contributor: tx-sender }
      { amount: (+ (get amount existing-contribution) amount) })
    
    (ok (+ (get total-pool bounty) amount))))

(define-public (submit-proposal-for-bounty (bounty-id uint) (proposal-id uint))
  (let (
    (bounty (unwrap! (map-get? bounties bounty-id) ERR_BOUNTY_NOT_FOUND))
    (proposal (unwrap! (contract-call? .ProposalManager get-proposal proposal-id) ERR_PROPOSAL_NOT_ELIGIBLE))
  )
    (asserts! (< stacks-block-height (get expiry-block bounty)) ERR_BOUNTY_EXPIRED)
    (asserts! (not (get claimed bounty)) ERR_BOUNTY_CLAIMED)
    (asserts! (is-eq (get creator proposal) tx-sender) ERR_PROPOSAL_NOT_ELIGIBLE)
    
    (map-set bounty-proposals
      { bounty-id: bounty-id, proposal-id: proposal-id }
      { submitted-by: tx-sender, submission-block: stacks-block-height })
    
    (ok true)))

(define-public (award-bounty (bounty-id uint) (winning-proposal-id uint))
  (let (
    (bounty (unwrap! (map-get? bounties bounty-id) ERR_BOUNTY_NOT_FOUND))
    (submission (unwrap! (map-get? bounty-proposals { bounty-id: bounty-id, proposal-id: winning-proposal-id }) ERR_PROPOSAL_NOT_ELIGIBLE))
    (proposal (unwrap! (contract-call? .ProposalManager get-proposal winning-proposal-id) ERR_PROPOSAL_NOT_ELIGIBLE))
  )
    (asserts! (is-eq tx-sender (get creator bounty)) ERR_NOT_BOUNTY_CREATOR)
    (asserts! (not (get claimed bounty)) ERR_BOUNTY_CLAIMED)
    (asserts! (is-eq (get status proposal) "passed") ERR_PROPOSAL_NOT_ELIGIBLE)
    
    (try! (contract-call? .VotingToken transfer 
      (get total-pool bounty) 
      (as-contract tx-sender) 
      (get submitted-by submission) 
      none))
    
    (map-set bounties bounty-id
      (merge bounty { 
        claimed: true,
        winning-proposal: (some winning-proposal-id)
      }))
    
    (ok (get total-pool bounty))))

(define-public (refund-expired-bounty (bounty-id uint))
  (let (
    (bounty (unwrap! (map-get? bounties bounty-id) ERR_BOUNTY_NOT_FOUND))
    (contribution (unwrap! (map-get? bounty-contributions { bounty-id: bounty-id, contributor: tx-sender }) ERR_INSUFFICIENT_FUNDS))
  )
    (asserts! (> stacks-block-height (get expiry-block bounty)) ERR_BOUNTY_ACTIVE)
    (asserts! (not (get claimed bounty)) ERR_BOUNTY_CLAIMED)
    
    (try! (contract-call? .VotingToken transfer 
      (get amount contribution) 
      (as-contract tx-sender) 
      tx-sender 
      none))
    
    (map-delete bounty-contributions { bounty-id: bounty-id, contributor: tx-sender })
    
    (map-set bounties bounty-id
      (merge bounty { total-pool: (- (get total-pool bounty) (get amount contribution)) }))
    
    (ok (get amount contribution))))

(define-read-only (get-bounty (bounty-id uint))
  (map-get? bounties bounty-id))

(define-read-only (get-bounty-contribution (bounty-id uint) (contributor principal))
  (map-get? bounty-contributions { bounty-id: bounty-id, contributor: contributor }))

(define-read-only (get-bounty-proposal-submission (bounty-id uint) (proposal-id uint))
  (map-get? bounty-proposals { bounty-id: bounty-id, proposal-id: proposal-id }))

(define-read-only (is-bounty-active (bounty-id uint))
  (let ((bounty (map-get? bounties bounty-id)))
    (if (is-none bounty)
      false
      (let ((bounty-data (unwrap-panic bounty)))
        (and 
          (< stacks-block-height (get expiry-block bounty-data))
          (not (get claimed bounty-data)))))))

(define-read-only (get-active-bounties-count)
  (let ((current-id (var-get next-bounty-id)))
    (fold count-active-bounties (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)))

(define-private (count-active-bounties (bounty-id uint) (count uint))
  (if (is-bounty-active bounty-id)
    (+ count u1)
    count))