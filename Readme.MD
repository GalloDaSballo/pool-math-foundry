## Fork OP
forge test --fork-url https://opt-mainnet.g.alchemy.com/v2/KEY

## Collecting Data

forge test --fork-url https://opt-mainnet.g.alchemy.com/v2/KEY -vv

Remember to use `-vv` (only 2) so you only see logs from us


## Velo test
forge test --match-contract VeloStable --fork-url https://opt-mainnet.g.alchemy.com/v2/KEY -vv

## CURVE TESTS
forge test --match-contract CurveStable --fork-url https://opt-mainnet.g.alchemy.com/v2/KEY -vv


## BAL TESTS
forge test --match-contract BalancerStable --fork-url https://opt-mainnet.g.alchemy.com/v2/KEY -vv
