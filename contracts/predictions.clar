;; Policy Prediction Market Smart Contract
;; This contract allows users to create prediction markets for policy outcomes,
;; place bets, resolve markets, and claim winnings.

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

;; Data Variables
(define-data-var market-name (string-ascii 50) "Policy Prediction Market")
(define-data-var next-market-id uint u1)

;; Maps
(define-map markets
  { market-id: uint }
  { description: (string-ascii 256), outcome: (optional bool), close-block: uint }
)

(define-map bets
  { market-id: uint, user: principal }
  { amount: uint, prediction: bool }
)

;; Private Functions
(define-private (is-valid-market-id (market-id uint))
  (< market-id (var-get next-market-id))
)

;; Public Functions

;; Create a new market
;; @param description: A description of the market
;; @param close-block: The block height at which the market will close
;; @returns: The ID of the newly created market
(define-public (create-market (description (string-ascii 256)) (close-block uint))
  (let
    (
      (market-id (var-get next-market-id))
    )
    (asserts! (> close-block block-height) ERR-INVALID-CLOSE-BLOCK)
    (map-set markets
      { market-id: market-id }
      { description: description, outcome: none, close-block: close-block }
    )
    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Place a bet on a market
;; @param market-id: The ID of the market to bet on
;; @param prediction: The predicted outcome (true or false)
;; @param amount: The amount of STX to bet
;; @returns: Success or failure
(define-public (place-bet (market-id uint) (prediction bool) (amount uint))
  (let
    (
      (existing-bet (default-to { amount: u0, prediction: false } 
                      (map-get? bets { market-id: market-id, user: tx-sender })))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-BET)
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
;; @param market-id: The ID of the market to resolve
;; @param outcome: The actual outcome of the market (true or false)
;; @returns: Success or failure
(define-public (resolve-market (market-id uint) (outcome bool))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (is-none (get outcome market)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (>= block-height (get close-block market)) ERR-MARKET-NOT-CLOSED)
    (map-set markets
      { market-id: market-id }
      (merge market { outcome: (some outcome) })
    )
    (ok true)
  )
)

;; Claim winnings from a resolved market
;; @param market-id: The ID of the market to claim winnings from
;; @returns: Success or failure
(define-public (claim-winnings (market-id uint))
  (let
    (
      (market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND))
      (bet (unwrap! (map-get? bets { market-id: market-id, user: tx-sender }) ERR-BET-NOT-FOUND))
      (outcome (unwrap! (get outcome market) ERR-MARKET-NOT-RESOLVED))
    )
    (asserts! (is-valid-market-id market-id) ERR-MARKET-NOT-FOUND)
    (asserts! (is-eq (get prediction bet) outcome) ERR-BET-LOST)
    (map-delete bets { market-id: market-id, user: tx-sender })
    (stx-transfer? (get amount bet) (as-contract tx-sender) tx-sender)
  )
)