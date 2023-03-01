const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploying
  const NFTmarketplace = await ethers.getContractFactory("NFTmarketplace");
  const instance = await upgrades.deployProxy(NFTmarketplace);
  await instance.deployed();

  // Upgrading
  const NFTmarketplaceV2 = await ethers.getContractFactory("NFTmarketplaceV2");
  console.log("NFTmarketplaceV2 deployed to:", instance.address);
}

main();