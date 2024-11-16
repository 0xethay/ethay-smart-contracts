import { ethers } from 'hardhat'

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log(
    'Account balance:',
    (await deployer.provider.getBalance(deployer.address)).toString()
  )

  // 0. Deploy USDT
  console.log('\nDeploying USDT...')
  // const USDT = await ethers.getContractFactory('Token')
  const initialSupply = ethers.parseEther('1000000') // 1 million USDT
  // const usdt = await USDT.deploy(initialSupply)
  // await usdt.waitForDeployment()
  const usdt = await ethers.getContractAt(
    'Token',
    '0x28aD5A6F6592Eaa2DaAf6d01c5Bcf71E0092dAf4'
  )
  console.log('USDT deployed to:', await usdt.getAddress())

  // 1. Deploy WorldID
  console.log('\nDeploying WorldID...')
  const WorldID = await ethers.getContractFactory('VerifyWorldID')
  const worldID = await WorldID.deploy(
    '0x42FF98C4E85212a5D31358ACbFe76a621b50fC02', // World ID Router Base Sepolia
    process.env.APP_ID || '',
    process.env.ACTION_ID || ''
  )
  await worldID.waitForDeployment()
  // const worldID = await ethers.getContractAt(
  //   'VerifyWorldID',
  //   ''
  // )
  console.log('WorldID deployed to:', await worldID.getAddress())

  // 2. Deploy Ethay
  console.log('\nDeploying Ethay...')
  const Ethay = await ethers.getContractFactory('Ethay')
  const ethay = await Ethay.deploy(
    await usdt.getAddress(),
    await worldID.getAddress(),
    '0x41c9e39574f40ad34c79f1c99b66a45efb830d4c' // Entropy Address Base Sepolia
  )
  await ethay.waitForDeployment() 
  console.log('Ethay deployed to:', await ethay.getAddress())

  // 3. Deploy Receiver
  console.log('\nDeploying CCIP Receiver...')
  const Receiver = await ethers.getContractFactory('Receiver')
  const receiver = await Receiver.deploy(
    '0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93', // router ccip base
    await usdt.getAddress(),
    await ethay.getAddress()
  )
  await receiver.waitForDeployment()
  console.log('CCIP Receiver deployed to:', await receiver.getAddress())

  // Print all addresses for verification
  console.log('\nDeployed Contracts:')
  console.log('------------------')
  console.log('USDT:', await usdt.getAddress())
  console.log('WorldID:', await worldID.getAddress())
  console.log('Ethay:', await ethay.getAddress())
  console.log('CCIP Receiver:', await receiver.getAddress())

  // Print deployment information for verification
  console.log('\nVerification Information:')
  console.log('------------------')
  console.log('USDT Constructor Arguments:', [initialSupply.toString()])
  console.log('WorldID Constructor Arguments:', [
    '0x42FF98C4E85212a5D31358ACbFe76a621b50fC02', // World ID Router Base Sepolia
    process.env.APP_ID,
    process.env.ACTION_ID,
  ])
  console.log('Ethay Constructor Arguments:', [
    await usdt.getAddress(),
    await worldID.getAddress(),
    '0x41c9e39574f40ad34c79f1c99b66a45efb830d4c', // Entropy Address Base Sepolia
  ])
  console.log('CCIP Receiver Constructor Arguments:', [
    '0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93', // router ccip base
    await usdt.getAddress(),
    await ethay.getAddress(),
  ])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
