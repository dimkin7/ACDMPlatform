import { ethers, config } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", owner.address);

  //deploy ERC20
  const factoryERC20 = await ethers.getContractFactory("DimaERC20");
  const token = await factoryERC20.deploy("Dima ERC20 2022.04.09", "DIMA_220409", 0);
  await token.deployed();
  console.log("DimaERC20:", token.address);
  const decimals = await token.decimals();

  //deploy Platform  
  const factoryPlatform = await ethers.getContractFactory("ACDMPlatform");
  //3 days
  const platform = await factoryPlatform.deploy(token.address, 3 * 24 * 60 * 60);
  await platform.deployed();
  console.log("ACDMPlatform:", platform.address);

  await token.addPlatform(platform.address);
}

// run
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
