(module kuro-compliance GOVERN
  (defcap GOVERN () true)
  (defconst GOV (read-keyset "GOV"))
  (defconst ORACLE (read-keyset "ORACLE"))

  ;; tables
  (deftable kyc { account:string status:string ts:time })
  (deftable mint_approvals { id:string account:string amount:decimal exp:time used:bool ts:time })
  (deftable redeem_approvals { id:string account:string amount:decimal bankref:string exp:time used:bool ts:time })
  (deftable events { id:string typ:string payload:string ts:time })

  (defun now:time () (time "1970-01-01T00:00:00Z"))

  (defun is-kyc:bool (acct:string)
    (with-default-read kyc acct {"account":acct "status":"none" "ts": (now)}
      (= (at "status" (read kyc acct)) "approved")))

  (defun set-kyc:string (acct:string status:string)
    (enforce-keyset ORACLE)
    (enforce (or (= status "approved") (= status "revoked")) "bad-status")
    (write kyc acct {"account":acct "status":status "ts": (now)})
    (write events (format "kyc:{}:{}" [acct status])
      {"id": (format "kyc:{}:{}" [acct status])
       "typ":"kyc"
       "payload": acct
       "ts": (now)})
    "ok")

  (defun approve-mint:string (id:string acct:string amt:decimal exp:time)
    (enforce-keyset ORACLE)
    (enforce (> amt 0.0) "amt>0")
    (enforce (is-kyc acct) "not-kyc")
    (write mint_approvals id
      {"id":id "account":acct "amount":amt "exp":exp "used": false "ts": (now)})
    (write events (format "mintOk:{}" [id])
      {"id": (format "mintOk:{}" [id])
       "typ":"mintOk"
       "payload": (format "{} {} {}" [id acct amt])
       "ts": (now)})
    "ok")

  (defun consume-mint:string (id:string)
    (enforce-keyset ORACLE)
    (let ((m (read mint_approvals id)))
      (enforce (= (at "used" m) false) "already-used")
      (write mint_approvals id
        {"id":id
         "account":(at "account" m)
         "amount":(at "amount" m)
         "exp":(at "exp" m)
         "used": true
         "ts": (now)})
      "ok"))

  (defun approve-redeem:string (id:string acct:string amt:decimal bankref:string exp:time)
    (enforce-keyset ORACLE)
    (enforce (> amt 0.0) "amt>0")
    (enforce (is-kyc acct) "not-kyc")
    (write redeem_approvals id
      {"id":id "account":acct "amount":amt "bankref":bankref "exp":exp "used": false "ts": (now)})
    (write events (format "redeemOk:{}" [id])
      {"id": (format "redeemOk:{}" [id])
       "typ":"redeemOk"
       "payload": (format "{} {} {} {}" [id acct amt bankref])
       "ts": (now)})
    "ok")

  (defun consume-redeem:string (id:string)
    (enforce-keyset ORACLE)
    (let ((r (read redeem_approvals id)))
      (enforce (= (at "used" r) false) "already-used")
      (write redeem_approvals id
        {"id":id
         "account":(at "account" r)
         "amount":(at "amount" r)
         "bankref":(at "bankref" r)
         "exp":(at "exp" r)
         "used": true
         "ts": (now)})
      "ok"))

  (defun get-kyc:bool (acct:string) (is-kyc acct))
  (defun get-mint:any (id:string) (read mint_approvals id))
  (defun get-redeem:any (id:string) (read redeem_approvals id))
)