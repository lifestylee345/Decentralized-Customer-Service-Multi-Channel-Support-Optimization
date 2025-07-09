;; Satisfaction Measurement Contract
;; Measures customer support satisfaction

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_RATING (err u501))
(define-constant ERR_ALREADY_RATED (err u502))
(define-constant ERR_TICKET_NOT_FOUND (err u503))

;; Customer satisfaction ratings (1-5 scale)
(define-map satisfaction-ratings uint {
    customer: principal,
    ticket-id: uint,
    rating: uint,
    feedback: (optional (string-ascii 500)),
    submitted-at: uint
})

(define-map ticket-satisfaction uint {
    total-ratings: uint,
    avg-rating: uint,
    rating-sum: uint
})

(define-map manager-satisfaction principal {
    total-ratings: uint,
    avg-rating: uint,
    rating-sum: uint,
    five-star-count: uint
})

(define-data-var next-rating-id uint u1)
(define-data-var global-satisfaction uint u0)
(define-data-var total-ratings uint u0)

;; Submit satisfaction rating
(define-public (submit-rating
    (ticket-id uint)
    (rating uint)
    (feedback (optional (string-ascii 500))))
    (begin
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)

        (let ((rating-id (var-get next-rating-id)))
            (map-set satisfaction-ratings rating-id {
                customer: tx-sender,
                ticket-id: ticket-id,
                rating: rating,
                feedback: feedback,
                submitted-at: block-height
            })

            ;; Update ticket satisfaction
            (match (map-get? ticket-satisfaction ticket-id)
                existing
                (let ((new-total (+ (get total-ratings existing) u1))
                      (new-sum (+ (get rating-sum existing) rating)))
                    (map-set ticket-satisfaction ticket-id {
                        total-ratings: new-total,
                        avg-rating: (/ new-sum new-total),
                        rating-sum: new-sum
                    })
                )
                ;; First rating for this ticket
                (map-set ticket-satisfaction ticket-id {
                    total-ratings: u1,
                    avg-rating: rating,
                    rating-sum: rating
                })
            )

            ;; Update global satisfaction
            (let ((current-total (var-get total-ratings))
                  (current-global (var-get global-satisfaction))
                  (new-total (+ current-total u1)))
                (var-set total-ratings new-total)
                (var-set global-satisfaction
                    (/ (+ (* current-global current-total) rating) new-total))
            )

            (var-set next-rating-id (+ rating-id u1))
            (ok rating-id)
        )
    )
)

;; Update manager satisfaction (called when ticket is resolved)
(define-public (update-manager-satisfaction (manager principal) (rating uint))
    (begin
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)

        (match (map-get? manager-satisfaction manager)
            existing
            (let ((new-total (+ (get total-ratings existing) u1))
                  (new-sum (+ (get rating-sum existing) rating))
                  (new-five-star (if (is-eq rating u5)
                                   (+ (get five-star-count existing) u1)
                                   (get five-star-count existing))))
                (map-set manager-satisfaction manager {
                    total-ratings: new-total,
                    avg-rating: (/ new-sum new-total),
                    rating-sum: new-sum,
                    five-star-count: new-five-star
                })
            )
            ;; First rating for this manager
            (map-set manager-satisfaction manager {
                total-ratings: u1,
                avg-rating: rating,
                rating-sum: rating,
                five-star-count: (if (is-eq rating u5) u1 u0)
            })
        )
        (ok true)
    )
)

;; Get satisfaction rating
(define-read-only (get-rating (rating-id uint))
    (map-get? satisfaction-ratings rating-id)
)

;; Get ticket satisfaction
(define-read-only (get-ticket-satisfaction (ticket-id uint))
    (map-get? ticket-satisfaction ticket-id)
)

;; Get manager satisfaction
(define-read-only (get-manager-satisfaction (manager principal))
    (map-get? manager-satisfaction manager)
)

;; Get global satisfaction
(define-read-only (get-global-satisfaction)
    (var-get global-satisfaction)
)

;; Calculate satisfaction trend (simplified)
(define-read-only (get-satisfaction-trend (manager principal))
    (match (map-get? manager-satisfaction manager)
        stats
        (let ((five-star-percentage (if (> (get total-ratings stats) u0)
                                      (/ (* (get five-star-count stats) u100) (get total-ratings stats))
                                      u0)))
            (ok {
                avg-rating: (get avg-rating stats),
                total-ratings: (get total-ratings stats),
                five-star-percentage: five-star-percentage
            })
        )
        (ok { avg-rating: u0, total-ratings: u0, five-star-percentage: u0 })
    )
)

;; Get top performing managers
(define-read-only (get-top-managers)
    ;; This would return managers sorted by satisfaction
    ;; Implementation would require iteration through all managers
    (ok u0)
)
