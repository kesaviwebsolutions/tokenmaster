import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {
  // Hardcoded parameters
  const Name: string = "CATSAIDMEOW";
  const Symbol: string = "CAT";
  const Supply = 1000000000000;
  const Receiver = "0x49b7275f16534C67B859eb33d08da3AfC0618D61";

  // Deploying the CATSAIDMEOW contract
  const catsaidmeow = m.contract("CATSAIDMEOW", [Name, Symbol, Supply, Receiver]);

  return { catsaidmeow };
});

export default TokenModule;
