;; Policy Prediction Market Smart Contract
;; This contract allows users to create prediction markets for policy outcomes,
;; place bets, resolve markets, claim winnings, and handles market expiration.

;; Constants
(define-constant ERR-INVALID-CLOSE-BLOCK (err u1))
(define-constant ERR-MARKET-CLOSED (err u2))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u3))
(define-constant ERR-INVALID-BET (err u4))
(define-constant ERR-MARKET-NOT-FOUND (err u5))
(define-constant ERR-INSUFFICIENT-FUNDS (err u6))
(define-constant ERR-MARKET-NOT-CLOSED (err u7))
(define-constant ERR-BET-NOT-FOUND (err u8))
(define-constant ERR-MARKET-NOT-RESOLVED (err u9))
(define-constant ERR-BET-LOST (err u10))
(define-constant ERR-MARKET-EXPIRED (err u11))
(define-constant ERR-MARKET-NOT-EXPIRED (err u12))
(define-constant ERR-UNAUTHORIZED (err u13))
(define-constant ERR-BET-TOO-LOW (err u14))
(define-constant ERR-BET-TOO-HIGH (err u15))
(define-constant ERR-INVALID-PARAMETER (err u16))

;; Additional Constants for Validation
(define-constant MAX-CLOSE-BLOCK-DELAY u52560) ;; Maximum ~1 year worth of blocks
(define-constant MIN-CLOSE-BLOCK-DELAY u144)   ;; Minimum ~1 day worth of blocks
(define-constant MAX-EXPIRY-DELAY u105120)     ;; Maximum ~2 years worth of blocks
(define-constant MIN-DESCRIPTION-LENGTH u10)    ;; Minimum description length

;; Data Variables
(define-data-var market-name (string-ascii 50) "Policy Prediction Market")
(define-data-var next-market-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Configuration
(define-data-var expiry-period uint u10000)
(define-data-var min-bet-amount uint u10)
(define-data-var max-bet-amount uint u1000000)

;; Maps
(define-map markets
  { market-id: uint }
  {
    description: (string-ascii 256),
    outcome: (optional bool),
    close-block: uint,
    expiry-block: uint,
    creator: principal
  }
)

(define-map bets
  { market-id: uint, user: principal }
  { amount: uint, prediction: bool }
)

;; Enhanced Private Validation Functions
(define-private (is-valid-market-id (market-id uint))
  (< market-id (var-get next-market-id))
)

(define-private (is-market-expired (market-id uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) false)))
    (>= block-height (get expiry-block market))
  )
)

(define-private (is-valid-string-length (str (string-ascii 256)))
  (and 
    (>= (len str) MIN-DESCRIPTION-LENGTH)
    (<= (len str) u256)
  )
)

(define-private (is-valid-close-block (close-block uint))
  (let 
    (
      (block-delay (- close-block block-height))
    )
    (and
      (>= block-delay MIN-CLOSE-BLOCK-DELAY)
      (<= block-delay MAX-CLOSE-BLOCK-DELAY)
    )
  )
)

(define-private (is-valid-expiry-block (close-block uint) (expiry-block uint))
  (let
    (
      (expiry-delay (- expiry-block close-block))
    )
    (and
      (> expiry-block close-block)
      (<= expiry-delay MAX-EXPIRY-DELAY)
    )
  )
)

(define-private (is-valid-bet-amount (amount uint))
  (and
    (>= amount (var-get min-bet-amount))
    (<= amount (var-get max-bet-amount))
  )
)

;; Public Functions

;; Create a new market with enhanced validation
(define-public (create-market (description (string-ascii 256)) (close-block uint))
  (let
    (
      (market-id (var-get next-market-id))
      (expiry-block (+ close-block (var-get expiry-period)))
    )
    ;; Enhanced input validation
    (asserts! (is-valid-string-length description) ERR-INVALID-PARAMETER)
    (asserts! (is-valid-close-block close-block) ERR-INVALID-CLOSE-BLOCK)
    (asserts! (is-valid-expiry-block close-block expiry-block) ERR-INVALID-PARAMETER)
    
    (map-set markets
      { market-id: market-id }
      {
        description: description,
        outcome: none,
        close-block: close-block,
        expiry-block: expiry-block,
        creator: tx-sender
      }
    )
    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Place a bet on a market with enhanced validation
(define-public (place-bet (market-id uint) (prediction bool) (amount uint))
  (let
    (
      (existing-bet (default-to { amount: u0, prediction: false } 
                      (map-get? bets { market-id: market-id, user: tx-sender })))
    )
    ;; Enhanced input validation
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (is-valid-bet-amount amount) ERR-INVALID-BET)
    (let
      (
        (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
        (total-bet-amount (+ amount (get amount existing-bet)))
      )
      ;; Additional validation for combined bet amount
      (asserts! (<= total-bet-amount (var-get max-bet-amount)) ERR-BET-TOO-HIGH)
      (asserts! (< block-height (get close-block market)) ERR-MARKET-CLOSED)
      (asserts! (is-none (get outcome market)) ERR-MARKET-ALREADY-RESOLVED)
      (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-FUNDS)
      
      (map-set bets
        { market-id: market-id, user: tx-sender }
        { amount: total-bet-amount, prediction: prediction }
      )
      (stx-transfer? amount tx-sender (as-contract tx-sender))
    )
  )
)

;; The rest of the contract remains the same...
;; [Previous functions: resolve-market, claim-winnings, refund-expired-bet, cleanup-expired-market]

;; Enhanced setter for expiry period with stricter validation
(define-public (set-expiry-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and 
      (>= new-period u1000)  ;; Minimum ~1 day worth of blocks
      (<= new-period u52560) ;; Maximum ~1 year worth of blocks
    ) ERR-INVALID-PARAMETER)
    (ok (var-set expiry-period new-period))
  )
)

;; Enhanced setter for minimum bet amount with stricter validation
(define-public (set-min-bet-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and 
      (>= new-amount u1)
      (< new-amount (var-get max-bet-amount))
      (<= new-amount u1000000) ;; Upper limit for minimum bet
    ) ERR-INVALID-PARAMETER)
    (ok (var-set min-bet-amount new-amount))
  )
)

;; Enhanced setter for maximum bet amount with stricter validation
(define-public (set-max-bet-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and 
      (> new-amount (var-get min-bet-amount))
      (<= new-amount u1000000000000)
      (>= new-amount u1000) ;; Lower limit for maximum bet
    ) ERR-INVALID-PARAMETER)
    (ok (var-set max-bet-amount new-amount))
  )
)

;; Getter for contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Function to transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-PARAMETER)
    (ok (var-set contract-owner new-owner))
  )
)