// SPDX-License-Identifier: BNFT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BNFT is ERC721Upgradeable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _contractAddressIndex;
    mapping (string => uint8) private hashes;
    mapping (uint256 => string) public tokenIdMetadataHashMap;
    address public owner;
    string public uri; 
    
    mapping (address => uint256) private approvedContracts ;

    event log(string msg, uint256 value);
    event logAddress(address sendersAddress, string msg, uint256 value);

    function initialize() initializer public {
        __ERC721_init("BNFT", "BSNT");
        owner = msg.sender;
    }

    modifier isOwner(){
        require(owner == msg.sender);
        _;
    }
    
    modifier isPlatfomOwnedContract(){
        require(approvedContracts[msg.sender] > 0);
        _;
    }
    
    function getContractAddressIndex() public view returns (uint256){
        uint256 counter = _contractAddressIndex.current();
        return counter;
    }
     
    function mintNft(address receiver, string memory fileHash, string memory metadataHash) external isPlatfomOwnedContract returns (uint256) {
        _tokenIds.increment();
        require(hashes[fileHash] != 1);
        hashes[fileHash] = 1;
        uint256 newNftTokenId = _tokenIds.current();
        _mint(receiver, newNftTokenId);
        tokenIdMetadataHashMap[newNftTokenId] = metadataHash;
        emit logAddress(receiver, "mintNft", newNftTokenId);
        return newNftTokenId;
    }
    
    function burnNFT(uint256 tokenId) external isPlatfomOwnedContract {
        tokenIdMetadataHashMap[tokenId] = "";
        _burn(tokenId);
    }
    
    function burnNFTOwnerAccess(uint256 tokenId) public isOwner {
        tokenIdMetadataHashMap[tokenId] = "";
        _burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        string memory metadataHash = tokenIdMetadataHashMap[tokenId];
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, metadataHash))
            : '';
    }
    
    function _baseURI() internal override view returns (string memory) {
        return uri;
    }
    
    function setBaseURI(string memory bUri) public isOwner {
        uri = bUri;
    }
    
    function registerApprovedContracts(address contractAddress) public isOwner {
        _contractAddressIndex.increment();
        uint256 counterIndex = _contractAddressIndex.current();
        approvedContracts[contractAddress] = counterIndex;
        emit logAddress(contractAddress, "registerApprovedContracts", counterIndex);
    }
    
    function unRegisterApprovedContracts(address contractAddress) public isOwner {
        require(approvedContracts[contractAddress] > 0, "Contract address not found.");
        approvedContracts[contractAddress] = 0;
        emit logAddress(contractAddress, "unRegisterApprovedContracts", 0);
    }
    
     
    
 
    
}
