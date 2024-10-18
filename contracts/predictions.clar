(define-data-var market-name (string-ascii 50) "Policy Prediction Market")

(define-map markets
  { market-id: uint }
  { description: (string-ascii 256), outcome: (optional bool), close-block: uint }
)

(define-map bets
  { market-id: uint, user: principal }
  { amount: uint, prediction: bool }
)

(define-data-var next-market-id uint u1)

;; Create a new market
(define-public (create-market (description (string-ascii 256)) (close-block uint))
  (let ((market-id (var-get next-market-id)))
    (map-set markets
      { market-id: market-id }
      { description: description, outcome: none, close-block: close-block }
    )
    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Place a bet on a market
(define-public (place-bet (market-id uint) (prediction bool) (amount uint))
  (let ((existing-bet (default-to { amount: u0, prediction: false } 
                        (map-get? bets { market-id: market-id, user: tx-sender }))))
    (if (>= block-height (unwrap-panic (get close-block (map-get? markets { market-id: market-id }))))
      (err u1) ;; Market is closed
      (begin
        (map-set bets
          { market-id: market-id, user: tx-sender }
          { amount: (+ amount (get amount existing-bet)), prediction: prediction }
        )
        (stx-transfer? amount tx-sender (as-contract tx-sender))
      )
    )
  )
)

;; Resolve a market
(define-public (resolve-market (market-id uint) (outcome bool))
  (let ((market (unwrap-panic (map-get? markets { market-id: market-id }))))
    (if (is-some (get outcome market))
      (err u2) ;; Market already resolved
      (begin
        (map-set markets
          { market-id: market-id }
          (merge market { outcome: (some outcome) })
        )
        (ok true)
      )
    )
  )
)

;; Claim winnings from a resolved market
(define-public (claim-winnings (market-id uint))
  (let (
    (market (unwrap-panic (map-get? markets { market-id: market-id })))
    (bet (unwrap-panic (map-get? bets { market-id: market-id, user: tx-sender })))
    (outcome (unwrap-panic (get outcome market)))
  )
    (if (is-eq (get prediction bet) outcome)
      (begin
        (map-delete bets { market-id: market-id, user: tx-sender })
        (stx-transfer? (get amount bet) (as-contract tx-sender) tx-sender)
      )
      (err u3) ;; User did not win the bet
    )
  )
)