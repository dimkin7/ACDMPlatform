// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//import "hardhat/console.sol"; //TODO delme
interface IACDM is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

contract ACDMPlatform is ReentrancyGuard {
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
    //orderId => order
    mapping(uint256 => Order) public orders;

    struct User {
        bool isValue;
        address addr;
    }
    //user => referrer
    mapping(address => User) public mReferrers;

    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
    //orders
    EnumerableSet.UintSet private mActiveOrdersSet;
    //orderId
    Counters.Counter private mOrderId;

    // >>> Events
    event StartSaleRound();
    //user, amount
    event BuyACDM(address, uint256);
    event StartTradeRound();
    //orderId, amount, price
    event AddOrder(uint256, uint256, uint256);
    //orderId
    event RemoveOrder(uint256);
    //user, orderId, amount
    event RedeemOrder(address, uint256, uint256);

    // <<< Events

    constructor(address ACDMToken, uint256 roundTime) {
        mRoundLength = roundTime;
        mACDMToken = IACDM(ACDMToken);

        //suppose it was Trade Round
        mRound = Round.TRADE;
        mTotalValueTradeRound = 1 ether;
    }

    //The referrer must already be registered on the platform
    //The first user sends address(0)
    function register(address referrer) external {
        if (referrer != address(0)) {
            require(mReferrers[referrer].isValue, "Referrer not registerted");
        }

        require(!mReferrers[msg.sender].isValue, "Already registerted");
        mReferrers[msg.sender] = User(true, referrer);
    }

    //referrer_1 will be sent  perc1/1000  of msg.value, referrer_2 will be sent  perc2/1000
    //decimals of perc1, perc2 = 1
    function _sendPercentToRef(uint256 perc1, uint256 perc2) internal {
        bool res;
        User memory ref1 = mReferrers[msg.sender];
        if (ref1.addr != address(0)) {
            (res, ) = ref1.addr.call{value: (msg.value * perc1) / 1000}("");
            require(res, "Failed to send to referrer 1");

            //ref2
            User memory ref2 = mReferrers[ref1.addr];
            if (ref2.addr != address(0)) {
                (res, ) = ref2.addr.call{value: (msg.value * perc2) / 1000}("");
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
    function startSaleRound() external {
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
        mNumTokensForSale = (mTotalValueTradeRound / mPrice) * 1e18;

        //mint tokens
        mACDMToken.mint(address(this), mNumTokensForSale);

        //remove orders
        for (uint256 i = 0; i < mActiveOrdersSet.length(); i++) {
            Order memory order = orders[i];
            delete orders[i];
            bool res = mACDMToken.transfer(order.owner, order.amount);
            require(res, "Tokens transfer error");
        }

        delete mActiveOrdersSet;
        emit StartSaleRound();
    }

    //User can buy ACDM tokens at a fixed price from the platform for ETH.
    function buyACDM() external payable nonReentrant {
        require(msg.value > 0, "ETH amount must be > 0");
        bool res;

        //calc amount of tokens
        uint256 amountToBuy = (msg.value / mPrice) * 1e18;

        require(mNumTokensForSale >= amountToBuy, "Not enough tokens");
        mNumTokensForSale -= amountToBuy;

        res = mACDMToken.transfer(msg.sender, amountToBuy);
        require(res, "Failed to transfer tokens");

        //referrer_1 will be sent 5% of his purchase, referrer_2 will be sent 3%.
        _sendPercentToRef(50, 30);

        emit BuyACDM(msg.sender, amountToBuy);
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
            mNumTokensForSale = 0;
        }
        //for calc total ETH value
        mTotalValueTradeRound = 0;

        emit StartTradeRound();
    }

    function addOrder(uint256 amount, uint256 price) external {
        bool res = mACDMToken.transferFrom(msg.sender, address(this), amount);
        require(res, "Tokens transfer error");

        //get new order ID
        mOrderId.increment();
        uint256 curOrderId = mOrderId.current();

        //remember id
        mActiveOrdersSet.add(curOrderId);

        Order storage newOrder = orders[curOrderId];
        newOrder.owner = msg.sender;
        newOrder.amount = amount;
        newOrder.price = price;

        emit AddOrder(curOrderId, amount, price);
    }

    //remove order id
    function removeOrder(uint256 orderId) external {
        Order memory order = orders[orderId];
        require(order.owner == msg.sender, "You aren't an owner");

        delete orders[orderId];
        //remove id
        mActiveOrdersSet.remove(orderId);

        bool res = mACDMToken.transfer(order.owner, order.amount);
        require(res, "Tokens transfer error");

        emit RemoveOrder(orderId);
    }

    function redeemOrder(uint256 orderId) external payable nonReentrant {
        require(msg.value > 0, "ETH amount must be > 0");
        bool res;
        Order storage order = orders[orderId];

        //calc amount of tokens
        uint256 amountToBuy = (msg.value / order.price) * 1e18;

        require(order.amount >= amountToBuy, "Not enough tokens");
        order.amount -= amountToBuy;

        //remove order from active if it's all sold
        if (order.amount == 0) {
            mActiveOrdersSet.remove(orderId);
        }

        //calc total volume
        mTotalValueTradeRound += msg.value;

        res = mACDMToken.transfer(msg.sender, amountToBuy);
        require(res, "Failed to transfer tokens");

        //owner of order will receive 95% ETH
        (res, ) = order.owner.call{value: (msg.value * 95) / 100}("");
        require(res, "Failed to send to owner");

        //referrers get 2,5 percent
        _sendPercentToRef(25, 25);

        emit RedeemOrder(msg.sender, orderId, amountToBuy);
    }
    //<<< Trade round
}
