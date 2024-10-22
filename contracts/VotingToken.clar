(define-constant TOKEN_NAME "VotingToken")
(define-constant TOKEN_SYMBOL "VT")
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2))
(define-constant ERR_INSUFFICIENT_STAKE (err u3))
(define-constant ERR_OVERFLOW (err u4))

;; State variables
(define-map balances principal uint)
(define-map staked-balances principal uint)
(define-data-var token-owner principal tx-sender)
(define-data-var total-supply uint u0)



;; SIP-010 functions
(define-read-only (get-name)
  (ok TOKEN_NAME))

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL))

(define-read-only (get-decimals)
  (ok u6))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-public (get-balance (account principal))
  (ok (default-to u0 (map-get? balances account))))

(define-public (get-staked-balance (account principal))
  (ok (default-to u0 (map-get? staked-balances account))))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let (
    (sender-balance (default-to u0 (map-get? balances sender)))
  )
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
    (match memo to-print (print to-print) 0x)
    (ok true)))

(define-public (mint (recipient principal) (amount uint))
  (let ((current-balance (default-to u0 (map-get? balances recipient))))
    (asserts! (is-eq (var-get token-owner) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> (+ current-balance amount) current-balance) ERR_OVERFLOW)
    (map-set balances recipient (+ current-balance amount))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok amount)))

(define-public (burn (amount uint))
  (let ((current-balance (default-to u0 (map-get? balances tx-sender))))
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set balances tx-sender (- current-balance amount))
    (var-set total-supply (- (var-get total-supply) amount))
    (ok amount)))

(define-public (stake (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? balances tx-sender)))
    (current-staked-balance (default-to u0 (map-get? staked-balances tx-sender)))
  )
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (map-set staked-balances tx-sender (+ current-staked-balance amount))
    (map-set balances tx-sender (- current-balance amount))
    (ok amount)))

(define-public (unstake (amount uint))
  (let (
    (staked-balance (default-to u0 (map-get? staked-balances tx-sender)))
    (current-balance (default-to u0 (map-get? balances tx-sender)))
  )
    (asserts! (>= staked-balance amount) ERR_INSUFFICIENT_STAKE)
    (map-set staked-balances tx-sender (- staked-balance amount))
    (map-set balances tx-sender (+ current-balance amount))
    (ok amount)))

(define-public (change-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get token-owner)) ERR_UNAUTHORIZED)
    (var-set token-owner new-owner)
    (ok true)))

(define-read-only (get-token-uri)
  (ok none))



(define-public (get-token-owner)
  (ok (var-get token-owner))) ;; Wrap the return value in an ok response
