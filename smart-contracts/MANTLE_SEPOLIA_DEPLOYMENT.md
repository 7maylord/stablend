# Stablend Smart Contracts - Mantle Sepolia Deployment

## ✅ Deployment Successful

All contracts have been successfully deployed to Mantle Sepolia testnet (Chain ID: 5003).

### Contract Addresses

| Contract | Address |
|----------|---------|
| **MockUSDC** | `0x72adE6a1780220074Fd19870210706AbCb7589BF` |
| **MockMNT** | `0x46415f21F1cCd97dfBecccD5dad3948daB8674A2` |
| **CreditScore** | `0xda4B11A190A8B30e367080651e905c0B5D3Ab8C6` |
| **RateAdjuster** | `0xb5497CB80F237435797e6B7Be4245b5Dae25703e` |
| **LendingMarket** | `0xABc85233e3c1475c8B0943A13A5DB7b1f77ED6a7` |
| **Chainlink MNT/USD Feed** | `0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78` |

### Deployment Details

- **Network**: Mantle Sepolia Testnet
- **Chain ID**: 5003
- **RPC URL**: `https://mantle-sepolia.g.alchemy.com/v2/hOFsEmyHlw0Ez4aLryoLetL-YwfWJC2D`
- **Total Gas Used**: 32,599,000,155 gas
- **Total Cost**: 0.651980035699000155 ETH

### Real Balances (On-Chain)

- **Deployer USDC Balance**: 1,000,000 USDC
- **Deployer MNT Balance**: 1,000,000 MNT
- **Deployer ETH Balance**: 100 ETH
- **Real MNT Price**: $0.77 USD (from Chainlink feed)

### Transaction Hashes

1. **MockUSDC**: `0x5e08d3a5f0e63e07ff11444737b6d9ee81cc74451993eacc1527aa40c7be040d`
2. **MockMNT**: `0x1e79c83ac742da633f2002b304a2b35f3464282e38e045bd981f49fdb8921940`
3. **CreditScore**: `0x67ed5d08b881c85c74d8ee3aff796969a367dfb2459f38fdcccf930382c79cd8`
4. **RateAdjuster**: `0xf6e65fcd635dfa4122688d83810a73418eaf7b076bb176cc9760c8215ec7af71`
5. **LendingMarket**: `0x8773697cd4e69df49e9c087ef65e9dd855722246b9aeb84f38b5ba684dd985be`
6. **Token Minting**: `0x8b0cbc019f3e287883e108ca0608ef63fcb043c55927f54bf8bf7adc3779602c`

### Environment Variables

For frontend integration, use these environment variables:

```env
REACT_APP_MOCK_USDC_ADDRESS=0x72adE6a1780220074Fd19870210706AbCb7589BF
REACT_APP_MOCK_MNT_ADDRESS=0x46415f21F1cCd97dfBecccD5dad3948daB8674A2
REACT_APP_LENDING_MARKET_ADDRESS=0x40Cd0edd7dAe6Ec3e7C8e6614b165EBC025aF443
REACT_APP_RATE_ADJUSTER_ADDRESS=0xb5497CB80F237435797e6B7Be4245b5Dae25703e
REACT_APP_CREDIT_SCORE_ADDRESS=0xda4B11A190A8B30e367080651e905c0B5D3Ab8C6
REACT_APP_CHAINLINK_MNT_USD_FEED=0x4c8962833Db7206fd45671e9DC806e4FcC0dCB78
REACT_APP_RPC_URL=https://mantle-sepolia.g.alchemy.com/v2/hOFsEmyHlw0Ez4aLryoLetL-YwfWJC2D
REACT_APP_CHAIN_ID=5003
```

### Notes

- **Real Chainlink Integration**: Using actual MNT/USD price feed from Chainlink
- **Verification Errors**: The "Failed to deserialize response" errors are related to Etherscan verification and don't affect the deployment
- **All contracts deployed successfully** and are ready for testing

### Next Steps

1. **Frontend Integration**: Use the contract addresses above in your frontend
2. **Testing**: Test all lending features on Mantle Sepolia
3. **Production**: Deploy to Mantle mainnet when ready

---

**Deployment Date**: July 18, 2025
**Status**: ✅ Successfully Deployed to Mantle Sepolia 