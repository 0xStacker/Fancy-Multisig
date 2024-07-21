A multisig wallet with fancy features. hard limit for participating wallets is 20, soft limit and required signatures can be adjusted within this range.

QUICK BREAKDOWN

- The admin is set on deployment (NB: admin is not the deployer)
- Admin is deemed the original creator of the multisig
- Can add new wallets to the multisig provided soft or hard limits are not reached ( requires a unanimous vote from all active members)
- Can kick a member address out of the multisig (requires a unanimous vote from all active members)
- Can adjust the number of required signatures for transaction execution (requires a unanimous vote from all members)
- All members can propose a transaction
- Each proposed transaction goes to pending until executed or rejected
- A proposed transaction is executed IFF the required signature is reached
