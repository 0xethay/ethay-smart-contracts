import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'

dotenv.config()

const deployer = process.env.DEPLOYER_PRIVATE_KEY || ''

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
    // settings: {
    //   optimizer: {
    //     enabled: true,
    //     runs: 200,
    //   },
    // },
  },
  networks: {
    baseTestnet: {
      url: 'https://sepolia.base.org',
      chainId: 84532,
      accounts: [deployer],
    },
    sepoliaETH: {
      url: 'https://eth-sepolia.public.blastapi.io',
      chainId: 11155111,
      accounts: [deployer],
    },
    scrollSepolia: {
      url: 'https://sepolia-rpc.scroll.io',
      chainId: 534351,
      accounts: [deployer],
    },
    lineaSepolia: {
      url: 'https://linea-sepolia.blockpi.network/v1/rpc/public',
      chainId: 59141,
      accounts: [deployer],
    },
  },
  sourcify: {
    enabled: true,
  },
}

export default config
