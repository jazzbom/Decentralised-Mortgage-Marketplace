// SPDX-License-Identifier: Ne07799
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./BNFT.sol";
/**
*Author Jay Bhosle
*CreatedDate April 2021 v1.01
**/
contract Ne0779 is ReentrancyGuardUpgradeable {
   
    bool public paused;
    BNFT public nft;
    string public name;
    string public symbol;
    address payable public owner;
    string public propertyDetailsHash;
    address payable public platformOwner;
    address payable public seller;
    bool public isSellerSigned;
    string public baseCurrency;
    //stored in wei
    uint256 public contractTreasuryBalance;
    uint256 public dateOfBirth;
    uint256 public latestExchangeRate;
    /**
     * Status Definations:
     * 
     **/
    uint256 public post_winning_mortgagee_bid_expiryInDays;
    uint256 public status;
    uint256 public salePriceInBaseCurrency;
    uint256 public fundingPoolSum;
    uint256 public outStandingBalanceOfPayment;
    uint256 public buyerPaidSumInBaseCurrency;
    uint256 public mortgageBidExpiryTime;
    string private uniquePostBidAccessKeyForMortgagees;
    address public owningBuyer;
    address[] public mortgagees;
    uint256[] public tokenIdArray;
    
    //Bidding buyers stored as eth value.
    mapping (address => uint256) public biddersDeposit;
    
    mapping (address => uint256) public removedMortgagees;
    
    //Stores owners shareholding in percentage * 100
    mapping (address => uint256) public ownershipSize;
    
    //Stores mortgagees investment in ETH 
    mapping (address => uint256) public mortgageesBalance;
    
    mapping (address => uint256) public mortgageesOwnershipSize;
    
    mapping (uint256 => address) public nftHolders;

    event log(string msg, uint256 value);
    event logAddress(address sendersAddress, string msg, uint256 value);
    event logUnauthorisedDepositReceived(address _address, uint256 value);
    
    struct TermSheet {
        uint256 rateOfInterest; //in decimal form i.e 50% = 0.50
        string interestType;
        uint256 repaymentBeginDate;
    }
    
    TermSheet public termSheet;

    function initialize(BNFT nftContractAddr,
        string memory nameOfContract,
        string memory symbolOfContract,
        string memory currencyName,
        uint256 salePrice,
        address payable sellerAddress,
        uint256 rateOfInterest,
        string memory interestType,
        address payable setPlatformOwner) public initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        nft = nftContractAddr;    
        owner = payable(msg.sender);    
        name = nameOfContract;
        symbol = symbolOfContract;
        dateOfBirth = block.timestamp;
        baseCurrency = currencyName;
        salePriceInBaseCurrency = newFixed(salePrice);
        status = 0;
        seller = sellerAddress;
        termSheet = TermSheet(rateOfInterest, interestType, 0);
        platformOwner = setPlatformOwner;
        post_winning_mortgagee_bid_expiryInDays = 1;
    }
    
    modifier isOwner(){
        require(owner == msg.sender);
        _;
    }
    
    modifier isPlatformOwner(){
        require(platformOwner == msg.sender);
        _;
    }
    
    modifier isSeller(){
        require(seller == msg.sender);
        _;
    }
    
    function setPaused(bool _paused) public isOwner {
        require(msg.sender == owner, "You are not the owner");
        paused = _paused;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    function getUniquePostBidAccessKeyForMortgagees() public isPlatformOwner view returns (string memory) {
        require(paused == false, "Contract is paused.");
        return uniquePostBidAccessKeyForMortgagees;
    }
    
    function setPropertyDetailsHash(string memory hashLine) public isOwner  {
        propertyDetailsHash = hashLine;
    }
    
    //Remove and use chainlink data price feed.
    function setLatestExchangeRate(uint256 value) public isOwner {
        latestExchangeRate = newFixed(value);
    }
    
    function setSalePriceInBaseCurrency(uint256 salePrice) public isOwner {
        require(status <= 1, "Sale price can only be updated at status Zero(0) or Open(1).");
        salePriceInBaseCurrency = newFixed(salePrice);
    }
    
    function getLatestExchangeRate() public view returns (uint256){
        return latestExchangeRate;
    }
    
    function setPostWinningMortgageeBidExpiryInDays(uint256 dayValue) public isOwner isPlatformOwner {
        post_winning_mortgagee_bid_expiryInDays = dayValue;
    }
    
    function setSeller(address payable sellerAddress) public isOwner {
        require(isSellerSigned == false, "Cannot update as seller has approved the contract.");
        seller = sellerAddress;
    }
    
    function approveContractAsASeller() public isSeller {
        require(paused == false, "Contract is paused.");
        isSellerSigned = true;
    }
    
    function latestPriceInBaseCurrency(uint256 weiVal) public view returns (uint256) {
        //exchange conversion to baseCurrency
        uint256 prod = weiVal * getLatestExchangeRate(); //convert eth to basecurrency value.
        uint256 baseCurrencyVal = prod / (10**18);
        return baseCurrencyVal;
    }
    
    function convertBaseToWei(uint256 basecurrency) public view returns (uint256) {
        uint256 etherPaymentValue = basecurrency / getLatestExchangeRate();
        uint256 weiPaymentValue = etherPaymentValue * 1 ether;
        return weiPaymentValue;
    }
    
    function depositAsBidder() public payable {
       require(paused == false, "Contract is paused.");
       require(msg.value > 0, "A bid value must be greater than zero.");
       owningBuyer = msg.sender;
       uint currentDeposit = biddersDeposit[owningBuyer];
       biddersDeposit[owningBuyer] = currentDeposit + msg.value;
       contractTreasuryBalance = contractTreasuryBalance + msg.value;
       status = 1;
       emit logAddress(msg.sender, "depositAsBidder", msg.value);
    }
    
    /**
     * Open the sale for mortgage auction
     **/
    function openForMortgageFunding(uint expirytimeInEpoch, string memory uniqueKeyForMortgageesAccess) public isOwner {
        require(isSellerSigned == true, "Seller has not approved the contract.");
        require(status == 1 && status != 3, "Contract status must be OPEN and must not already be FUNDING to begin Mortgage bid auction.");
        
        uint256 bidDepositValue = biddersDeposit[owningBuyer];
        
        uint baseCurrencyDeposit = latestPriceInBaseCurrency(bidDepositValue);
        uint balanceOfPaymentForBidderInBaseCurrency = salePriceInBaseCurrency - baseCurrencyDeposit;
        
        require(balanceOfPaymentForBidderInBaseCurrency > 0, "No mortgage needed as the bid value covers the full sale price.");
        // set status to FUNDING 
        status = 3;
        //expiry time
        mortgageBidExpiryTime = expirytimeInEpoch;
        uniquePostBidAccessKeyForMortgagees = uniqueKeyForMortgageesAccess; //enables access for the winning mortgagees to fund at the end of the auction.
        emit log("openForMortgageFunding with expiry", expirytimeInEpoch);
    }
    
    function fundAsMortgagee(string memory uniqueAccessKey) public payable nonReentrant {
        require(paused == false, "Contract is paused.");
        require(msg.value > 0, "Investment value must be higher than zero.");
        require(block.timestamp > mortgageBidExpiryTime, "Request for mortgage bid auction has not ended yet.");
        
        //allow mortgages to be funded only for the set number of days
        uint mortgageCrowdFundEndTime = mortgageBidExpiryTime + (post_winning_mortgagee_bid_expiryInDays * 1 days);
        require(mortgageCrowdFundEndTime >= block.timestamp, "Mortgage investment window has expired.");
        
        require(keccak256(abi.encodePacked(uniquePostBidAccessKeyForMortgagees)) == keccak256(abi.encodePacked(uniqueAccessKey)),
        "UnAuthorised. Only winning bids allowed to deposit funds.");
        
        uint valueInbaseCurrency = latestPriceInBaseCurrency(msg.value);
        
        uint latestFundingPoolSumInBaseCurrency = latestPriceInBaseCurrency(fundingPoolSum);
        require(latestFundingPoolSumInBaseCurrency <= salePriceInBaseCurrency, "No space for new investment as funding has reach 100%");
        require(valueInbaseCurrency <= salePriceInBaseCurrency, "Investment value as priced in base currency must be lower or equal to sale price.");
        uint256 mortgageeBalance = mortgageesBalance[msg.sender];
        mortgageesBalance[msg.sender] = mortgageeBalance + msg.value;
        mortgagees.push(msg.sender);
        fundingPoolSum = fundingPoolSum + msg.value;
        contractTreasuryBalance = contractTreasuryBalance + msg.value;
        emit logAddress(msg.sender, "fundAsMortgagee", msg.value);
    }
    
    /**
     * Enables owner to kickout bad/manupulating mortgagees
     * **/
    function removeMortgagee(address payable addrsToRemove) public isOwner nonReentrant {
        require(status == 3, "Addresses must not be empty.");
        uint investmentWei = mortgageesBalance[addrsToRemove];
        mortgageesBalance[addrsToRemove] = 0;
        addrsToRemove.transfer(investmentWei);
        (bool success, ) = addrsToRemove.call{value:investmentWei}("");
        require(success, "removeMortgagee failed at transfer");
        emit logAddress(addrsToRemove, "removeMortgagee", 0);
    } 
        
    function calculateOwnerShipPercent(uint256 valueInBaseCurrency, uint256 againstValInBaseCurrency) private pure returns (uint256) {
        uint256 prod = valueInBaseCurrency * fixed2();
        return prod / againstValInBaseCurrency;
    }    
        
    function initializeNewState(uint256 statusCode) public isOwner {
        
        require(status !=  6, "Contract status cannot be modified as it has been closed");
        
        if (statusCode == 3){
            require(isSellerSigned == true, "Seller has not approved the contract.");
            require(outStandingBalanceOfPayment > 0, "The outStandingBalanceOfPayment is 0 i.e. paid in full.");
            require(status == 1, "Contract status must be OPEN to begin funding round.");
            status = 3;
        } else{
            //TODO More contral statements required per status
            
            //temporary
            status = statusCode;
        }

        emit logAddress(owner, "initializeNewState", statusCode);
    }
    
    function sold() public isOwner nonReentrant {
        
         //SOLD
            require(isSellerSigned == true, "Seller has not approved the contract.");
            require(owningBuyer != address(0), "Bidding buyer address not found.");
            uint totalOwnerBid = biddersDeposit[owningBuyer];
            biddersDeposit[owningBuyer] = 0;
            
            uint baseCurrencyDeposit = latestPriceInBaseCurrency(totalOwnerBid);
            buyerPaidSumInBaseCurrency = baseCurrencyDeposit;
            
            //Sets ownershipSize of the buyer
            ownershipSize[owningBuyer] = calculateOwnerShipPercent(buyerPaidSumInBaseCurrency, salePriceInBaseCurrency); 
            
            uint moneyToTransfer = fundingPoolSum + totalOwnerBid;
            uint moneyToTransferBCurrency = latestPriceInBaseCurrency(moneyToTransfer);
            if (moneyToTransferBCurrency > salePriceInBaseCurrency){
            uint refundIfHigherThanSale = moneyToTransferBCurrency - salePriceInBaseCurrency;
                
                //TODO Refund must be made to mortgagees instead of buyer.
                if (refundIfHigherThanSale > 0){
                    //convert fiat to eth
                    uint256 refundVal = convertBaseToWei(refundIfHigherThanSale);
                    fundingPoolSum = fundingPoolSum - refundVal;
                    biddersDeposit[owningBuyer] = refundVal;
                    moneyToTransfer = moneyToTransfer - refundVal;
                }
            }
            
            
            if (ownershipSize[owningBuyer] >= fixed2()){
                contractFullyPaid();
            }else{
                uint fundingPoolSumInBCurrency = latestPriceInBaseCurrency(fundingPoolSum);
                
                //Set mortgagees ownerships
                for (uint i = 0; i < mortgagees.length; i++){
                    address mortgageesAddress = mortgagees[i];
                    uint investmenInBaseCurrency = latestPriceInBaseCurrency(mortgageesBalance[mortgageesAddress]);
                    mortgageesOwnershipSize[mortgageesAddress] = calculateOwnerShipPercent(investmenInBaseCurrency, fundingPoolSumInBCurrency);
                    mortgageesBalance[mortgageesAddress] = 0;
                    
                    // uint256 tokenId = mintOwnershipNFT(mortgageesAddress, fileHash, metadataHash);
                    // require(tokenId > 0, "Unable to create NFT. Please check the NFT contract.");
                }
                
                //calc the interest on the loan 
                uint interestSumProduct = fundingPoolSumInBCurrency * termSheet.rateOfInterest;
                uint interestSum = interestSumProduct / fixed2();
                outStandingBalanceOfPayment = fundingPoolSumInBCurrency + interestSum;
                termSheet.repaymentBeginDate = block.timestamp;
                status = 8;
            }
            
 
            //TODO Check why moneyToTransfer was higher than contractTreasuryBalance
            if (moneyToTransfer >= contractTreasuryBalance){
                uint256 transferAmt = contractTreasuryBalance;
                contractTreasuryBalance = 0;
                (bool success, ) = seller.call{value:transferAmt}("");
                require(success, "Sold money transfer failed.");
            }else{
                contractTreasuryBalance = contractTreasuryBalance - moneyToTransfer;
                (bool success, ) = seller.call{value:moneyToTransfer}("");
                require(success, "Sold money else transfer failed.");
            }

            emit logAddress(owningBuyer, "Sold for:", moneyToTransferBCurrency);
    }
    
    function payToclaimOwnershipNFT() public payable nonReentrant {
        require(paused == false, "Contract is paused.");
        require(mortgageesOwnershipSize[msg.sender] > 0 || ownershipSize[msg.sender] > 0 , "Not authorised to claim NFT.");
        //TODO Send a event to an oracle which should generate the nft metatadata and mint + transfer the nft. The off chain sys ensures appropriate payment was made to complete the transaction.
        
        (bool success, ) = platformOwner.call{value:msg.value}("");
        require(success, "payToclaimOwnershipNFT failed at transfer");
        emit logAddress(msg.sender, "payToclaimOwnershipNFT", msg.value);
    }
    
    function mintOwnershipNFT(address receiverAddress, string memory fileHash,
        string memory metadataHash) public isPlatformOwner returns (uint256) {
        require(paused == false, "Contract is paused.");
        uint256 tokenId = nft.mintNft(receiverAddress, fileHash, metadataHash);
        nftHolders[tokenId] = receiverAddress;
        tokenIdArray.push(tokenId);
        emit logAddress(receiverAddress, "mintOwnershipNFT", 0);
        return tokenId;
    }
    
    function burnOwnershipNFT(uint256 tokenId) public isPlatformOwner {
        require(nftHolders[tokenId] != address(0), "TokenId not associated with any ownership.");
        nftHolders[tokenId] = address(0);
        nft.burnNFT(tokenId);
        emit log("burnNFT", tokenId);
    }
    
    function repayMortgage() public payable {
        require(paused == false, "Contract is paused.");
        require(msg.value > 0, "payment value must be greater than o");
        require(ownershipSize[msg.sender] > 0, "Repayment must come from the buying owner's only.");
        uint amtInBaseCurrency = latestPriceInBaseCurrency(msg.value);
        outStandingBalanceOfPayment = outStandingBalanceOfPayment - amtInBaseCurrency;
        contractTreasuryBalance = contractTreasuryBalance + msg.value;
        emit logAddress(msg.sender, "repayMortgage", msg.value);
        contractFullyPaid();
    }
    
    function contractFullyPaid() private {
        if (outStandingBalanceOfPayment <= newFixed(5)){
            status = 5;//PAID
            //Burn mortgagees NFT and set owner's ownerhsip to 100%
            for (uint256 i = 0; i < tokenIdArray.length; i++){
                uint256 tokenId = tokenIdArray[i];
                burnOwnershipNFT(tokenId);
            }
            
            for (uint i = 0; i < mortgagees.length; i++){
                address mortgageesAddress = mortgagees[i];
                uint256 owed = _calOwedAmountOnOwnershipSize(mortgageesAddress);
                mortgageesBalance[mortgageesAddress] = mortgageesBalance[mortgageesAddress] + owed;
                mortgageesOwnershipSize[mortgageesAddress] = 0;
            }
            
            ownershipSize[owningBuyer] = 10000;
            //Send event to create and transfer ownership NFT to owner.
            emit log("contractFullyPaid", outStandingBalanceOfPayment);
           
        }
    }
    
    function claimMortgageRepayment() public nonReentrant returns (uint256) {
        require(paused == false, "Contract is paused.");
        require(isSellerSigned == true, "Seller has not approved the contract.");
        
        uint owedAmt = 0;
        if (outStandingBalanceOfPayment <= newFixed(5)){
            require(status == 5, "Status not set to PAID to claim full amount.");
            owedAmt = mortgageesBalance[msg.sender];
            mortgageesBalance[msg.sender] = 0;
        }else{
            require(status == 8, "Not open for mortgage repayments yet.");
            owedAmt = _calOwedAmountOnOwnershipSize(msg.sender);
        }
        contractTreasuryBalance = contractTreasuryBalance - owedAmt;
        require(owedAmt > 0, "No owed amount found.");
        (bool success, ) = msg.sender.call{value:owedAmt}("");
        require(success, "claimMortgageRepayment failed at transfer");
        emit logAddress(msg.sender, "claimMortgageRepayment", owedAmt);
        return owedAmt;
    }
    
    function _calOwedAmountOnOwnershipSize(address addressToCal) private view returns (uint256) {
        uint shareSize = mortgageesOwnershipSize[addressToCal];
        //TODO This is an example. Needs a proper function.
        return (contractTreasuryBalance * (shareSize)) / fixed2();
    }
    
    function withdrawAsMortgagee() public nonReentrant {
        require(paused == false, "Contract is paused.");
        require(status != 8, "Unable to withdraw after the status of the contract set to SOLD");
        uint transferVal = mortgageesBalance[msg.sender];
        fundingPoolSum = fundingPoolSum - transferVal;
        contractTreasuryBalance = contractTreasuryBalance - transferVal;
        (bool success, ) = payable(msg.sender).call{value:transferVal}("");
        require(success, "withdrawAsMortgagee failed at transfer");
        emit logAddress(msg.sender, "withdrawAsMortgagee", transferVal);
    }
    
    function withdrawAsBidder() public nonReentrant {
        require(paused == false, "Contract is paused.");
        require(status != 8, "Unable to withdraw after the status of the contract set to SOLD");
        uint transferVal = biddersDeposit[msg.sender];
        require(transferVal > 0, "Bid not found.");
        uint ownershipPercentage = ownershipSize[msg.sender]; 
        if (ownershipPercentage > 0){
            ownershipSize[msg.sender] = 0;
        }
        biddersDeposit[msg.sender] = 0;
        owningBuyer = address(0); 
        contractTreasuryBalance = contractTreasuryBalance - transferVal;
        (bool success, ) = payable(msg.sender).call{value:transferVal}("");
        require(success, "withdrawAsBidder failed at transfer");
        emit logAddress(msg.sender, "withdrawAsBidder", transferVal);
    }
    
    /*** 
     * 
     * @notice Converts an uint256 to fixed point units, equivalent to multiplying
     * by 10^digits().
     * @dev Test newFixed(0) returns 0
     * Test newFixed(1) returns fixed1()
     * Test newFixed(maxNewFixed()) returns maxNewFixed() * fixed1()
     * Test newFixed(maxNewFixed()+1) fails
     */
    function newFixed(uint256 x)
        public
        pure
        returns (uint256)
    {
        assert(x <= maxNewFixed());
        return x * fixed1();
    }
    
    /**
     * @notice This is 1 in the fixed point units used in this library.
     * @dev Test fixed1() equals 10^digits()
     * Hardcoded to 4 digits.
     */
    function fixed1() public pure returns(uint256) {
        return 1000;
    }
    
    /**
     * @notice This is 1 in the fixed point units used in this library.
     * @dev Test fixed1() equals 10^digits()
     * Hardcoded to 5 digits.
     */
    function fixed2() public pure returns(uint256) {
        return 10000;
    }
    
     /**
     * @notice Maximum value that can be converted to fixed point. Optimize for
     * @dev deployment. 
     * Test maxNewFixed() equals maxInt256() / fixed1()
     * Hardcoded to 24 digits.
     */
    function maxNewFixed() public pure returns(uint256) {
        return 57896044618658097711785492504343953926634992332820282;
    }
    
    receive() external payable { 
    	emit logUnauthorisedDepositReceived(msg.sender, msg.value); 
    }
    
    /**
     * Test version only function to reset contract for re-use in beta-testing
     * MUST BE REMOVED PRIOR TO LIVE
     * **/
    function resetBETA(uint256 rateOfInterest, string memory interestType, BNFT nftContractAddr) public isOwner nonReentrant {
        nft = nftContractAddr;    
        status = 0;
        propertyDetailsHash = "";
        isSellerSigned = false;
        contractTreasuryBalance = 0;
        latestExchangeRate = 0;
        salePriceInBaseCurrency = 0;
        fundingPoolSum = 0;
        outStandingBalanceOfPayment = 0;
        buyerPaidSumInBaseCurrency = 0;
        mortgageBidExpiryTime = 0;
        uniquePostBidAccessKeyForMortgagees = "";
        for (uint i = 0; i < mortgagees.length; i++){
            address mortgageesAddress = mortgagees[i];
            mortgageesBalance[mortgageesAddress] = 0;
            mortgageesOwnershipSize[mortgageesAddress] = 0;
        }
        delete mortgagees;
        for (uint i = 0; i < tokenIdArray.length; i++){
            uint256 tokenId = tokenIdArray[i];
            if (nftHolders[tokenId] != address(0)){
                burnOwnershipNFT(tokenId);
            }
            nftHolders[tokenId] = address(0);
        }
        delete tokenIdArray;
        biddersDeposit[owningBuyer] = 0;
        ownershipSize[owningBuyer] = 0;
        termSheet = TermSheet(rateOfInterest, interestType, 0);
        owningBuyer = address(0);
        payable(msg.sender).transfer(address(this).balance);
    }
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
}
