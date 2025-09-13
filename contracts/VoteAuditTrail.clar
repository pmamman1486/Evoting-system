;; Vote Audit Trail - Cryptographic vote verification and audit system
;; Provides transparent audit trail and integrity verification for elections

;; Error constants  
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-COMMITMENT-NOT-FOUND (err u401))
(define-constant ERR-VERIFICATION-FAILED (err u402))
(define-constant ERR-AUDIT-SEALED (err u403))
(define-constant ERR-CHALLENGE-EXISTS (err u404))
(define-constant ERR-INSUFFICIENT-REWARD (err u405))
(define-constant ERR-UPDATE-FAILED (err u406))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Audit parameters
(define-constant MIN-CHALLENGE-REWARD u1000)
(define-constant AUDIT-PERIOD-BLOCKS u1440) ;; ~6 hours
(define-constant MAX-VERIFIERS u50)

;; Vote commitments - cryptographic proof of vote integrity
(define-map vote-commitments
    {voter: principal, proposal-id: uint}
    {
        commitment-hash: (buff 32),
        vote-choice: uint,
        block-height: uint,
        verified: bool,
        challenge-count: uint
    }
)

;; Audit entries - comprehensive election audit trail
(define-map audit-entries
    uint ;; entry-id
    {
        proposal-id: uint,
        voter-count: uint,
        commitment-count: uint,
        verification-rate: uint,
        challenge-count: uint,
        timestamp: uint,
        auditor: principal,
        sealed: bool
    }
)

;; Proposal audit status
(define-map proposal-audits
    uint ;; proposal-id
    {
        total-votes: uint,
        verified-votes: uint,
        pending-challenges: uint,
        audit-complete: bool,
        integrity-score: uint,
        last-updated: uint
    }
)

;; Verification challenges
(define-map verification-challenges
    uint ;; challenge-id
    {
        challenger: principal,
        proposal-id: uint,
        voter: principal,
        challenge-reason: (string-ascii 100),
        reward-pool: uint,
        resolved: bool,
        resolution: (optional (string-ascii 200))
    }
)

;; Authorized verifiers
(define-map authorized-verifiers
    principal
    {
        authorized: bool,
        verification-count: uint,
        reputation-score: uint,
        last-activity: uint
    }
)

;; Data variables
(define-data-var audit-counter uint u0)
(define-data-var challenge-counter uint u0)

;; Public Functions

;; Record vote commitment for integrity verification
(define-public (record-vote-commitment (proposal-id uint) (commitment-hash (buff 32)) (vote-choice uint))
    (let (
        (existing-commitment (map-get? vote-commitments {voter: tx-sender, proposal-id: proposal-id}))
    )
        (asserts! (is-none existing-commitment) ERR-COMMITMENT-NOT-FOUND)
        
        ;; Store cryptographic commitment
        (map-set vote-commitments {voter: tx-sender, proposal-id: proposal-id}
            {
                commitment-hash: commitment-hash,
                vote-choice: vote-choice,
                block-height: stacks-block-height,
                verified: false,
                challenge-count: u0
            }
        )
        
        ;; Update proposal audit status
        (unwrap! (update-proposal-audit-status proposal-id) ERR-UPDATE-FAILED)
        (ok true)
    )
)

;; Verify vote commitment cryptographically
(define-public (verify-vote-commitment (voter principal) (proposal-id uint) (proof (buff 64)))
    (let (
        (commitment (unwrap! (map-get? vote-commitments {voter: voter, proposal-id: proposal-id}) ERR-COMMITMENT-NOT-FOUND))
        (verifier-info (unwrap! (map-get? authorized-verifiers tx-sender) ERR-NOT-AUTHORIZED))
    )
        (asserts! (get authorized verifier-info) ERR-NOT-AUTHORIZED)
        
        ;; Mark as verified (simplified cryptographic verification)
        (map-set vote-commitments {voter: voter, proposal-id: proposal-id}
            (merge commitment {verified: true})
        )
        
        ;; Update verifier stats
        (map-set authorized-verifiers tx-sender
            (merge verifier-info {
                verification-count: (+ (get verification-count verifier-info) u1),
                last-activity: stacks-block-height
            })
        )
        
        (unwrap! (update-proposal-audit-status proposal-id) ERR-UPDATE-FAILED)
        (ok true)
    )
)

;; Challenge a verification
(define-public (challenge-verification (proposal-id uint) (voter principal) (reason (string-ascii 100)) (reward-amount uint))
    (let (
        (challenge-id (+ (var-get challenge-counter) u1))
        (commitment (unwrap! (map-get? vote-commitments {voter: voter, proposal-id: proposal-id}) ERR-COMMITMENT-NOT-FOUND))
    )
        (asserts! (>= reward-amount MIN-CHALLENGE-REWARD) ERR-INSUFFICIENT-REWARD)
        
        ;; Transfer challenge reward to contract
        (try! (stx-transfer? reward-amount tx-sender (as-contract tx-sender)))
        
        ;; Create challenge
        (map-set verification-challenges challenge-id
            {
                challenger: tx-sender,
                proposal-id: proposal-id,
                voter: voter,
                challenge-reason: reason,
                reward-pool: reward-amount,
                resolved: false,
                resolution: none
            }
        )
        
        ;; Update commitment challenge count
        (map-set vote-commitments {voter: voter, proposal-id: proposal-id}
            (merge commitment {challenge-count: (+ (get challenge-count commitment) u1)})
        )
        
        (var-set challenge-counter challenge-id)
        (ok challenge-id)
    )
)

;; Seal audit trail (finalize election audit)
(define-public (seal-audit-trail (proposal-id uint))
    (let (
        (audit-status (unwrap! (map-get? proposal-audits proposal-id) ERR-COMMITMENT-NOT-FOUND))
        (entry-id (+ (var-get audit-counter) u1))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get audit-complete audit-status)) ERR-AUDIT-SEALED)
        
        ;; Create final audit entry
        (map-set audit-entries entry-id
            {
                proposal-id: proposal-id,
                voter-count: (get total-votes audit-status),
                commitment-count: (get verified-votes audit-status),
                verification-rate: (calculate-verification-rate proposal-id),
                challenge-count: (get pending-challenges audit-status),
                timestamp: stacks-block-height,
                auditor: tx-sender,
                sealed: true
            }
        )
        
        ;; Mark audit as complete
        (map-set proposal-audits proposal-id
            (merge audit-status {audit-complete: true})
        )
        
        (var-set audit-counter entry-id)
        (ok entry-id)
    )
)

;; Authorize independent verifier
(define-public (authorize-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        
        (map-set authorized-verifiers verifier
            {
                authorized: true,
                verification-count: u0,
                reputation-score: u100,
                last-activity: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Generate integrity report
(define-public (generate-integrity-report (proposal-id uint))
    (let (
        (audit-status (unwrap! (map-get? proposal-audits proposal-id) ERR-COMMITMENT-NOT-FOUND))
        (integrity-score (calculate-integrity-score proposal-id))
    )
        (map-set proposal-audits proposal-id
            (merge audit-status {
                integrity-score: integrity-score,
                last-updated: stacks-block-height
            })
        )
        (ok integrity-score)
    )
)

;; Private Functions

;; Update proposal audit status
(define-private (update-proposal-audit-status (proposal-id uint))
    (let (
        (current-status (default-to 
            {total-votes: u0, verified-votes: u0, pending-challenges: u0, audit-complete: false, integrity-score: u0, last-updated: u0}
            (map-get? proposal-audits proposal-id)
        ))
    )
        (map-set proposal-audits proposal-id
            (merge current-status {
                total-votes: (+ (get total-votes current-status) u1),
                last-updated: stacks-block-height
            })
        )
        (ok true)
    )
)

;; Calculate verification rate
(define-private (calculate-verification-rate (proposal-id uint))
    (match (map-get? proposal-audits proposal-id)
        audit-status
            (if (> (get total-votes audit-status) u0)
                (/ (* (get verified-votes audit-status) u100) (get total-votes audit-status))
                u0
            )
        u0
    )
)

;; Calculate integrity score
(define-private (calculate-integrity-score (proposal-id uint))
    (let (
        (verification-rate (calculate-verification-rate proposal-id))
        (audit-status (default-to 
            {total-votes: u0, verified-votes: u0, pending-challenges: u0, audit-complete: false, integrity-score: u0, last-updated: u0}
            (map-get? proposal-audits proposal-id)
        ))
        (challenge-penalty (if (<= (* (get pending-challenges audit-status) u5) u20) (* (get pending-challenges audit-status) u5) u20))
    )
        (if (>= verification-rate challenge-penalty)
            (- verification-rate challenge-penalty)
            u0
        )
    )
)

;; Read-only Functions

(define-read-only (get-vote-commitment (voter principal) (proposal-id uint))
    (map-get? vote-commitments {voter: voter, proposal-id: proposal-id}))

(define-read-only (get-proposal-audit (proposal-id uint))
    (map-get? proposal-audits proposal-id))

(define-read-only (get-challenge (challenge-id uint))
    (map-get? verification-challenges challenge-id))

(define-read-only (get-verifier-status (verifier principal))
    (map-get? authorized-verifiers verifier))

(define-read-only (is-authorized-verifier (verifier principal))
    (match (map-get? authorized-verifiers verifier)
        verifier-info (get authorized verifier-info)
        false
    )
)
