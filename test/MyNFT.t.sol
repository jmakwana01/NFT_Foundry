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

    

}