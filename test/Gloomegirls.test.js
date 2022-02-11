const { assert, expect } = require('chai');
const { BigNumber, Contract } = require('ethers');
const { ethers, web3 } = require("hardhat");
const Web3 = require('web3')

require('chai')
  .use(require('chai-as-promised'))
  .should()

let Gloomegirls;
let contract;
let accounts;

before(async () => {
  Gloomegirls = await ethers.getContractFactory("Gloomegirls");
  contract = await Gloomegirls.deploy("");
  accounts = await ethers.getSigners();
})

describe('deployment', async () => {
  it('deploys successfully', async () => {
    const address = contract.address
    assert.notEqual(address, '0x0')
    assert.notEqual(address, null)
    assert.notEqual(address, undefined)
    assert.notEqual(address, '')
  })

  it('has a name', async () => {
    const name = await contract.name()
    assert.equal(name, 'Gloomegirls')
  })

  it('has a symbol', async () => {
    const symbol = await contract.symbol()
    assert.equal(symbol, 'GEG')
  })
})

describe('minting', async () => {
  it('can mint 1 token', async () => {
    const { chainId: networkId } = await ethers.provider.getNetwork();
    const contractAddress = contract.address;
    const nonce = await ethers.provider.getTransactionCount(accounts[0].address, 'latest'); //get latest nonce
    //the transaction
    const tx = {
      'from': accounts[0].address,
      'to': contractAddress,
      'nonce': nonce,
      'gasLimit': 500000,
      // maxFeePerGas: new web3.utils.BN(web3.utils.toWei('250', 'gwei')),
      // maxPriorityFeePerGas: new web3.utils.BN(web3.utils.toWei('4', 'gwei')),
      'value': BigNumber.from(Web3.utils.toWei('.03', 'ether')).toHexString(),
      'data': contract.interface.encodeFunctionData('mint', []),
    };
    const result = await accounts[0].sendTransaction(tx);

    const totalSupply = await contract.totalSupply();
    // SUCCESS
    assert.equal(totalSupply, 1)
  })

  it('can mint 5 tokens', async () => {
    const contractAddress = contract.address;
    const nonce = await ethers.provider.getTransactionCount(accounts[0].address, 'latest'); //get latest nonce
    //the transaction
    const tx = {
      'from': accounts[0].address,
      'to': contractAddress,
      'nonce': nonce,
      'gasLimit': 500000,
      // maxFeePerGas: new web3.utils.BN(web3.utils.toWei('250', 'gwei')),
      // maxPriorityFeePerGas: new web3.utils.BN(web3.utils.toWei('4', 'gwei')),
      'value': BigNumber.from(Web3.utils.toWei('.15', 'ether')).toHexString(),
      'data': contract.interface.encodeFunctionData('mintMultiple', [5]),
    };
    const result = await accounts[0].sendTransaction(tx);

    const totalSupply = await contract.totalSupply();
    // SUCCESS
    assert.equal(totalSupply, 6)
  })

  it('account has balance of 6', async () => {
    const balance = await contract.balanceOf(accounts[0].address)

    for (let i = 0; i < balance; i++) {
      const token = await contract.tokenOfOwnerByIndex(accounts[0].address, i);
      const tokenURI = await contract.tokenURI(token.toNumber())
    }

    assert.equal(balance, 6, 'has 6 token balance');
  })
})

describe('withdraw', async () => {
  it('allows withdrawing all funds', async () => {
    await contract.withdrawAll();
  })
})

describe('reserve mints', async () => {
  it('allows reserving a set number of tokens', async () => {
    const prevSupply = await contract.totalSupply();

    await contract.reserveForOwner();

    const reserve = await contract.RESERVE();
    const totalSupply = await contract.totalSupply();

    assert.equal(totalSupply.toNumber(), reserve.toNumber() + prevSupply.toNumber(), 'total supply is equivalent to reserve + previous mint count');
  })

  it('reserve mints correctly generates different variations', async () => {
    const token2 = await contract.tokenOfOwnerByIndex(accounts[0].address, 1);
    const token3 = await contract.tokenOfOwnerByIndex(accounts[0].address, 2);

    assert.notEqual(token2, token3);
  })

  it('can\'t reserve twice', async () => {
    await expect(contract.reserveForOwner()).to.eventually.be.rejected
  })
})

describe('lock', async () => {
  it('can\'t lock', async () => {
    await expect(contract.lock()).to.eventually.be.rejected
  })

  // it('can lock', async () => {
  //   // todo: need to ensure all tokens are minted before attempting to lock, or it will fail
  //   await contract.lock();
  // })

  // it('cannot change baseuri after locking', async () => {
  //   // todo: need to ensure previous test to lock works so this will be rejected
  //   await expect(contract.setBaseURI('https://example.com')).to.eventually.be.rejected
  // })
})

describe('burn', async () => {
  it('can burn token', async () => {
    const prevTokenAtIndex2 = await contract.tokenOfOwnerByIndex(accounts[0].address, 2)

    await expect(contract.burn(prevTokenAtIndex2.toNumber())).to.eventually.be.fulfilled

    const newTokenAtIndex2 = await contract.tokenOfOwnerByIndex(accounts[0].address, 2)

    assert.notEqual(newTokenAtIndex2.toNumber(), prevTokenAtIndex2.toNumber())
  })

  it('burned token is no owned by account', async () => {
    const address = await contract.ownerOf(2) //

    console.log('token', address);
    assert.notEqual(address, accounts[0].address)
  })
})