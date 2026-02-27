;; ==========================================================
;; DONATION DAPP – PRODUCTION VERSION
;; Secure STX-based donation contract
;; ==========================================================

;; ================= CONSTANTS =================

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))
(define-constant ERR-PAUSED (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))

;; ================= STATE =================

(define-data-var contract-owner principal tx-sender)
(define-data-var total-donated uint u0)
(define-data-var paused bool false)

(define-map donations
  { donor: principal }
  { amount: uint }
)

;; ================= PRIVATE HELPERS =================

(define-private (assert-owner)
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
)

(define-private (assert-not-paused)
  (asserts! (not (var-get paused)) ERR-PAUSED)
)

;; ================= PUBLIC FUNCTIONS =================

;; Donate STX to the contract
(define-public (donate (amount uint))
  (begin
    (assert-not-paused)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update donor record (accumulative)
    (let (
          (current (default-to u0 (get amount (map-get? donations { donor: tx-sender }))))
         )
      (map-set donations
        { donor: tx-sender }
        { amount: (+ current amount) }
      )
    )

    ;; Update total
    (var-set total-donated (+ (var-get total-donated) amount))

    (print {
      event: "donation",
      donor: tx-sender,
      amount: amount,
      total-donated: (var-get total-donated)
    })

    (ok true)
  )
)

;; Withdraw collected funds (owner only)
(define-public (withdraw (amount uint))
  (begin
    (assert-owner)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)

    (try!
      (stx-transfer?
        amount
        (as-contract tx-sender)
        tx-sender
      )
    )

    (print {
      event: "withdraw",
      by: tx-sender,
      amount: amount
    })

    (ok true)
  )
)

;; ================= ADMIN =================

(define-public (pause)
  (begin
    (assert-owner)
    (var-set paused true)
    (print { event: "paused" })
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (assert-owner)
    (var-set paused false)
    (print { event: "unpaused" })
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (assert-owner)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; ================= READ ONLY =================

(define-read-only (get-donation (donor principal))
  (default-to u0 (get amount (map-get? donations { donor })))
)

(define-read-only (get-total-donated)
  (var-get total-donated)
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)
