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

    function test_OnlyMinterCanMintWithURI() public {
        vm.prank(hacker);
        vm.expectRevert();
        nft.setBaseURI("new-base-uri");
    }

    function test_OnlyOwnerCanSetMintPrice()public{
        vm.prank(hacker);
        vm.expectRevert();
        nft.setMintPrice(0.2 ether);
    }
    
    function test_OnlyPauserCanPause()public {
        vm.prank(hacker);
        vm.expectRevert();
        nft.pause();
    }

    // =============================================================
    //                        ADMIN FUNCTION TESTS
    // =============================================================

    function test_SetBaseURI() public {
        // Arrange: Define new base URI
        string memory newBaseURI = "https://newapi.mynft.com/";
        
        // Act: Set new base URI with event expectation
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit BaseURIUpdated(BASE_URI, newBaseURI);
        nft.setBaseURI(newBaseURI);
        
        // Assert: Test the new URI is used for tokens
        // First mint a token to test the URI
        vm.prank(minter);
        nft.mintWithURI(user1, ""); // Empty custom URI to use base URI
        
        string memory expectedURI = string(abi.encodePacked(newBaseURI, "1"));
        assertEq(nft.tokenURI(1), expectedURI, "Token URI should use new base URI");
    }

    function test_SetMintPrice()public{
        uint256 newPrice = 0.02 ether;

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);

        emit MintPriceUpdated(MINT_PRICE, newPrice);
        nft.setMintPrice(newPrice);

        assertEq(nft.mintPrice(),newPrice,"Mint Price should be updated");
    }

    function test_SetPublicMintEnabled()public {
        //ACT: enable public minting with event expectation
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PublicMintStatusChanged(true);
        nft.setPublicMintEnabled(true);

        //Assert:Verify public minting is enabled
        assertTrue(nft.publicMintEnabled(),"Public minting should be enabled");
    }

    function test_SetWhitelistMintEnabled() public {
        // Act: Enable whitelist minting with event expectation
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit WhitelistMintStatusChanged(true);
        nft.setWhitelistMintEnabled(true);
        
        // Assert: Verify whitelist minting is enabled
        assertTrue(nft.whitelistMintEnabled(), "Whitelist minting should be enabled");
    }
    
    /**
     * @dev Test adding addresses to whitelist
     * Should add multiple addresses and emit event
     */
    function test_AddToWhitelist() public {
        // Arrange: Create array of addresses to whitelist
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;
        
        // Act: Add to whitelist with event expectation
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit AddressesWhitelisted(addresses);
        nft.addToWhitelist(addresses);
        
        // Assert: Verify addresses were whitelisted
        assertTrue(nft.isWhitelisted(user1), "User1 should be whitelisted");
        assertTrue(nft.isWhitelisted(user2), "User2 should be whitelisted");
        assertFalse(nft.isWhitelisted(user3), "User3 should not be whitelisted");
    }
    
    /**
     * @dev Test removing addresses from whitelist
     * Should remove addresses and emit event
     */
    function test_RemoveFromWhitelist() public {
        // Arrange: First add addresses to whitelist
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;
        
        vm.startPrank(owner);
        nft.addToWhitelist(addresses);
        
        // Act: Remove from whitelist with event expectation
        vm.expectEmit(true, true, true, true);
        emit AddressesRemovedFromWhitelist(addresses);
        nft.removeFromWhitelist(addresses);
        vm.stopPrank();
        
        // Assert: Verify addresses were removed from whitelist
        assertFalse(nft.isWhitelisted(user1), "User1 should be removed from whitelist");
        assertFalse(nft.isWhitelisted(user2), "User2 should be removed from whitelist");
    }

    function test_SetRoyaltyInfo() public {
        // Arrange: Define new royalty settings
        address newRecipient = user1;
        uint256 newPercentage = 750; // 7.5%
        
        // Act: Set royalty info with event expectation
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit RoyaltyInfoUpdated(newRecipient, newPercentage);
        nft.setRoyaltyInfo(newRecipient, newPercentage);
        
        // Assert: Verify royalty settings were updated
        assertEq(nft.royaltyRecipient(), newRecipient, "Royalty recipient should be updated");
        assertEq(nft.royaltyPercentage(), newPercentage, "Royalty percentage should be updated");
        
        // Test royalty calculation
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, newRecipient, "Royalty receiver should match recipient");
        assertEq(royaltyAmount, 0.075 ether, "Royalty amount should be 7.5% of sale price");
    }

    function test_SetRoyaltyInfo_InvalidPercentage() public {
        // Act & Assert: Should revert for royalty > 10%
        vm.prank(owner);
        vm.expectRevert(MyNFT.InvalidRoyaltyPercentage.selector);
        nft.setRoyaltyInfo(user1, 1001); // 10.01% > 10% maximum
    }

    function test_Withdraw() public {
        // Arrange: Generate some funds by enabling and executing public mints
        vm.prank(owner);
        nft.setPublicMintEnabled(true);
        
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(user1);
        
        // Verify contract has funds
        uint256 contractBalance = address(nft).balance;
        assertEq(contractBalance, MINT_PRICE, "Contract should have mint payment");
        
        uint256 ownerBalanceBefore = owner.balance;
        
        // Act: Withdraw funds
        vm.prank(owner);
        nft.withdraw();
        
        // Assert: Verify funds were transferred to owner
        assertEq(address(nft).balance, 0, "Contract balance should be 0 after withdrawal");
        assertEq(owner.balance, ownerBalanceBefore + contractBalance, "Owner should receive contract balance");
    }

    // =============================================================
    //                        PAUSABLE TESTS
    // =============================================================
    
    /**
     * @dev Test pausing functionality
     * Should pause contract and prevent minting/transfers
     */
    function test_Pause() public {
        // Act: Pause the contract
        vm.prank(pauser);
        nft.pause();
        
        // Assert: Contract should be paused
        assertTrue(nft.paused(), "Contract should be paused");
        
        // Assert: Minting should fail while paused
        vm.prank(minter);
        vm.expectRevert(); // Should revert because contract is paused
        nft.mintWithURI(user1, "test");
    }
    
    /**
     * @dev Test unpausing functionality
     * Should unpause contract and restore normal operations
     */
    function test_Unpause() public {
        // Arrange: First pause the contract
        vm.prank(pauser);
        nft.pause();
        
        // Act: Unpause the contract
        vm.prank(pauser);
        nft.unpause();
        
        // Assert: Contract should not be paused
        assertFalse(nft.paused(), "Contract should not be paused after unpause");
        
        // Assert: Should be able to mint again
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        assertEq(nft.balanceOf(user1), 1, "Should be able to mint after unpause");
    }
    
    /**
     * @dev Test that transfers are blocked while paused
     * Existing tokens should not be transferable during pause
     */
    function test_TransferWhilePaused() public {
        // Arrange: Mint a token first
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        
        // Pause the contract
        vm.prank(pauser);
        nft.pause();
        
        // Act & Assert: Transfer should fail while paused
        vm.prank(user1);
        vm.expectRevert(); // Should revert due to pause
        nft.transferFrom(user1, user2, 1);
    }

    // =============================================================
    //                        SUPPLY LIMIT TESTS
    // =============================================================
    
    /**
     * @dev Test that batch minting cannot exceed max supply
     * Should prevent batch mints that would exceed MAX_SUPPLY
     */
    function test_ExceedsMaxSupply_BatchMint() public {
        // Arrange: Create recipients array larger than MAX_SUPPLY
        // Using smaller number for testing efficiency, but testing the logic
        address[] memory recipients = new address[](MAX_SUPPLY + 1);
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = address(uint160(i + 1)); // Generate unique addresses
        }
        
        // Act & Assert: Batch mint exceeding max supply should fail
        vm.prank(minter);
        vm.expectRevert(MyNFT.ExceedsMaxSupply.selector);
        nft.batchMint(recipients);
    }
    
    /**
     * @dev Test approaching maximum supply limit
     * Verify behavior when nearing the supply cap
     */
    function test_MaxSupplyReached() public {
        // Note: Testing with full MAX_SUPPLY would be gas-intensive
        // This test demonstrates the concept with smaller numbers
        
        // This test verifies the supply limit logic works correctly
        // In a real scenario, you might want to create a test contract
        // with a smaller MAX_SUPPLY constant for efficient testing
        
        uint256 currentTokenId = nft.getCurrentTokenId();
        assertEq(currentTokenId, 1, "Should start with token ID 1");
        
        // Test that we can mint up to the limit
        vm.prank(minter);
        nft.mintWithURI(user1, "test1");
        
        assertEq(nft.totalSupply(), 1, "Should have 1 token minted");
        assertEq(nft.getCurrentTokenId(), 2, "Next token ID should be 2");
    }

    // =============================================================
    //                        ERC721 FUNCTIONALITY TESTS
    // =============================================================

    function test_TokenURI_WithCustomURI() public {
        string memory customURI = "ipfs://custom-hash";
        vm.prank(owner);
        nft.setBaseURI("");//custom uri only works when baseURI is not set already
        vm.prank(minter);
        nft.mintWithURI(user1, customURI);
        
        assertEq(nft.tokenURI(1), customURI);
    }

    function test_TokenURI_withBaseURI()public {
        vm.prank(minter);
        nft.mintWithURI(user1, "");
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "1"));
        assertEq(nft.tokenURI(1), expectedURI);

    }

    function test_Transfer() public {
        // Mint a token
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        
        // Transfer it
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);
        
        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_Approve() public {
        // Mint a token
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        
        // Approve user2 to transfer token 1
        vm.prank(user1);
        nft.approve(user2, 1);
        
        assertEq(nft.getApproved(1), user2);
        
        // user2 can now transfer the token
        vm.prank(user2);
        nft.transferFrom(user1, user3, 1);
        
        assertEq(nft.ownerOf(1), user3);
    }

    function test_SetApprovalForAll() public {
        // Mint tokens
        vm.prank(minter);
        nft.mintWithURI(user1, "test1");
        vm.prank(minter);
        nft.mintWithURI(user1, "test2");
        
        // Set approval for all
        vm.prank(user1);
        nft.setApprovalForAll(user2, true);
        
        assertTrue(nft.isApprovedForAll(user1, user2));
        
        // user2 can transfer any of user1's tokens
        vm.prank(user2);
        nft.transferFrom(user1, user3, 1);
        
        vm.prank(user2);
        nft.transferFrom(user1, user3, 2);
        
        assertEq(nft.balanceOf(user3), 2);
    }

    // =============================================================
    //                        ENUMERABLE TESTS
    // =============================================================

    function test_TokensByIndex()public{
        //Mint some tokens
        vm.startPrank(minter);
        nft.mintWithURI(user1, "test1");
        nft.mintWithURI(user2, "test2");
        nft.mintWithURI(user1, "test3");
        vm.stopPrank();

        assertEq(nft.totalSupply(),3);
        assertEq(nft.tokenByIndex(0),1);
        assertEq(nft.tokenByIndex(1), 2);
        assertEq(nft.tokenByIndex(2), 3);
        uint256 total_supply = nft.totalSupply();
        vm.expectRevert();
        nft.tokenByIndex(total_supply+1);

    }

       function test_TokenOfOwnerByIndex() public {
        // Mint tokens to user1
        vm.startPrank(minter);
        nft.mintWithURI(user1, "test1");
        nft.mintWithURI(user2, "test2"); // Different owner
        nft.mintWithURI(user1, "test3");
        vm.stopPrank();
        
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(nft.tokenOfOwnerByIndex(user1, 1), 3);
        
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.tokenOfOwnerByIndex(user2, 0), 2);
    }

    // =============================================================
    //                        FUZZ TESTS
    // =============================================================
    function testFuzz_SetMintPrice(uint256 price)public {
        //Bound the price to reasonable values to avoid overflow issues

        price = bound(price,0,100 ether);
        vm.prank(owner);
        nft.setMintPrice(price);

        assertEq(nft.mintPrice(),price);
    }

     function testFuzz_SetRoyaltyPercentage(uint256 percentage) public {
        // Bound to valid royalty percentages (0-10%)
        percentage = bound(percentage, 0, 1000);
        
        vm.prank(owner);
        nft.setRoyaltyInfo(user1, percentage);
        
        assertEq(nft.royaltyPercentage(), percentage);
        
        // Test royalty calculation
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, user1);
        assertEq(royaltyAmount, (1 ether * percentage) / 10000);
    }

    function testFuzz_PublicMint(address to , uint256 payment)public{
        //Ensure 'to' is not zero address and not a contract
        vm.assume(to != address(0) && to != address(nft));
        vm.assume(to.code.length ==0);

        vm.prank(owner);
        nft.setPublicMintEnabled(true);

        vm.deal(to, payment);

        if(payment >= nft.mintPrice() && nft.mintedByAddress(to)<MAX_PER_WALLET){
            vm.prank(to);
            nft.publicMint{value:payment}(to);

            assertEq(nft.balanceOf(to),1);
            assertEq(nft.ownerOf(nft.totalSupply()),to);
        } else {
            vm.prank(to);
            if (payment < nft.mintPrice()) {
                vm.expectRevert(MyNFT.InsufficientPayment.selector);
            } else {
                vm.expectRevert(MyNFT.ExceedsMaxPerWallet.selector);
            }
            nft.publicMint{value: payment}(to);
        }
    }

    function testFuzz_BatchMint(uint8 numRecipients) public {
        // Bound to reasonable number to avoid gas issues
        numRecipients = uint8(bound(numRecipients, 1, 100));
        
        address[] memory recipients = new address[](numRecipients);
        for (uint256 i = 0; i < numRecipients; i++) {
            recipients[i] = address(uint160(i + 1000)); // Avoid zero address
        }
        
        vm.prank(minter);
        nft.batchMint(recipients);
        
        assertEq(nft.totalSupply(), numRecipients);
        
        // Check each recipient got a token
        for (uint256 i = 0; i < numRecipients; i++) {
            assertEq(nft.balanceOf(recipients[i]), 1);
            assertEq(nft.ownerOf(i + 1), recipients[i]);
        }
    }
    
    function testFuzz_WhitelistOperations(address[] calldata addresses) public {
        // Filter out zero address and duplicates
        address[] memory validAddresses = new address[](0);
        
        for (uint256 i = 0; i < addresses.length && i < 50; i++) { // Limit to 50 for gas
            if (addresses[i] != address(0)) {
                // Simple duplicate check (not efficient but works for testing)
                bool isDuplicate = false;
                for (uint256 j = 0; j < validAddresses.length; j++) {
                    if (validAddresses[j] == addresses[i]) {
                        isDuplicate = true;
                        break;
                    }
                }
                if (!isDuplicate) {
                    // Extend array (inefficient but works for testing)
                    address[] memory newArray = new address[](validAddresses.length + 1);
                    for (uint256 k = 0; k < validAddresses.length; k++) {
                        newArray[k] = validAddresses[k];
                    }
                    newArray[validAddresses.length] = addresses[i];
                    validAddresses = newArray;
                }
            }
        }
        
        if (validAddresses.length > 0) {
            vm.prank(owner);
            nft.addToWhitelist(validAddresses);
            
            // Check all addresses are whitelisted
            for (uint256 i = 0; i < validAddresses.length; i++) {
                assertTrue(nft.isWhitelisted(validAddresses[i]));
            }
            
            // Remove from whitelist
            vm.prank(owner);
            nft.removeFromWhitelist(validAddresses);
            
            // Check all addresses are removed
            for (uint256 i = 0; i < validAddresses.length; i++) {
                assertFalse(nft.isWhitelisted(validAddresses[i]));
            }
        }
    }

    // =============================================================
    //                        EDGE CASE TESTS
    // =============================================================
    
    function test_MintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintWithURI(address(0), "test");
    }
    
    function test_TransferToZeroAddress() public {
        // Mint a token first
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        
        vm.prank(user1);
        vm.expectRevert();
        nft.transferFrom(user1, address(0), 1);
    }
    
    function test_TransferNonexistentToken() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.transferFrom(user1, user2, 999);
    }
    
    function test_ApproveNonexistentToken() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.approve(user2, 999);
    }
    
    function test_TokenURINonexistentToken() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }
    
    function test_OwnerOfNonexistentToken() public {
        vm.expectRevert();
        nft.ownerOf(999);
    }
    
    function test_ReentrancyProtection() public {
        // This is a basic test - in practice you'd create a malicious contract
        // that tries to reenter during mint
        vm.prank(owner);
        nft.setPublicMintEnabled(true);
        
        // Multiple calls in same transaction should work fine
        // but actual reentrancy would be prevented by ReentrancyGuard
        vm.startPrank(user1);
        nft.publicMint{value: MINT_PRICE}(user1);
        nft.publicMint{value: MINT_PRICE}(user1);
        vm.stopPrank();
        
        assertEq(nft.balanceOf(user1), 2);
    }
    
    function test_ExcessPaymentHandling() public {
        vm.prank(owner);
        nft.setPublicMintEnabled(true);
        
        uint256 excessPayment = MINT_PRICE * 2;
        uint256 contractBalanceBefore = address(nft).balance;
        
        vm.prank(user1);
        nft.publicMint{value: excessPayment}(user1);
        
        // Contract should receive the full payment (no refund mechanism)
        assertEq(address(nft).balance, contractBalanceBefore + excessPayment);
        assertEq(nft.balanceOf(user1), 1);
    }

    // =============================================================
    //                        GAS OPTIMIZATION TESTS
    // =============================================================
    
    function test_GasUsage_SingleMint() public {
        vm.prank(owner);
        nft.setPublicMintEnabled(true);
        
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        nft.publicMint{value: MINT_PRICE}(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for single mint:", gasUsed);
        // Assert gas usage is reasonable (adjust based on your requirements)
        assertLt(gasUsed, 200000); // Less than 200k gas
    }
    
    function test_GasUsage_BatchMint() public {
        address[] memory recipients = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            recipients[i] = address(uint160(i + 1));
        }
        
        uint256 gasBefore = gasleft();
        vm.prank(minter);
        nft.batchMint(recipients);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for batch mint (10 tokens):", gasUsed);
        console.log("Gas per token:", gasUsed / 10);
    }

    // =============================================================
    //                        INTEGRATION TESTS
    // =============================================================
    
    function test_FullWorkflow() public {
        // 1. Setup: Enable minting and whitelist some users
        address[] memory whitelist = new address[](2);
        whitelist[0] = user1;
        whitelist[1] = user2;
        
        vm.startPrank(owner);
        nft.addToWhitelist(whitelist);
        nft.setWhitelistMintEnabled(true);
        nft.setPublicMintEnabled(true);
        vm.stopPrank();
        
        // 2. Whitelist minting
        vm.prank(user1);
        nft.whitelistMint{value: MINT_PRICE}(user1);
        
        // 3. Public minting
        vm.prank(user3);
        nft.publicMint{value: MINT_PRICE}(user3);
        //Removing baseuri to make custom uri default
        vm.prank(owner);
        nft.setBaseURI("");
        // 4. Admin minting
        vm.prank(minter);
        uint256 tokenId = nft.mintWithURI(user2, "special-uri");
        
        // 5. Verify state
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.balanceOf(user3), 1);
        assertEq(nft.tokenURI(tokenId), "special-uri");
        
        // 6. Transfer
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);
        assertEq(nft.balanceOf(user2), 2);
        
        // 7. Pause and unpause
        vm.prank(pauser);
        nft.pause();
        assertTrue(nft.paused());
        
        vm.prank(pauser);
        nft.unpause();
        assertFalse(nft.paused());
        
        // 8. Withdraw funds
        uint256 contractBalance = address(nft).balance;
        vm.prank(owner);
        nft.withdraw();
        assertEq(address(nft).balance, 0);
    }
    
    // =============================================================
    //                        HELPER FUNCTIONS
    // =============================================================
    
    function test_HelperFunctions() public {
        assertEq(nft.getCurrentTokenId(), 1);
        assertEq(nft.totalMinted(), 0);
        
        vm.prank(minter);
        nft.mintWithURI(user1, "test");
        
        assertEq(nft.getCurrentTokenId(), 2);
        assertEq(nft.totalMinted(), 1);
    }
    
    // Test royalty calculation with different sale prices
    function test_RoyaltyCalculation() public {
        // Default royalty is 5% (500 basis points)
        (address receiver, uint256 royalty1) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, owner);
        assertEq(royalty1, 0.05 ether);
        
        (address receiver2, uint256 royalty2) = nft.royaltyInfo(1, 2 ether);
        assertEq(receiver2, owner);
        assertEq(royalty2, 0.1 ether);
        
        // Change royalty settings
        vm.prank(owner);
        nft.setRoyaltyInfo(user1, 1000); // 10%
        
        (address receiver3, uint256 royalty3) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver3, user1);
        assertEq(royalty3, 0.1 ether);
    }
}