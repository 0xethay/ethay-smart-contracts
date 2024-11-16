// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntropyConsumer} from "./interfaces/IEntropyConsumer.sol";
import {IEntropy} from "./interfaces/IEntropy.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IVerifyWorldID} from "./interfaces/IVerifyWorldID.sol";

contract Ethay is IEntropyConsumer {
    struct Product {
        uint256 id;
        string name;
        uint256 price;
        uint256 quantity;
        bool isForSale;
        address seller;
        uint256 usdtBalance;
        string ipfsLink;
        string description;
    }

    struct Purchase {
        uint256 id;
        address buyer;
        uint256 quantity;
        uint256 totalPrice;
        bool isConfirmed;
        uint256 purchaseTime;
        bool isDisputed;
        address judge;
        address referrer;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => mapping(uint256 => Purchase)) public purchases;
    mapping(uint256 => uint256) public purchaseCountsPerProduct;
    uint256 public productCount;
    IERC20 public usdtToken;
    IVerifyWorldID public verifyWorldID;
    address[] public judgeList;
    mapping(address => bool) public isJudge;
    mapping(address => bool) public isSeller;
    mapping(address => uint256) public indexJudge;

    uint256 public constant CONFIRMATION_PERIOD = 14 days;
    uint256 public constant DISPUTE_PERIOD = 14 days;
    uint256 public constant REFERRAL_REWARD_PERCENT = 1; // 1% reward

    // Pythnetwork
    IEntropy entropy;
    uint64 callbackSequenceNumber;
    mapping(uint64 => TempDataPurchase) tempCallbackData;
    struct TempDataPurchase {
        uint256 _productId;
        uint256 _purchaseId;
    }

    // ref
    struct Referral {
        bool isActive;
        uint256 totalRewards;
    }
    mapping(address => Referral) public referrals;

    event ProductCreated(
        uint256 id,
        string name,
        uint256 price,
        uint256 quantity,
        address seller,
        string ipfsLink,
        string description
    );
    event ProductRemoved(uint256 id, string name, address seller);
    event PriceChanged(uint256 id, uint256 newPrice);
    event QuantityModified(uint256 id, uint256 newQuantity);
    event SaleStatusChanged(uint256 id, bool isForSale);
    event ProductPurchased(
        uint256 id,
        address buyer,
        uint256 quantity,
        uint256 totalPrice,
        uint256 purchaseId,
        address referrer
    );
    event PurchaseConfirmed(
        uint256 productId,
        uint256 purchaseId,
        bool isForcedConfirmation
    );
    event DisputeRaised(uint256 productId, uint256 purchaseId, address judge);
    event DisputeResolved(
        uint256 productId,
        uint256 purchaseId,
        uint256 buyerAmount,
        uint256 sellerAmount
    );
    event USDTWithdrawn(uint256 id, address seller, uint256 amount);
    event HumanVerified(address user);
    event JudgeAssigned(uint256 productId, uint256 purchaseId, address judge);
    event JudgeRegistered(address judge);
    event JudgeRemoved(address judge);
    event ReferralCodeActivated(address user);
    event ReferralCodeInActivated(address user);
    event ReferralRewardEarned(address referrer, uint256 amount);
    event ReferralRewardsWithdrawn(address user, uint256 amount);
    event SellerRegistered(address seller);
    event ProductMetadataUpdated(
        uint256 id,
        string name,
        string newIpfsLink,
        string newDescription
    );

    constructor(
        address _usdtTokenAddress,
        address _verifyWorldID,
        address _entropyAddress
    ) {
        usdtToken = IERC20(_usdtTokenAddress);
        verifyWorldID = IVerifyWorldID(_verifyWorldID);
        entropy = IEntropy(_entropyAddress);
    }

    modifier onlyHuman() {
        require(
            verifyWorldID.isVerifiedHuman(msg.sender),
            "World ID verification required"
        );
        _;
    }

    modifier onlyProductSeller(uint256 _id) {
        require(
            products[_id].seller == msg.sender,
            "Only product seller can call"
        );
        _;
    }
    modifier onlySeller() {
        require(isSeller[msg.sender] == true, "Only seller can call");
        _;
    }

    modifier isNotSeller() {
        require(isSeller[msg.sender] == false, "Only non-seller can call");
        _;
    }

    modifier onlyBuyer(uint256 _productId, uint256 _purchaseId) {
        require(
            purchases[_productId][_purchaseId].buyer == msg.sender,
            "Only buyer can call"
        );
        _;
    }

    modifier onlyAssignedJudge(uint256 _productId, uint256 _purchaseId) {
        require(
            purchases[_productId][_purchaseId].judge == msg.sender,
            "Only assigned judge can call"
        );
        _;
    }

    modifier isNotJudge() {
        require(isJudge[msg.sender] == false, "Only non-judge can call.");
        _;
    }

    modifier onlyJudge() {
        require(isJudge[msg.sender] == true, "Only judge can call.");
        _;
    }

    function registerAsSeller() public onlyHuman isNotJudge isNotSeller {
        isSeller[msg.sender] = true;
        emit SellerRegistered(msg.sender);
    }

    function registerAsJudge() public onlyHuman isNotJudge isNotSeller {
        isJudge[msg.sender] = true;
        indexJudge[msg.sender] = judgeList.length;
        judgeList.push(msg.sender);
        emit JudgeRegistered(msg.sender);
    }

    function removeYourselfFromJudge() public onlyJudge {
        uint256 index = indexJudge[msg.sender];
        judgeList[index] = judgeList[judgeList.length - 1];
        judgeList.pop();
        isJudge[msg.sender] = false;
        delete indexJudge[msg.sender];
        emit JudgeRemoved(msg.sender);
    }

    function activateReferralCode() public onlyHuman {
        require(
            !referrals[msg.sender].isActive,
            "Referral code already activated"
        );

        referrals[msg.sender] = Referral(true, 0);

        emit ReferralCodeActivated(msg.sender);
    }

    function createProduct(
        string memory _name,
        uint256 _price,
        uint256 _quantity,
        string memory _ipfsLink,
        string memory _description
    ) public onlySeller {
        require(_price > 0, "Price must be greater than zero");
        products[productCount] = Product(
            productCount,
            _name,
            _price,
            _quantity,
            true,
            msg.sender,
            0,
            _ipfsLink,
            _description
        );
        emit ProductCreated(
            productCount,
            _name,
            _price,
            _quantity,
            msg.sender,
            _ipfsLink,
            _description
        );
        productCount++;
    }

    function changePrice(
        uint256 _id,
        uint256 _newPrice
    ) public onlyProductSeller(_id) {
        require(_newPrice > 0, "Price must be greater than zero");
        products[_id].price = _newPrice;
        emit PriceChanged(_id, _newPrice);
    }

    function modifyQuantity(
        uint256 _id,
        uint256 _newQuantity
    ) public onlyProductSeller(_id) {
        require(_newQuantity >= 0, "Quantity cannot be negative");
        products[_id].quantity = _newQuantity;
        emit QuantityModified(_id, _newQuantity);
    }

    function toggleSaleStatus(uint256 _id) public onlyProductSeller(_id) {
        products[_id].isForSale = !products[_id].isForSale;
        emit SaleStatusChanged(_id, products[_id].isForSale);
    }

    function updateProductMetadata(
        uint256 _id,
        string memory _name,
        string memory _newIpfsLink,
        string memory _newDescription
    ) public onlyProductSeller(_id) {
        Product storage product = products[_id];
        product.name = _name;
        product.ipfsLink = _newIpfsLink;
        product.description = _newDescription;

        emit ProductMetadataUpdated(_id, _name, _newIpfsLink, _newDescription);
    }

    function buyProduct(
        address _buyer,
        uint256 _id,
        uint256 _quantity,
        address _referrer
    ) public {
        require(_id < productCount, "Invalid product ID");
        Product storage product = products[_id];
        require(product.seller != _buyer, "Cannot buy your own product");
        require(product.isForSale, "Product is not for sale");
        require(product.quantity >= _quantity, "Insufficient product quantity");

        uint256 totalPrice = product.price * _quantity;

        product.quantity -= _quantity;
        uint256 purchaseId = purchaseCountsPerProduct[_id]++;
        purchases[_id][purchaseId] = Purchase(
            purchaseId,
            _buyer,
            _quantity,
            totalPrice,
            false,
            block.timestamp,
            false,
            address(0),
            _referrer
        );
        require(
            usdtToken.transferFrom(msg.sender, address(this), totalPrice),
            "USDT transfer failed"
        );

        emit ProductPurchased(
            _id,
            _buyer,
            _quantity,
            totalPrice,
            purchaseId,
            _referrer
        );
    }

    function confirmPurchase(
        uint256 _productId,
        uint256 _purchaseId
    ) public onlyBuyer(_productId, _purchaseId) {
        Purchase storage purchase = purchases[_productId][_purchaseId];
        require(!purchase.isConfirmed, "Purchase already confirmed");
        require(!purchase.isDisputed, "Purchase is disputed");
        require(
            block.timestamp <= purchase.purchaseTime + CONFIRMATION_PERIOD,
            "Confirmation period has passed"
        );

        _confirmAndUpdateBalance(_productId, _purchaseId, false);
    }

    function forceConfirmPurchase(
        uint256 _productId,
        uint256 _purchaseId
    ) public onlyProductSeller(_productId) {
        Purchase storage purchase = purchases[_productId][_purchaseId];
        require(!purchase.isConfirmed, "Purchase already confirmed");
        require(!purchase.isDisputed, "Purchase is disputed");
        require(
            block.timestamp > purchase.purchaseTime + CONFIRMATION_PERIOD,
            "Confirmation period has not passed yet"
        );

        _confirmAndUpdateBalance(_productId, _purchaseId, true);
    }

    function _confirmAndUpdateBalance(
        uint256 _productId,
        uint256 _purchaseId,
        bool _isForced
    ) private {
        Purchase storage purchase = purchases[_productId][_purchaseId];
        purchase.isConfirmed = true;
        uint256 totalPrice = purchase.totalPrice;
        address _referrer = purchase.referrer;
        // Process referral
        if (referrals[_referrer].isActive && _referrer != msg.sender) {
            uint256 referralReward = (totalPrice * REFERRAL_REWARD_PERCENT) /
                100;
            referrals[_referrer].totalRewards += referralReward;
            totalPrice -= referralReward;
            emit ReferralRewardEarned(_referrer, referralReward);
        }

        products[_productId].usdtBalance += totalPrice;

        emit PurchaseConfirmed(_productId, _purchaseId, _isForced);
    }

    function resolveDispute(
        uint256 _productId,
        uint256 _purchaseId,
        uint256 _buyerAmount
    ) public onlyAssignedJudge(_productId, _purchaseId) {
        Purchase storage purchase = purchases[_productId][_purchaseId];
        require(purchase.isDisputed, "No dispute raised for this purchase");
        require(!purchase.isConfirmed, "Purchase already confirmed");

        uint256 sellerAmount = purchase.totalPrice - _buyerAmount;

        // Transfer amounts to buyer and seller
        require(
            usdtToken.transfer(purchase.buyer, _buyerAmount),
            "Transfer to buyer failed"
        );
        require(
            usdtToken.transfer(products[_productId].seller, sellerAmount),
            "Transfer to seller failed"
        );

        purchase.isConfirmed = true;
        purchase.isDisputed = false;

        emit DisputeResolved(
            _productId,
            _purchaseId,
            _buyerAmount,
            sellerAmount
        );
    }

    function raiseDispute(
        uint256 _productId,
        uint256 _purchaseId
    ) public payable onlyBuyer(_productId, _purchaseId) {
        Purchase storage purchase = purchases[_productId][_purchaseId];
        require(!purchase.isConfirmed, "Purchase already confirmed");
        require(!purchase.isDisputed, "Dispute already raised");
        require(
            block.timestamp <= purchase.purchaseTime + DISPUTE_PERIOD,
            "Dispute period has passed"
        );
        require(judgeList.length > 0, "Judge list empty");

        // Pythnetwork entropy
        address entropyProvider = entropy.getDefaultProvider();
        uint256 fee = entropy.getFee(entropyProvider);
        bytes32 userRandomNumber = keccak256(
            abi.encode(block.prevrandao, purchase.buyer, purchase.id)
        );
        callbackSequenceNumber = entropy.requestWithCallback{value: fee}(
            entropyProvider,
            userRandomNumber
        );
        // Store for find storage purchase in entropyCallback
        tempCallbackData[callbackSequenceNumber] = TempDataPurchase(
            _productId,
            _purchaseId
        );

        emit DisputeRaised(_productId, _purchaseId, purchase.judge);
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address,
        bytes32 randomNumber
    ) internal override {
        require(
            sequenceNumber == callbackSequenceNumber,
            "Invalid identify sequenceNumber"
        );

        TempDataPurchase memory tempData = tempCallbackData[sequenceNumber];
        Purchase storage purchase = purchases[tempData._productId][
            tempData._purchaseId
        ];
        delete tempCallbackData[sequenceNumber];

        uint256 judgeIndex = uint256(randomNumber) % judgeList.length;
        purchase.judge = judgeList[judgeIndex];
        purchase.isDisputed = true;
        emit JudgeAssigned(
            tempData._productId,
            tempData._purchaseId,
            purchase.judge
        );
    }

    function withdrawUSDT(uint256 _id) public onlyProductSeller(_id) {
        Product storage product = products[_id];
        uint256 amount = product.usdtBalance;
        require(amount > 0, "No USDT to withdraw");

        product.usdtBalance = 0;
        require(usdtToken.transfer(msg.sender, amount), "USDT transfer failed");
        emit USDTWithdrawn(_id, msg.sender, amount);
    }

    function withdrawReferralRewards() public onlyHuman {
        uint256 rewards = referrals[msg.sender].totalRewards;
        require(rewards > 0, "No rewards to withdraw");

        referrals[msg.sender].totalRewards = 0;
        require(
            usdtToken.transfer(msg.sender, rewards),
            "USDT transfer failed"
        );

        emit ReferralRewardsWithdrawn(msg.sender, rewards);
    }

    function getReferralRewards(address _user) public view returns (uint256) {
        return referrals[_user].totalRewards;
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function getJudgeCount() public view returns (uint256) {
        return judgeList.length;
    }
}
