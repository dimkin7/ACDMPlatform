// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "hardhat/console.sol"; //TODO delme
interface IACDM is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

contract ACDMPlatform {
    IACDM public mACDMToken;
    enum Round {
        SALE,
        TRADE
    }
    Round public mRound;
    uint256 public mRoundLength;
    uint256 public mRoundStartedTime;
    uint256 public mPrice; //Price of ACDM in Wei
    uint256 public mNumTokensForSale; //Number ACDM tokens to sale in Sale round
    uint256 public mTotalValueTradeRound; //Value in ETH traded in Trade round

    struct Order {
        uint256 amount;
        uint256 price;
        address owner;
    }
    Order[] public orders;

    struct User {
        bool isValue;
        address addr;
    }
    //user => referrer
    mapping(address => User) public mReferrers;

    //user, amount
    event BuyACDM(address, uint256);

    constructor(address ACDMToken, uint256 roundTime) {
        mRoundLength = roundTime;
        mACDMToken = IACDM(ACDMToken);

        //suppose it was Trade Round
        mRound = Round.TRADE;
        mTotalValueTradeRound = 1 ether;

        //starting from Sale round
        startSaleRound();
    }

    //The referrer must already be registered on the platform
    //The first user sends address(0)
    function register(address referrer) external {
        require(!mReferrers[msg.sender].isValue, "Already registerted");
        mReferrers[msg.sender] = User(true, referrer);
    }

    //referrer_1 will be sent  perc1/1000  of msg.value, referrer_2 will be sent  perc2/1000
    //decimals of perc1, perc2 = 1
    function _sendPercentToRef(uint256 perc1, uint256 perc2) internal {
        bool res;
        User memory ref1 = mReferrers[msg.sender];
        if (ref1.addr != address(0)) {
            (res, ) = ref1.addr.call{value: (msg.value * perc1) / 1000}(""); //TODO re-entrancy guard
            require(res, "Failed to send to referrer 1");

            //ref2
            User memory ref2 = mReferrers[ref1.addr];
            if (ref2.addr != address(0)) {
                (res, ) = ref2.addr.call{value: (msg.value * perc2) / 1000}(""); //TODO re-entrancy guard
                require(res, "Failed to send to referrer 2");
            }
        }
    }

    function _roundPrepare(Round newRound) internal {
        require(mRound != newRound, "The round is already active");
        mRound = newRound;
        mRoundStartedTime = block.timestamp;
    }

    //Sale round >>>
    function startSaleRound() public {
        require(
            block.timestamp - mRoundStartedTime >= mRoundLength,
            "Wait more time"
        );
        _roundPrepare(Round.SALE);

        //Price ETH = lastPrice*1,03+0,000004
        if (mPrice == 0) {
            //The first round sells tokens worth 1ETH (100 000 ACDM)
            mPrice = 10000000000000; //Ether  0.00001
        } else {
            mPrice = ((mPrice * 103) / 100) + 4000000000000;
        }

        //calc mNumTokensForSale
        //The number of issued tokens in each Sale round is different and depends on the total volume of trades in the Trade round.
        mNumTokensForSale = mTotalValueTradeRound / mPrice;

        //redeem orders //TODO
        for (uint256 i = 0; i < orders.length; i++) {
            //TODO цикл
            orders[i]; //TODO
        }
        delete orders;
    }

    //User can buy ACDM tokens at a fixed price from the platform for ETH.
    function buyACDM() external payable {
        //bool res;

        require(mRound == Round.SALE, "Not a Sale round");
        require(msg.value > 0, "ETH amount must be > 0");
        //calc amount of tokens
        uint256 amount = msg.value / mPrice;
        mACDMToken.transfer(msg.sender, amount);

        //referrer_1 will be sent 5% of his purchase, referrer_2 will be sent 3%.
        _sendPercentToRef(50, 30);

        emit BuyACDM(msg.sender, amount);
    }

    //<<< Sale round

    //>>> Trade round
    //Users can redeem ACDM tokens from each other for ETH.
    function startTradeRound() external {
        //The Sale round may end early if all tokens have been sold out.
        require(
            mNumTokensForSale == 0 ||
                block.timestamp - mRoundStartedTime >= mRoundLength,
            "Wait more time"
        );
        _roundPrepare(Round.TRADE);

        //At the end of the Sale round unsold tokens are burned.
        if (mNumTokensForSale > 0) {
            mACDMToken.burn(address(this), mNumTokensForSale);
        }
        mTotalValueTradeRound = 0;
    }

    function addOrder(uint256 amount, uint256 price)
        external
        returns (uint256)
    {
        bool res = mACDMToken.transferFrom(msg.sender, address(this), amount);
        require(res, "Tokens transfer error");

        Order memory newOrder;
        newOrder.owner = msg.sender;
        newOrder.amount = amount;
        newOrder.price = price;
        orders.push(newOrder);

        return orders.length - 1;
    }

    function removeOrder() external {}

    function redeemOrder(uint256 id) external payable {
        bool res;
        // и по 2,5% получат рефереры,
        //в случае их отсутствия платформа забирает эти проценты себе.

        Order storage curOrder = orders[id]; //TODO storage vs memory

        //owner of order will receive 95% ETH
        (res, ) = curOrder.owner.call{value: (msg.value * 95) / 100}(""); //TODO re-entrancy guard
        require(res, "Failed to send to owner");

        //referrers get 2,5 percent
        _sendPercentToRef(25, 25);
    }
    //<<< Trade round
}
/*

Описание раунда «Trade»:
user_1 выставляет ордер на продажу ACDM токенов за определенную сумму в ETH. User_2 выкупает токены за ETH. 
Ордер может быть выкуплен не полностью. Также ордер можно отозвать и пользователю вернутся его токены, которые еще не были проданы. 
Полученные ETH сразу отправляются пользователю в их кошелек metamask. 
По окончанию раунда все открытые ордера закрываются и оставшиеся токены отправляются их владельцам.








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



 */
