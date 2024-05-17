import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {

  // Deploying the LockFactory contract
  const lotteryFactory = m.contract("LotteryFactory", []);

  return { lotteryFactory };
});

export default TokenModule;
