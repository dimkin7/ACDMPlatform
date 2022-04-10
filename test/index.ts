import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract } from "ethers";
import { network } from "hardhat";

let owner: SignerWithAddress;
let user1: SignerWithAddress;
let user2: SignerWithAddress;
let user3: SignerWithAddress;
let token: Contract;
let platform: Contract;

describe("ACDMPlatform", function () {
  before(async function () {
    [owner, user1, user2, user3] = await ethers.getSigners();

    //create token
    const factoryToken = await ethers.getContractFactory("DimaERC20");
    token = await factoryToken.deploy("Dima ERC20 2022.04.09", "DIMA_220409", 0);
    await token.deployed();

    //create platform
    const factoryPlatform = await ethers.getContractFactory("ACDMPlatform");
    //3 дня
    platform = await factoryPlatform.deploy(token.address, 3 * 24 * 60 * 60);
    await platform.deployed();

    await token.addPlatform(platform.address);
  });

  it("Check balance", async function () {
    let balance = await ethers.provider.getBalance(platform.address);
    expect(balance).to.equal(0);
    balance = await ethers.provider.getBalance(user1.address);
    expect(ethers.utils.parseEther("10000")).to.equal(balance);
  });

  it("Register", async function () {
    await platform.connect(user1).register('0x0000000000000000000000000000000000000000');
    await platform.connect(user2).register(user1.address);
    await platform.connect(user3).register(user2.address);
  });



  it("Sale round 1 - prepare", async function () {
    await platform.startSaleRound();
    //в первом раунде продается 100 000 токенов
    expect(await platform.mNumTokensForSale())
      .to.equal(ethers.utils.parseEther("100000"));

    expect(await token.balanceOf(platform.address))
      .to.equal(ethers.utils.parseEther("100000"));

    expect(await platform.mPrice())
      .to.equal(ethers.utils.parseEther("0.00001"));
  });

  it("Sale round 1 - user1 - 100 tokens", async function () {
    //event BuyACDM(user, amount);
    await expect(platform.connect(user1).buyACDM({ value: ethers.utils.parseEther("0.001") }))
      .to.emit(platform, "BuyACDM")
      .withArgs(user1.address, ethers.utils.parseEther("100"));

    expect(await token.balanceOf(user1.address))
      .to.equal(ethers.utils.parseEther("100"));

    let balance = await ethers.provider.getBalance(platform.address);
    expect(balance).to.equal(ethers.utils.parseEther("0.001"));
  });

  it("Sale round 1 - user2 - 0,1 tokens", async function () {
    let user1_balance_before = await ethers.provider.getBalance(user1.address);

    await expect(platform.connect(user2).buyACDM({ value: ethers.utils.parseEther("0.000001") }))
      .to.emit(platform, "BuyACDM")
      .withArgs(user2.address, ethers.utils.parseEther("0.1"));

    expect(await token.balanceOf(user2.address))
      .to.equal(ethers.utils.parseEther("0.1"));

    let balance = await ethers.provider.getBalance(platform.address);
    expect(balance).to.equal(ethers.utils.parseEther("0.00100095"));

    let user1_balance_after = await ethers.provider.getBalance(user1.address);
    expect(user1_balance_after.sub(user1_balance_before)).to.equal(ethers.utils.parseEther("0.00000005"));
  });

  //buyACDM user1-3
  it("Sale round 1 - user3 - 5 tokens", async function () {
    let user1_balance_before = await ethers.provider.getBalance(user1.address);
    let platform_balance_before = await ethers.provider.getBalance(platform.address);

    await expect(platform.connect(user3).buyACDM({ value: ethers.utils.parseEther("0.00005") }))
      .to.emit(platform, "BuyACDM")
      .withArgs(user3.address, ethers.utils.parseEther("5"));

    expect(await token.balanceOf(user3.address))
      .to.equal(ethers.utils.parseEther("5"));

    let user1_balance_after = await ethers.provider.getBalance(user1.address);
    expect(user1_balance_after.sub(user1_balance_before)).to.equal(ethers.utils.parseEther("0.0000015"));
    let platform_balance_after = await ethers.provider.getBalance(platform.address);
    expect(platform_balance_after.sub(platform_balance_before)).to.equal(ethers.utils.parseEther("0.000046"));
  });

  ///********************
  it("Wait 3 days", async function () {
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 3]);
  });
  ///********************

  it("Trade round 1 user1 addOrder", async function () {
    await platform.startTradeRound();
    await token.connect(user1).approve(platform.address, ethers.utils.parseEther("100"));

    //event AddOrder(orderId, amount, price);
    await expect(platform.connect(user1).addOrder(ethers.utils.parseEther("100"), ethers.utils.parseEther("0.02")))
      .to.emit(platform, "AddOrder")
      .withArgs(1, ethers.utils.parseEther("100"), ethers.utils.parseEther("0.02"));
  });
  it("Trade round 1 user3 redeemOrder", async function () {
    //event RedeemOrder(user, orderId, amount);
    await expect(platform.connect(user3).redeemOrder(1, { value: ethers.utils.parseEther("0.03") }))
      .to.emit(platform, "RedeemOrder")
      .withArgs(user3.address, 1, ethers.utils.parseEther("1.5"));
  });

  it("Trade round 1 user1 removeOrder", async function () {
    //event RemoveOrder(orderId);
    await expect(platform.connect(user1).removeOrder(1))
      .to.emit(platform, "RemoveOrder")
      .withArgs(1);

    expect(await token.balanceOf(user1.address))
      .to.equal(ethers.utils.parseEther("98.5"));
  });

  ///********************
  it("Wait 3 days", async function () {
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 3]);
  });
  ///********************


  it("Sale round 2 - prepare", async function () {
    await platform.startSaleRound();

    expect(await platform.mPrice())
      .to.equal(ethers.utils.parseEther("0.0000143")); //цена токена в раунде 2 =	0,0000143

    // //в первом раунде продается 100 000 токенов
    // expect(await platform.mNumTokensForSale())
    //   .to.equal(ethers.utils.parseEther("100000"));

    // expect(await token.balanceOf(platform.address))
    //   .to.equal(ethers.utils.parseEther("100000"));

  });



  //user2 addOrder
  //Раунд может закончиться досрочно если все токены были распроданы. 
  //По окончанию раунда не распроданные токены сжигаются.
});

/*

Пример расчета:

объем торгов в trade раунде = 0,5 ETH (общая сумма ETH на которую пользователи наторговали в рамках одного trade раунд)

0,5 / 0,0000187 = 26737.96. (0,0000187 = цена токена в текущем раунде)

следовательно в Sale раунде будет доступно к продаже 26737.96 токенов ACDM.


Описание раунда «Trade»:

user_1 выставляет ордер на продажу ACDM токенов за определенную сумму в ETH. User_2 выкупает токены за ETH. Ордер может быть выкуплен не полностью. Также ордер можно отозвать и пользователю вернутся его токены, которые еще не были проданы. Полученные ETH сразу отправляются пользователю в их кошелек metamask. По окончанию раунда все открытые ордера закрываются и оставшиеся токены отправляются их владельцам.


Описание Реферальной программы:

При регистрации пользователь указывает своего реферера (Реферер должен быть уже зарегистрирован на платформе).

При покупке в Sale раунде токенов ACDM, рефереру_1 отправится 5% от его покупки, рефереру_2 отправится 3%, сама платформа получит 92% в случае отсутствия рефереров всё получает платформа.

При покупке в Trade раунде пользователь, который выставил ордер на продажу ACDM токенов получит 95% ETH и по 2,5% получат рефереры, в случае их отсутствия платформа забирает эти проценты себе.





Sale Round N	Price ETH
1	0,00001
2	0,0000143
3	0,0000187
4	0,0000233
5	0,000028
6	0,0000328

 */