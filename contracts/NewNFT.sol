// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract NewNFT is ERC721, ERC2981, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    string private uri;

    mapping(uint => string) public nftURI; 

    constructor() ERC721("New NFT", "MNFT") {}

    function _baseURI() internal view override returns (string memory) {
        return uri; //"
    }


    function safeMint(string memory _uri,address _marketplaceAddress,uint96 _feeNumotor) public onlyOwner {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
        listURI(_uri,tokenId);
        setApprovalForAll(_marketplaceAddress,true);
        _setTokenRoyalty(tokenId,msg.sender,_feeNumotor); // 10% == 1000 
        // _feeDomit 10000 
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {   
        
        return string(abi.encodePacked(super.tokenURI(tokenId), ".json"));
    }
    

    function listURI(string memory _uri,uint tokenId) private {
        uri = _uri;
        nftURI[tokenId] = _uri;
    }

    function approval(address _marketplaceAddress)public {
        setApprovalForAll(_marketplaceAddress,true);
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}