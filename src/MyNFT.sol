// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MyNFT
 * @dev A comprehensive ERC721 NFT contract with multiple features for testing purposes
 * @author Learning Foundry
 * 
 * Features included:
 * - Standard ERC721 functionality
 * - Enumerable (track all tokens)
 * - URI Storage (individual token URIs)
 * - Pausable (emergency stop mechanism)
 * - Access Control (role-based permissions)
 * - Ownable (contract ownership)
 * - Minting with different access levels
 * - Batch operations
 * - Royalty support (EIP-2981)
 * - Maximum supply cap
 * - Whitelist functionality
 */
contract MyNFT is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    ERC721Pausable, 
    Ownable, 
    AccessControl,
    ReentrancyGuard 
{
    // =============================================================
    //                        CONSTANTS
    // =============================================================
    
    /// @dev Role identifier for minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @dev Role identifier for pausers
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @dev Maximum number of tokens that can be minted
    uint256 public constant MAX_SUPPLY = 10000;
    
    /// @dev Maximum tokens per wallet for public mint
    uint256 public constant MAX_PER_WALLET = 5;

    // =============================================================
    //                        STATE VARIABLES
    // =============================================================
    
    /// @dev Current token ID counter (starts from 1)
    uint256 private _nextTokenId = 1;
    
    /// @dev Base URI for token metadata
    string private _baseTokenURI;
    
    /// @dev Mapping to track how many tokens each address has minted
    mapping(address => uint256) public mintedByAddress;
    
    /// @dev Mapping for whitelist functionality
    mapping(address => bool) public whitelist;
    
    /// @dev Whether public minting is enabled
    bool public publicMintEnabled = false;
    
    /// @dev Whether whitelist minting is enabled
    bool public whitelistMintEnabled = false;
    
    /// @dev Price per token in wei
    uint256 public mintPrice = 0.01 ether;
    
    /// @dev Royalty percentage (basis points, e.g., 500 = 5%)
    uint256 public royaltyPercentage = 500;
    
    /// @dev Address to receive royalties
    address public royaltyRecipient;

    // =============================================================
    //                        EVENTS
    // =============================================================
    
    /// @dev Emitted when base URI is updated
    event BaseURIUpdated(string oldBaseURI, string newBaseURI);
    
    /// @dev Emitted when mint price is updated
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    
    /// @dev Emitted when public mint status changes
    event PublicMintStatusChanged(bool enabled);
    
    /// @dev Emitted when whitelist mint status changes
    event WhitelistMintStatusChanged(bool enabled);
    
    /// @dev Emitted when addresses are added to whitelist
    event AddressesWhitelisted(address[] addresses);
    
    /// @dev Emitted when addresses are removed from whitelist
    event AddressesRemovedFromWhitelist(address[] addresses);
    
    /// @dev Emitted when royalty info is updated
    event RoyaltyInfoUpdated(address recipient, uint256 percentage);

    // =============================================================
    //                        ERRORS
    // =============================================================
    
    /// @dev Thrown when trying to mint more than max supply
    error ExceedsMaxSupply();
    
    /// @dev Thrown when public minting is not enabled
    error PublicMintNotEnabled();
    
    /// @dev Thrown when whitelist minting is not enabled
    error WhitelistMintNotEnabled();
    
    /// @dev Thrown when address is not whitelisted
    error NotWhitelisted();
    
    /// @dev Thrown when trying to mint more than allowed per wallet
    error ExceedsMaxPerWallet();
    
    /// @dev Thrown when insufficient payment is sent
    error InsufficientPayment();
    
    /// @dev Thrown when trying to set invalid royalty percentage
    error InvalidRoyaltyPercentage();

    // =============================================================
    //                        CONSTRUCTOR
    // =============================================================
    
    /**
     * @dev Initializes the contract with basic parameters
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     * @param baseURI The base URI for token metadata
     * @param owner The address that will own the contract
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address owner
    ) ERC721(name, symbol) Ownable(owner) {
        _baseTokenURI = baseURI;
        royaltyRecipient = owner;
        
        // Grant roles to the contract owner
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
    }

    // =============================================================
    //                        MINTING FUNCTIONS
    // =============================================================
    
    /**
     * @dev Mints a single token to the caller (public mint)
     * @param to Address to mint the token to
     * @notice Requires public minting to be enabled and payment
     */
    function publicMint(address to) external payable nonReentrant whenNotPaused {
        if (!publicMintEnabled) revert PublicMintNotEnabled();
        if (msg.value < mintPrice) revert InsufficientPayment();
        if (mintedByAddress[to] >= MAX_PER_WALLET) revert ExceedsMaxPerWallet();
        
        _mintToken(to);
        mintedByAddress[to]++;
    }
    
    /**
     * @dev Mints a token for whitelisted addresses
     * @param to Address to mint the token to
     * @notice Requires whitelist minting to be enabled and address to be whitelisted
     */
    function whitelistMint(address to) external payable nonReentrant whenNotPaused {
        if (!whitelistMintEnabled) revert WhitelistMintNotEnabled();
        if (!whitelist[to]) revert NotWhitelisted();
        if (msg.value < mintPrice) revert InsufficientPayment();
        if (mintedByAddress[to] >= MAX_PER_WALLET) revert ExceedsMaxPerWallet();
        
        _mintToken(to);
        mintedByAddress[to]++;
    }
    
    /**
     * @dev Mints multiple tokens to specified addresses (only minter role)
     * @param recipients Array of addresses to mint tokens to
     * @notice Only addresses with MINTER_ROLE can call this
     */
    function batchMint(address[] calldata recipients) external onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 length = recipients.length;
        if (_nextTokenId + length - 1 > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        for (uint256 i = 0; i < length; i++) {
            _mintToken(recipients[i]);
        }
    }
    
    /**
     * @dev Mints a token with custom URI (only minter role)
     * @param to Address to mint the token to
     * @param uri Custom URI for the token
     * @return tokenId The ID of the minted token
     */
    function mintWithURI(address to, string memory uri) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        returns (uint256) 
    {
        uint256 tokenId = _mintToken(to);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }
    
    /**
     * @dev Internal minting function
     * @param to Address to mint the token to
     * @return tokenId The ID of the minted token
     */
    function _mintToken(address to) internal returns (uint256) {
        if (_nextTokenId > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        _safeMint(to, tokenId);
        
        return tokenId;
    }

    // =============================================================
    //                        ADMIN FUNCTIONS
    // =============================================================
    
    /**
     * @dev Sets the base URI for token metadata
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        string memory oldBaseURI = _baseTokenURI;
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(oldBaseURI, newBaseURI);
    }
    
    /**
     * @dev Sets the mint price
     * @param newPrice The new mint price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;
        emit MintPriceUpdated(oldPrice, newPrice);
    }
    
    /**
     * @dev Enables or disables public minting
     * @param enabled Whether public minting should be enabled
     */
    function setPublicMintEnabled(bool enabled) external onlyOwner {
        publicMintEnabled = enabled;
        emit PublicMintStatusChanged(enabled);
    }
    
    /**
     * @dev Enables or disables whitelist minting
     * @param enabled Whether whitelist minting should be enabled
     */
    function setWhitelistMintEnabled(bool enabled) external onlyOwner {
        whitelistMintEnabled = enabled;
        emit WhitelistMintStatusChanged(enabled);
    }
    
    /**
     * @dev Adds addresses to the whitelist
     * @param addresses Array of addresses to add to whitelist
     */
    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
        emit AddressesWhitelisted(addresses);
    }
    
    /**
     * @dev Removes addresses from the whitelist
     * @param addresses Array of addresses to remove from whitelist
     */
    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
        emit AddressesRemovedFromWhitelist(addresses);
    }
    
    /**
     * @dev Pauses all token transfers and minting
     * @notice Only addresses with PAUSER_ROLE can call this
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpauses all token transfers and minting
     * @notice Only addresses with PAUSER_ROLE can call this
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Sets royalty information
     * @param recipient Address to receive royalties
     * @param percentage Royalty percentage in basis points (e.g., 500 = 5%)
     */
    function setRoyaltyInfo(address recipient, uint256 percentage) external onlyOwner {
        if (percentage > 1000) revert InvalidRoyaltyPercentage(); // Max 10%
        royaltyRecipient = recipient;
        royaltyPercentage = percentage;
        emit RoyaltyInfoUpdated(recipient, percentage);
    }
    
    /**
     * @dev Withdraws contract balance to owner
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================
    
    /**
     * @dev Returns the next token ID to be minted
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
    
    /**
     * @dev Returns the total number of tokens minted
     */
    function totalMinted() external view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    /**
     * @dev Returns whether an address is whitelisted
     * @param addr Address to check
     */
    function isWhitelisted(address addr) external view returns (bool) {
        return whitelist[addr];
    }
    
    /**
     * @dev Returns royalty information for a token
     * @param tokenId Token ID to check
     * @param salePrice Sale price to calculate royalty from
     * @return receiver Address to receive royalty
     * @return royaltyAmount Amount of royalty to pay
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) 
        external 
        view 
        returns (address receiver, uint256 royaltyAmount) 
    {
        // Silence unused parameter warning
        tokenId;
        
        receiver = royaltyRecipient;
        royaltyAmount = (salePrice * royaltyPercentage) / 10000;
    }

    // =============================================================
    //                        OVERRIDES
    // =============================================================
    
    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    /**
     * @dev Override to return base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || interfaceId == 0x2a55205a; // EIP-2981
    }
}