import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {
    const _stableCoin = '0x4169e624bB7200C00E55Ed526929bfE78B5348A6';
    const  _name = 'Goa Resort';
    const  _symbol = 'GOAR';
    const _fundraisingGoal = 10000;
    const _contributionAmnt = 10;
    const _projectStartTime = Math.floor(Date.now() / 1000);
    const _maxSharesPerWallet = 100;
    const _projectOwner = '0xb71800bd9951e2F6d8F24987E32423F176F2847C';
    const _platformFee = 25;
    const _platformWallet = '0x4750A590318B197D8dEE9C24CDeE5Ac84c6B1D81';
    const _projectAPY = 10;

  // Deploying the Single Lottery contract
  const listingSingle = m.contract("BEATListings", [_stableCoin, _name, _symbol, _fundraisingGoal, _contributionAmnt, _projectStartTime, _maxSharesPerWallet, _projectOwner, _platformFee, _platformWallet, _projectAPY]);

  return { listingSingle };
});

export default TokenModule;
