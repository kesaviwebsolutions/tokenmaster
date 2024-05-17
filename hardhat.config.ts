// import { HardhatUserConfig } from "hardhat/config";
// import "@nomicfoundation/hardhat-toolbox";

// const config: HardhatUserConfig = {
//   solidity: "0.8.24",
// };

// export default config;
import { vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const INFURA_API_KEY = vars.get("INFURA_API_KEY");
const HOLESKY_PRIVATE_KEY = vars.get("HOLESKY_PRIVATE_KEY");
const SEPOLIA_PVT_KEY = vars.get("SEPOLIA_PVT_KEY");
const BSCTESTNET_PVT_KEY = vars.get("BSCTESTNET_PVT_KEY");
const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");
const BSCSCAN_API_KEY = vars.get("BSCSCAN_API_KEY");

export default {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    holesky: {
      url: `https://holesky.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [HOLESKY_PRIVATE_KEY],
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PVT_KEY],
    },
    bsctestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [BSCTESTNET_PVT_KEY],
    },
    bscmainnet: {
      url: `https://bsc-dataseed2.binance.org/`,
      accounts: [BSCTESTNET_PVT_KEY],
    },
  },
  etherscan: {
    apiKey: {
      holesky: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      bscTestnet: BSCSCAN_API_KEY,
    },
  },
};
