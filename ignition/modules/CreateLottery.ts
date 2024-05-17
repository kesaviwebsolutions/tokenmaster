import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Uint256 } from "web3";

const TokenModule = buildModule("TokenModule", (m) => {
    const startTime = Math.floor(Date.now() / 1000);
    const duration = 21;
    const token = "0x4169e624bB7200C00E55Ed526929bfE78B5348A6";
    const ticketPrice = 10;
    const decimals = 18;
    const maxTicketPerWallet = 100;
    const shares: number[] = [50, 30, 20]; // Array of shares
    const creatorFee = 20;

  // Deploying the Single Lottery contract
  const lotterySingle = m.contract("LotterySingle", [startTime, duration, token, ticketPrice, decimals, maxTicketPerWallet, shares, creatorFee]);

  return { lotterySingle };
});

export default TokenModule;
