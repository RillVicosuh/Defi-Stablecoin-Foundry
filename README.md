# Defi Stable Coin

**Etherscan Link**: https://sepolia.etherscan.io/address/0x0bcd78eac4c55ce6f64b37db2b45abad5ad37e28#writeContract

## Introduction

This Decentralized Stable Coin (DSC) is a robust and decentralized stable coin implementation built on Ethereum. DSC is algorithmically minted and is collateralized by a combination of exogenous digital assets, specifically Ether (ETH) and Bitcoin (BTC). The DSC token is pegged to the US Dollar for stability. 

## Project Structure

This project is comprised of three main parts:

1. **DSCEngine:** The DSCEngine is the smart contract that acts as the logic for the stable coin. This contract provides functionality to mint and burn DSC tokens based on provided collateral and maintains the value of DSC pegged to USD.

2. **decentralizedStableCoin:** The decentralizedStableCoin contract serves as the base layer of DSC. It defines the basic functionalities of the stable coin including its ERC20 properties and allows the owner (the DSCEngine contract) to mint or burn tokens.

3. **DeploySC:** DeploySC is a script that orchestrates the deployment of the above smart contracts. It establishes the appropriate dependencies between contracts (like assigning ownership of the `decentralizedStableCoin` to `DSCEngine`).

## Getting Started

To run the project, you first need to compile and deploy the contracts to the Ethereum network. Here are the steps to do so:

1. Compile the contracts: 
    ```sh
   forge build
    ```

2. Deploy the contracts using the `DeploySC` script. 

## Testing

This project includes a comprehensive test suite to validate the functionality of the DSC system. To run the tests, use the following command:

```sh
forge test
```

This will run all the tests located in the `test/` directory. The tests validate the functionality of both `DSCEngine` and `decentralizedStableCoin` contracts, checking the correctness of token minting, burning, and the interaction between the two contracts.

## Contact

For further information or if you encounter any issues, please contact the project author, Ricardo Villacana(ricardovill77@gmail.com).

## License

This project is licensed under the MIT License.
