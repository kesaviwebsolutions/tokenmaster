import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {

  // Deploying the LockFactory contract
  const beatFactory = m.contract("BEATFactory", []);

  return { beatFactory };
});

export default TokenModule;
