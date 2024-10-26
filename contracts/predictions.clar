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
(define-constant ERR-INVALID-PARAMETER (err u16))  ;; New error for invalid input parameters

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

;; Private Functions
(define-private (is-valid-market-id (market-id uint))
  (< market-id (var-get next-market-id))
)

(define-private (is-market-expired (market-id uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) false)))
    (>= block-height (get expiry-block market))
  )
)

;; Validation function for string length
(define-private (is-valid-string-length (str (string-ascii 256)))
  (and (>= (len str) u1) (<= (len str) u256))
)

;; Public Functions

;; Create a new market
(define-public (create-market (description (string-ascii 256)) (close-block uint))
  (let
    (
      (market-id (var-get next-market-id))
      (expiry-block (+ close-block (var-get expiry-period)))
    )
    (asserts! (is-valid-string-length description) ERR-INVALID-PARAMETER)
    (asserts! (> close-block block-height) ERR-INVALID-CLOSE-BLOCK)
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

;; Place a bet on a market
(define-public (place-bet (market-id uint) (prediction bool) (amount uint))
  (let
    (
      (existing-bet (default-to { amount: u0, prediction: false } 
                      (map-get? bets { market-id: market-id, user: tx-sender })))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (>= amount (var-get min-bet-amount)) ERR-BET-TOO-LOW)
    (asserts! (<= amount (var-get max-bet-amount)) ERR-BET-TOO-HIGH)
    (let
      (
        (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
      )
      (asserts! (< block-height (get close-block market)) ERR-MARKET-CLOSED)
      (asserts! (is-none (get outcome market)) ERR-MARKET-ALREADY-RESOLVED)
      (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-FUNDS)
      (map-set bets
        { market-id: market-id, user: tx-sender }
        { amount: (+ amount (get amount existing-bet)), prediction: prediction }
      )
      (stx-transfer? amount tx-sender (as-contract tx-sender))
    )
  )
)

;; Resolve a market
(define-public (resolve-market (market-id uint) (outcome bool))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (is-none (get outcome market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (>= block-height (get close-block market)) ERR-MARKET-NOT-CLOSED)
    (asserts! (< block-height (get expiry-block market)) ERR-MARKET-EXPIRED)
    (map-set markets
      { market-id: market-id }
      (merge market { outcome: (some outcome) })
    )
    (ok true)
  )
)

;; Claim winnings from a resolved market
(define-public (claim-winnings (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
      (bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender }) ERR-BET-NOT-FOUND))
      (outcome (unwrap! (get outcome market) ERR-MARKET-NOT-RESOLVED))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (< block-height (get expiry-block market)) ERR-MARKET-EXPIRED)
    (asserts! (is-eq (get prediction bet) outcome) ERR-BET-LOST)
    (map-delete bets { market-id: market-id, user: tx-sender })
    (stx-transfer? (get amount bet) (as-contract tx-sender) tx-sender)
  )
)

;; Refund bets for an expired market
(define-public (refund-expired-bet (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
      (bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender }) ERR-BET-NOT-FOUND))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (>= block-height (get expiry-block market)) ERR-MARKET-NOT-EXPIRED)
    (asserts! (is-none (get outcome market)) ERR-MARKET-ALREADY-RESOLVED)
    (map-delete bets { market-id: market-id, user: tx-sender })
    (stx-transfer? (get amount bet) (as-contract tx-sender) tx-sender)
  )
)

;; Clean up an expired market (can only be called by the market creator)
(define-public (cleanup-expired-market (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (>= block-height (get expiry-block market)) ERR-MARKET-NOT-EXPIRED)
    (asserts! (is-eq tx-sender (get creator market)) ERR-UNAUTHORIZED)
    (map-delete markets { market-id: market-id })
    (ok true)
  )
)

;; Getter for expiry period
(define-read-only (get-expiry-period)
  (ok (var-get expiry-period))
)

;; Setter for expiry period (only contract owner can set this)
(define-public (set-expiry-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and (> new-period u0) (<= new-period u1000000)) ERR-INVALID-PARAMETER)
    (ok (var-set expiry-period new-period))
  )
)

;; Getter for minimum bet amount
(define-read-only (get-min-bet-amount)
  (ok (var-get min-bet-amount))
)

;; Setter for minimum bet amount (only contract owner can set this)
(define-public (set-min-bet-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and (> new-amount u0) (< new-amount (var-get max-bet-amount))) ERR-INVALID-PARAMETER)
    (ok (var-set min-bet-amount new-amount))
  )
)

;; Getter for maximum bet amount
(define-read-only (get-max-bet-amount)
  (ok (var-get max-bet-amount))
)

;; Setter for maximum bet amount (only contract owner can set this)
(define-public (set-max-bet-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (and (> new-amount (var-get min-bet-amount)) (<= new-amount u1000000000000)) ERR-INVALID-PARAMETER)
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