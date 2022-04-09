import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";

let owner: SignerWithAddress;
let user1: SignerWithAddress;
let user2: SignerWithAddress;
let user3: SignerWithAddress;
let token: Contract;
let platform: Contract;
let decimals: number = 18;

describe("ACDMPlatform", function () {
  before(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();

    //create token
    const factoryToken = await ethers.getContractFactory("DimaERC20");
    token = await factoryToken.deploy("Dima ERC20 2022.04.09", "DIMA_220409", ethers.utils.parseUnits("100000.0", decimals));
    await token.deployed();

    //create platform
    const factoryPlatform = await ethers.getContractFactory("ACDMPlatform");
    //3 дня
    platform = await factoryPlatform.deploy(token.address, 3 * 24 * 60 * 60);
    await platform.deployed();

    await token.addPlatform(platform.address);
  });

  it("Test1", async function () {

    //в первом раунде продается 100 000 токенов
    await expect(await platform.mNumTokensForSale())
      .to.equal(100000);

  });


});
