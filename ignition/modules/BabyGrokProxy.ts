import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {

    const implementation = "0xFfbe2Aa41b9278514252E635E88119B67A329c3b";
  // Deploying the Proxy contract
  const BabyGrokProxy = m.contract("BabyGrokAffiliateProxy", [implementation]);

  return { BabyGrokProxy };
});

export default TokenModule;
