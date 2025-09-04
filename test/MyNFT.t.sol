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

    /**
     * @dev Test admin minting for custom URI
        Only address with MINTER_ROLE should be able to mint with custom URIs
     */

    function test_MinterRoleMint()public{
        //Arrange:Use Minter address to mint with custom URI
        // string memory customURI = "ipfs://custom-hash-for-special-nft";

        // //ACT: Mint token with custom URI
        // nft.mintWithURI(user1, customURI);
        string memory customURI = "ipfs://custom-hash";
        vm.prank(owner);
        nft.setBaseURI("");

        vm.prank(minter);
        nft.mintWithURI(user1, customURI);
        
        assertEq(nft.tokenURI(1), customURI, "Custom URI should be returned exactly");
        //Assert: Verify token was minted correctly
        assertEq(nft.balanceOf(user1),1,"User should have 1 token");
        assertEq(nft.ownerOf(1),user1,"user1 should own token ID 1");
        assertEq(nft.tokenURI(1),customURI,"Token should have custom URI");
        assertEq(nft.totalSupply(),1,"Total supply should be 1");
        assertEq(nft.getCurrentTokenId(),2,"Next token ID should be 2");
    }

    /**
     * @dev Test batch minting functionalty
     Verifies that multiple tokens can be minted efficiently in one transaction
     */

    function test_BatchMint()public {
        //Arrange: Create array of reciepients for batch mint
        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1]= user2;
        recipients[2]= user3;

        //ACT: Batch mint to all recipients
        vm.prank(minter);
        nft.batchMint(recipients);

        //Assert: Verify all tokens were minted correctly
        assertEq(nft.totalSupply(),3,"Total supply should be 3 after batch mint");
        assertEq(nft.balanceOf(user1),1,"User 1 should have 1 token");
        assertEq(nft.balanceOf(user2),1,"User 2 should have 1 token");
        assertEq(nft.balanceOf(user3),1,"User 3 should have 1 token");

        //Verify token ownership by ID
        assertEq(nft.ownerOf(1),user1,"User1 should own token 1");
        assertEq(nft.ownerOf(2),user2,"User2 should own token 2");
        assertEq(nft.ownerOf(3),user3,"User3 should own token 3");
    }

    function test_PublicMint_Success() public {
        //Arrange enable public minting(onlyOwner)
        vm.prank(owner);
        nft.setPublicMintEnabled(true);

        //Act User mints a token woth correct payment
        vm.prank(user1);
        nft.publicMint{value:MINT_PRICE}(user1);
        //Assert: Verify mint was successful
        assertEq(nft.balanceOf(user1),1,"user should have 1 token after public mint");
        assertEq(nft.mintedByAddress(user1),1,"Should track 1 token minted by user");
        assertEq(nft.ownerOf(1),user1,"User should own the minted token");

        //Verify contract recieved payment
        assertEq(address(nft).balance,MINT_PRICE,"Contract should have received mint payment");
    }

    /**
     * @dev Test public minting fails when not enabled
        should revert with custom error when public minting is disabled
     */
    function test_PublicMint_NotEnabled()public{
        //public minting is disabled by default in setup

        //act 
        vm.prank(user1);
        vm.expectRevert( MyNFT.PublicMintNotEnabled.selector);
       
        nft.publicMint{value:MINT_PRICE}(user1);
    }

    /**
     * @dev Test public minting fails with insufficient payment
     should revert when payment is leass than mint price
     */
    function test_PublicMint_InsufficientPayment()public{
        //Arrange:Enable public Minting
        vm.prank(owner);
        nft.setPublicMintEnabled(true);

        //ACT & Assert: Mint with Insufficient payment should fail
        vm.prank(user1);
        vm.expectRevert(MyNFT.InsufficientPayment.selector);
        nft.publicMint{value:MINT_PRICE -1}(user1);//send 1 wei less than required

    }

    /**
     * @dev Test Public minting respeccts per wallet limits
     Use
     */
    
    function test_PublicMint_ExceedsMaxPerWallet()public{
        //Arrange: Enable public minting 
        vm.prank(owner);
        nft.setPublicMintEnabled(true);

        //ACT: Mint maximum allowed tokens
        vm.startPrank(user1);
        for (uint256 i=0;i<MAX_PER_WALLET;i++){
            nft.publicMint{value:MINT_PRICE}(user1);
        }

        //ACT & ASSERT: Attempt to mint one more shoudl fail
        vm.expectRevert(MyNFT.ExceedsMaxPerWallet.selector);
        nft.publicMint{value:MINT_PRICE}(user1);
        vm.stopPrank();

        //Verify user has exactly MAX_PER_WALLET tokens
        assertEq(nft.balanceOf(user1),MAX_PER_WALLET,"User should have max allowed tokens");
        assertEq(nft.mintedByAddress(user1),MAX_PER_WALLET,"should track max mint per address");
    }

    /**
     * @dev Test successful whitelist minting
     Whitelisted user should be able to mint when whitelist is enabled

     */
      function test_WhitelistMint_Success() public {
        // Arrange: Add user to whitelist and enable whitelist minting
        address[] memory toWhitelist = new address[](1);
        toWhitelist[0] = user1;
        
        vm.startPrank(owner);
        nft.addToWhitelist(toWhitelist);           // Add to whitelist
        nft.setWhitelistMintEnabled(true);         // Enable whitelist minting
        vm.stopPrank();
        
        // Verify user is whitelisted
        assertTrue(nft.isWhitelisted(user1), "User should be whitelisted");
        
        // Act: Whitelist mint
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(user1);
        
        // Assert: Verify mint was successful
        assertEq(nft.balanceOf(user1), 1, "Whitelisted user should have 1 token");
        assertEq(nft.mintedByAddress(user1), 1, "Should track whitelist mint");
    }

       /**
     * @dev Test whitelist minting fails when not enabled
     * Should fail even for whitelisted users if whitelist minting is disabled
     */
    function test_WhitelistMint_NotEnabled() public {
        // Arrange: Add user to whitelist but don't enable whitelist minting
        address[] memory toWhitelist = new address[](1);
        toWhitelist[0] = user1;
        
        vm.prank(owner);
        nft.addToWhitelist(toWhitelist);
        // Note: whitelist minting remains disabled
        
        // Act & Assert: Should fail even though user is whitelisted
        vm.prank(user1);
        vm.expectRevert(MyNFT.WhitelistMintNotEnabled.selector);
        nft.whitelistMint{value: MINT_PRICE}(user1);
    }
    
    /**
     * @dev Test whitelist minting fails for non-whitelisted users
     * Should reject minting attempts from users not on whitelist
     */
    function test_WhitelistMint_NotWhitelisted() public {
        // Arrange: Enable whitelist minting but don't whitelist user1
        vm.prank(owner);
        nft.setWhitelistMintEnabled(true);
        
        // Verify user is not whitelisted
        assertFalse(nft.isWhitelisted(user1), "User should not be whitelisted");
        
        // Act & Assert: Non-whitelisted user should not be able to mint
        vm.prank(user1);
        vm.expectRevert(MyNFT.NotWhitelisted.selector);
        nft.whitelistMint{value: MINT_PRICE}(user1);
    }

    // =============================================================
    //                        ACCESS CONTROL TESTS
    // =============================================================

    function test_OnlyMinterCanBatchMint()public{
        address[] memory recipients = new address[](1);
        recipients[0]= user1;

        vm.prank(hacker);
        vm.expectRevert();
        nft.batchMint(recipients);
    }

    
}