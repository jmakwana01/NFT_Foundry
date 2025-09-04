//SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MyNFT.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title MyNFTTest
 * @dev Comprehensive test suite for MyNFT contract
 * @notice Tests cover all functionality including edge cases and fuzz testing
 * 
 * Test Structure:
 * 1. Deployment & Interface Tests - Verify contract deploys correctly and implements required interfaces
 * 2. Minting Tests - Test all minting functions and their access controls
 * 3. Access Control Tests - Verify role-based permissions work correctly
 * 4. Admin Function Tests - Test owner/admin functions like price setting, URI updates
 * 5. Pausable Tests - Verify pause/unpause functionality works correctly
 * 6. Supply Limit Tests - Test maximum supply constraints are enforced
 * 7. ERC721 Functionality Tests - Standard ERC721 operations (transfer, approve, etc.)
 * 8. Enumerable Tests - Test the enumerable extension functionality
 * 9. Fuzz Tests - Property-based testing with random inputs
 * 10. Edge Case Tests - Boundary conditions and error scenarios
 * 11. Gas Optimization Tests - Performance benchmarks
 * 12. Integration Tests - Full workflow scenarios
**/

contract MyNFTTest is Test{
    // =============================================================
    //                        TEST SETUP & CONSTANSTS
    // =============================================================

    //Main contract instance for testing 
    MyNFT public nft;

    // Test addresses - using makeAddr for clean, labeled addresses 
    address public owner = makeAddr("owner");
    address public minter = makeAddr("minter");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public hacker = makeAddr("hacker");

    //Test constants matching the contract's configuration
    string constant NAME="MyNFT";
    string constant SYMBOL="MNFT";
    string constant BASE_URI="https://ipfs.io/ipfs/QmexAVFvkq3FREjk3yKJAi779y96jKjNJ4BATxRC7uCX6K";
    uint256 constant MINT_PRICE = 0.01 ether;
    uint256 constant MAX_SUPPLY=1_0_000;
    uint256 constant MAX_PER_WALLET =5;

     // Events for testing - copied from contract for verification
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event BaseURIUpdated(string oldBaseURI, string newBaseURI);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PublicMintStatusChanged(bool enabled);
    event WhitelistMintStatusChanged(bool enabled);
    event AddressesWhitelisted(address[] addresses);
    event AddressesRemovedFromWhitelist(address[] addresses);
    event RoyaltyInfoUpdated(address recipient, uint256 percentage);

    /**
     * @dev Setup function runs before each test
        Deploys fresh contract instance and sets up test environment
     */

    function setUp()public{
        vm.prank(owner);
        nft = new MyNFT(NAME,SYMBOL,BASE_URI,owner);

        //Give test addresses ETH for testing paid minting functions
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(hacker,10 ether);

        vm.startPrank(owner);
        nft.grantRole(nft.MINTER_ROLE(),minter);
        nft.grantRole(nft.PAUSER_ROLE(),pauser);
        vm.stopPrank();
    }

    // =============================================================
    //                        DEPLOYMENT & INTERFACE TESTS
    // =============================================================

    /**
     * @dev Test that contract deploys with correct intial state
        Verifies all deployment parameters are set correctly
     */

    function test_Deployment()public view {
        // check basic contract metadata 
        assertEq(nft.name(), NAME,"Contract name should match deployment parameter");
        assertEq(nft.symbol(),SYMBOL,"Contract symbol should match deployment parameter");
        assertEq(nft.owner(),owner,"Contract owner should be set correctly");

        // Check token id management 
        assertEq(nft.getCurrentTokenId(),1,"Token ID counter should start at 1");
        assertEq(nft.totalSupply(), 0,"Total sypply should start at 0");
        assertEq(nft.totalMinted(),0,"Total minted should start at 0");

        //check mint configuration
        assertEq(nft.mintPrice(), MINT_PRICE,"Mint price should match deployment setting");
        assertFalse(nft.publicMintEnabled(),"public minting should be disabled by default");
        assertFalse(nft.whitelistMintEnabled(),"whitelist minting should be disabled by default");

        //check role assignments - owner should have all admin roles
        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), owner),"Owner should have default admin role");
        assertTrue(nft.hasRole(nft.PAUSER_ROLE(), owner),"Owner should have pauser role");
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), owner),"Owner should have minter role");

        //check granted roles from setup
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), minter),"Minter address should have minter role");
        assertTrue(nft.hasRole(nft.PAUSER_ROLE(), pauser),"Pauser address should have pauser role");

        //check constants
        assertEq(nft.MAX_SUPPLY(), MAX_SUPPLY,"Max supply constant should match expected value");
        assertEq(nft.MAX_PER_WALLET(),MAX_PER_WALLET,"Max per wallet should match expected value");
    }

    /**
     * @dev Test that contract implements all required interfaces
     * ERC721 contracts should support multiple interface standards
     */
    function test_SupportsInterface() public {
        // Core ERC721 interface
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId), "Should support ERC721 interface");
        
        // ERC721Enumerable extension - allows iteration through all tokens
        assertTrue(nft.supportsInterface(type(IERC721Enumerable).interfaceId), "Should support ERC721Enumerable");
        
        // AccessControl interface - role-based permissions
        assertTrue(nft.supportsInterface(type(IAccessControl).interfaceId), "Should support AccessControl");
        
        // EIP-2981 Royalty standard - royalty payments on secondary sales
        assertTrue(nft.supportsInterface(0x2a55205a), "Should support EIP-2981 royalty standard");
        
        // ERC165 interface detection standard
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId), "Should support ERC165");
    }
    
    // =============================================================
    //                        MINTING TESTS
    // =============================================================
}