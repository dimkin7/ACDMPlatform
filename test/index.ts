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
    expect(ethers.utils.parseEther("0.0")).to.equal(balance);
    balance = await ethers.provider.getBalance(user1.address);
    expect(ethers.utils.parseEther("10000.0")).to.equal(balance);
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
      .to.equal(ethers.utils.parseEther("100000.0"));

    expect(await token.balanceOf(platform.address))
      .to.equal(ethers.utils.parseEther("100000.0"));

    expect(await platform.mPrice())
      .to.equal(ethers.utils.parseEther("0.00001"));
  });

  it("Sale round 1 - user1 - 100 tokens", async function () {
    //event BuyACDM(address, uint256);
    await expect(platform.connect(user1).buyACDM({ value: ethers.utils.parseEther("0.001") }))
      .to.emit(platform, "BuyACDM")
      .withArgs(user1.address, ethers.utils.parseEther("100.0"));

    expect(await token.balanceOf(user1.address))
      .to.equal(ethers.utils.parseEther("100.0"));

    let balance = await ethers.provider.getBalance(platform.address);
    expect(ethers.utils.parseEther("0.001")).to.equal(balance);
  });

  //buyACDM user1-3

  ///********************
  it("Wait 3 days", async function () {
    await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 3]);
  });
  ///********************

  it("Trade round 1", async function () {
    await platform.startTradeRound();

    //user1 addOrder
    //user1 removeOrder
    //user2 addOrder

    //user3 redeemOrder

  });


  //startSaleRound

});

/*
Есть 2 раунда «Торговля» и «Продажа», которые следуют друг за другом, начиная с раунда продажи.

Каждый раунд длится 3 дня.

Основные понятия:

Раунд «Sale» - В данном раунде пользователь может купить токены ACDM по фиксируемой цене у платформы за ETH.

Раунд «Trade» - в данном раунде пользователи могут выкупать друг у друга токены ACDM за ETH.

Реферальная программа — реферальная программа имеет два уровня, пользователи получают реварды в ETH.

Описание раунда «Sale»:

Цена токена с каждым раундом растет и рассчитывается по формуле (смотри excel файл). Количество выпущенных токенов в каждом Sale раунде разное и зависит от общего объема торгов в раунде «Trade». Раунд может закончиться досрочно если все токены были распроданы. По окончанию раунда не распроданные токены сжигаются. Самый первый раунд продает токенны на сумму 1ETH (100 000 ACDM)

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

Price ETH = lastPrice*1,03+0,000004

Пример расчета цены токена: 0,0000100*1,03+0,000004 = 0,0000143


Sale Round N	Price ETH
1	0,00001
2	0,0000143
3	0,0000187
4	0,0000233
5	0,000028
6	0,0000328

 */