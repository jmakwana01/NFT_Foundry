// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyNFT.sol";

/**
 * @title DeployScript
 * @dev Script to deploy MyNFT contract using Foundry
 * @notice Run with: forge script script/Deploy.s.sol:DeployScript --broadcast --rpc-url <network>
 */
contract DeployScript is Script {
    // Deployment parameters - modify these as needed
    string constant NAME = "My NFT Collection";
    string constant SYMBOL = "MNC";
    string constant BASE_URI = "https://ipfs.io/ipfs/QmexAVFvkq3FREjk3yKJAi779y96jKjNJ4BATxRC7uCX6K";
    
    function run() external {
        // Get deployment parameters from environment variables or use defaults
        string memory name = vm.envOr("NFT_NAME", NAME);
        string memory symbol = vm.envOr("NFT_SYMBOL", SYMBOL);
        string memory baseURI = vm.envOr("NFT_BASE_URI", BASE_URI);
        
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the NFT contract
        MyNFT nft = new MyNFT(
            name,
            symbol,
            baseURI,
            deployer
        );
        
        console.log("MyNFT deployed at:", address(nft));
        
        // Optional: Set initial configuration
        // nft.setMintPrice(0.01 ether);
        // nft.setPublicMintEnabled(true);
        
        vm.stopBroadcast();
        
        // Log important information
        console.log("=== Deployment Summary ===");
        console.log("Contract Address:", address(nft));
        console.log("Contract Name:", nft.name());
        console.log("Contract Symbol:", nft.symbol());
        console.log("Owner:", nft.owner());
        console.log("Max Supply:", nft.MAX_SUPPLY());
        console.log("Mint Price:", nft.mintPrice());
        console.log("Public Mint Enabled:", nft.publicMintEnabled());
        
        // Save deployment info to file for reference
        string memory deploymentInfo = string(abi.encodePacked(
            '{\n',
            '  "contractAddress": "', vm.toString(address(nft)), '",\n',
            '  "contractName": "', name, '",\n',
            '  "contractSymbol": "', symbol, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "network": "', vm.envOr("NETWORK_NAME", string("unknown")), '",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '"\n',
            '}'
        ));
        
        vm.writeFile("deployments/latest.json", deploymentInfo);
        console.log("Deployment info saved to deployments/latest.json");
    }
}