import { ethers } from 'hardhat';

async function main() {
  const Token = await ethers.getContractFactory("CATSAIDMEOW");
  try {
    const token = await Token.deploy("CATSAIDMEOW", "CAT", "1000000000000", "0x49b7275f16534C67B859eb33d08da3AfC0618D61");
    await token.deployed();
    console.log("Token deployed to:", token.address);
  } catch (error) {
    console.error("Deployment failed:", error);
  }
}

main().catch((error) => {
  console.error("Unhandled error:", error);
  process.exit(1);
});
