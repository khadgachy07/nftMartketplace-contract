// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable@4.8.1/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.8.1/security/ReentrancyGuardUpgradeable.sol";

import "./PriceFeed.sol";

contract NFTMartketplace is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    PriceFeed
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _marketItemIds;
    CountersUpgradeable.Counter private _nftSold;
    CountersUpgradeable.Counter private _nftCanceled;



    bytes32 private constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE"); 
    uint256 public listingFee;

    enum State {
        Listed,
        Cancelled,
        Sold
    }


    struct NFT {
        uint256 marketItemId;
        address nftAddress;
        uint256 tokenId;
        address creator;
        address seller;
        address owner;
        uint256 price;
        State nftState;
    }

    event NFTlisted(
        uint256 marketItemId,
        address nftAddress,
        uint256 tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price,
        State nftState
    );

    event NFTcanceled(
        uint256 marketItemId,
        address nftAddress,
        uint256 tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price,
        State nftState
    );


    event NFTsold(
        uint256 marketItemId,
        address nftAddress,
        uint256 tokenId,
        address creator,
        address seller,
        address owner,
        uint256 price,
        State nftState
    );


    struct NFTauction{
        uint256 auctionItem;
        address nftAddress;
        uint256 tokenId;
        address auctionedBy;
        uint256 startingPrice;
        uint256 auctionedAt;
        uint256 auctionedEndAt;
        address previousBidder;
        address highestBidder;
        uint256 previousBid;
        uint256 highestBid;
    }

    mapping(uint256 => NFT) public NFTs;
    mapping(address => mapping(uint256 => bool)) public forSale;

    CountersUpgradeable.Counter private _nftAuctioned;

    mapping(uint256 => NFTauction) public nftInAuction;

    modifier checkInSale(address nftAddress, uint256 tokenId) {
        require(
            IERC721Upgradeable(nftAddress).ownerOf(tokenId) == address(this),
            "Item is not on sale"
        );
        require(forSale[nftAddress][tokenId], "Item is not listed on sale");
        _;
    }

    modifier notInSalenMustBeOwner(address nftAddress, uint256 tokenId) {
        require(
            IERC721Upgradeable(nftAddress).ownerOf(tokenId) == msg.sender,
            "Caller is not an owner of this item"
        );
        require(!forSale[nftAddress][tokenId], "Item is alrealy on sale");
        _;
    }


    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        setListingFee();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function updateListPrice(uint256 _listPrice)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        listingFee = _listPrice;
    }

    function assginOperator(address _operator)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(OPERATOR_ROLE, _operator);
    }

    function removeOperator (address _operator)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(OPERATOR_ROLE, _operator);
    }

    function withdrawListingFee() public onlyRole(OPERATOR_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    function pause() public onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function setListingFee() private{
        listingFee = 0.005 ether;
    }

    function getNFTPrice(uint256 _marketItemId) public view returns (uint256){
        uint result = PriceFeed.getEthPrice() * NFTs[_marketItemId].price;
        return result/1000000000000000000;
    }

 
    function auctionNFT(address _nftAddress,uint256 _tokenId,uint256 _price) public notInSalenMustBeOwner(_nftAddress, _tokenId){
        _nftAuctioned.increment();
        uint256 newItem = _nftAuctioned.current();
        nftInAuction[newItem] = NFTauction(
            newItem,
            _nftAddress,
            _tokenId,
            msg.sender,
            _price,
            block.timestamp,
            0,
            address(0),
            address(0),
            0,
            0
        );
        IERC721Upgradeable(_nftAddress).transferFrom(msg.sender,address(this),_tokenId);
    }

    function bidforNFT(uint _auctionedItem)public payable {
        NFTauction memory nft = nftInAuction[_auctionedItem];
        require(msg.sender != nft.auctionedBy,"Participant cannot bid for their own auctioned NFT");
        require(msg.value > nft.highestBid && msg.value > nft.startingPrice,"Participant need to bid more than pervious bid");
        require(nft.auctionedEndAt == 0,"Auction has alrerady ended");
        if(nft.highestBidder != address(0)){
            nft.previousBidder = nft.highestBidder; // 
            nft.previousBid = nft.highestBid;
        }
        nft.highestBidder = msg.sender;
        nft.highestBid = msg.value; 
        nftInAuction[_auctionedItem] = nft;
        if(nft.previousBid != 0){
            payable(nft.previousBidder).transfer(nft.previousBid);
        }
    }

    function endAuction(uint _auctionedItem) public payable {
        NFTauction memory nft = nftInAuction[_auctionedItem];
        require(nft.auctionedBy == msg.sender,"You must be owner of this NFT to end this auction");
        require(nft.auctionedEndAt == 0,"This auction has alrerady ended");
        nft.auctionedEndAt = block.timestamp;
        nftInAuction[_auctionedItem] = nft;
        payable(msg.sender).transfer(nft.highestBid);
        IERC721Upgradeable(nft.nftAddress).transferFrom(address(this),nft.highestBidder,nft.tokenId);
    }

    function listNFTforSale(
        address _nftAddress,
        uint256 _tokenId,
        uint256 tokenPrice,
        address _creator
    ) public payable nonReentrant notInSalenMustBeOwner(_nftAddress, _tokenId) {
        require(msg.value == listingFee, "Not Enough Listing Fee");
        _marketItemIds.increment();
        uint256 newItemId = _marketItemIds.current();
        NFTs[newItemId] = NFT(
            newItemId,
            _nftAddress,
            _tokenId,
            _creator,
            msg.sender,
            address(0), //
            tokenPrice,
            State.Listed
        );
        forSale[_nftAddress][_tokenId] = true;
        IERC721Upgradeable(_nftAddress).transferFrom(
            msg.sender,  // from
            address(this), // --- contract'
            _tokenId // tokenId
        );
        emit NFTlisted(
            newItemId,
            _nftAddress,
            _tokenId,
            _creator,
            msg.sender,
            address(0),
            tokenPrice,
            State.Listed
        );
    }

    function cancelSale(
        address _nftAddress,
        uint256 tokenId,
        uint256 _marketItemId
    ) public nonReentrant checkInSale(_nftAddress, tokenId) {
        NFT memory nft = NFTs[_marketItemId];
        require(
            nft.seller == msg.sender || hasRole(OPERATOR_ROLE, msg.sender),
            "Only seller or Operator can cancel the sale"
        );
        _nftCanceled.increment();
        nft.owner = nft.seller;
        nft.price = 0;
        nft.nftState = State.Cancelled;
        NFTs[_marketItemId] = nft;
        forSale[_nftAddress][nft.tokenId] = false;
        IERC721Upgradeable(_nftAddress).transferFrom(
            address(this), // from
            nft.seller,
            nft.tokenId
        );
        emit NFTcanceled(
            _marketItemId,
            _nftAddress,
            nft.tokenId,
            nft.creator,
            address(0),
            msg.sender,
            0,
            State.Cancelled
        );
    }

    function buyNFT(
        address _nftAddress,
        uint256 tokenId,
        uint256 _marketItemId
    ) public payable nonReentrant checkInSale(_nftAddress, tokenId) {
        //    IERC721 newNFT = IERC721(_nftAddress);
        NFT memory nft = NFTs[_marketItemId];
        require(
            nft.nftState == State.Listed,
            "This item is not listed for sale"
        );
        require(msg.value == nft.price, "Given price is not enough");
        _nftSold.increment();
        forSale[_nftAddress][nft.tokenId] = false;
        nft.owner = msg.sender;
        nft.nftState = State.Sold;
        NFTs[_marketItemId] = nft;
        (, uint256 royalAmount) = IERC2981Upgradeable(_nftAddress).royaltyInfo(
            nft.tokenId,
            nft.price
        );
        payable(nft.seller).transfer(nft.price);
        payable(nft.creator).transfer(royalAmount);
        IERC721Upgradeable(_nftAddress).transferFrom(
            address(this),
            msg.sender,
            nft.tokenId
        );
        emit NFTsold(
            _marketItemId,
            _nftAddress,
            nft.tokenId,
            nft.creator,
            nft.seller,
            msg.sender,
            nft.price,
            State.Sold
        );
    }

    function resaleNFT(
        uint256 _marketItemId,
        address _nftAddress,
        uint256 _tokenId,
        uint256 price
    ) public payable nonReentrant notInSalenMustBeOwner(_nftAddress, _tokenId) {
        NFT memory nft = NFTs[_marketItemId];
        require(msg.value >= listingFee, "Not Enough Listing Fee");
        nft.seller = msg.sender;
        nft.owner = address(0);
        nft.price = price;
        nft.nftState = State.Listed;
        NFTs[_marketItemId] = nft;
        forSale[_nftAddress][_tokenId] = true;
        IERC721Upgradeable(_nftAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        emit NFTlisted(
            _marketItemId,
            _nftAddress,
            _tokenId,
            nft.creator,
            msg.sender,
            address(0),
            price,
            State.Listed
        );
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

// proxy contract --- 0xf0e4600fBb40F79c20C876a20FDD6f56074F028D
// implementation contract ---- 0x5cb5b7Df6d0C6B14326F32Ca9c876a051b3909dE

