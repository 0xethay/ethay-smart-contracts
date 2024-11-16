import { ethers } from 'hardhat'

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log(
    'Account balance:',
    (await deployer.provider.getBalance(deployer.address)).toString()
  )

  // 0. Deploy USDT
  // console.log('\nDeploying USDT...')
  const USDT = await ethers.getContractFactory('Token')
  const initialSupply = ethers.parseEther('1000000') // 1 million USDT
  // const usdt = await USDT.deploy(initialSupply)
  // await usdt.waitForDeployment()
  const usdt = await ethers.getContractAt(
    'Token',
    '0x28aD5A6F6592Eaa2DaAf6d01c5Bcf71E0092dAf4'
  )
  console.log('USDT deployed to:', await usdt.getAddress())

  // 1. Deploy Sender
  console.log('\nDeploying CCIP Sender...')
  const Sender = await ethers.getContractFactory('Sender')
  const sender = await Sender.deploy(
    '0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59', // router Sepolia
    '0x779877A7B0D9E8603169DdbD7836e478b4624789', // link Sepolia
    await usdt.getAddress()
  )
  console.log('CCIP Sender deployed to:', await sender.getAddress())

  // 2. Send link token Ethay
  console.log('\GET Link Token...')
 const LinkToken = await ethers.getContractAt(
   'Token',
   '0x779877A7B0D9E8603169DdbD7836e478b4624789' // link Sepolia
 )
 console.log('Link Token deployed to:', await LinkToken.getAddress())
 console.log('send Link Token to Sender...')
 const tx = await LinkToken.connect(deployer).transfer(
   await sender.getAddress(),
   ethers.parseEther('20') //10 link
 )
 console.log('tx:', tx.hash)
   

  // Print all addresses for verification
  console.log('\nDeployed Contracts:')
  console.log('------------------')
  console.log('USDT:', await usdt.getAddress())
  console.log('CCIP Sender:', await sender.getAddress())
 

  // Print deployment information for verification
  console.log('\nVerification Information:')
  console.log('------------------')
  console.log('USDT Constructor Arguments:', [initialSupply.toString()])
  console.log('CCIP Receiver Constructor Arguments:', [
    '0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59', // router Sepolia
    '0x779877A7B0D9E8603169DdbD7836e478b4624789', // link Sepolia
    await usdt.getAddress(),
  ])
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
