//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
    @title decentralizedStableCoin
    @author Ricardo Villcana
    Stable Coin Attributes:
        Collateral: Exogenous (Eth & Btc)
        Minting: Algorithmic
        Relative Stability: Pegged to USD
*/
contract decentralizedStableCoin is ERC20Burnable, Ownable {
    error decentralizedStableCoin__MustBeMoreThanZero();
    error decentralizedStableCoin__BurnAmountExceedsBalance();
    error decentralizedStableCoin__NotZeroAddress();

    //In the constructor we pass the name of the stable coin and its symbol
    constructor() ERC20("DegenDev", "DD") {}

    //The onlyOwner modifier comes from the Ownable contract we inherit from
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        //The amount of tokens that can be burned has to exceed zero
        //If it doesn't, revert the call of this function
        if (_amount <= 0) {
            revert decentralizedStableCoin__MustBeMoreThanZero();
        }
        //The amount of tokens being burned can't exceed the total balance of stable coins in the address that is calling this function
        if (balance < _amount) {
            revert decentralizedStableCoin__BurnAmountExceedsBalance();
        }
        //Using the function burn from the parent contract, ERC20Burnable, so we use the keyword "super" so that we don't call the burn function we just overided
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        //Cannot mint stable coins to the 0x000... address or the disposal address
        if (_to == address(0)) {
            revert decentralizedStableCoin__NotZeroAddress();
        }
        //Cannot mint a negative amount of stable coins
        if (_amount <= 0) {
            revert decentralizedStableCoin__MustBeMoreThanZero();
        }
        //Calling the parent _mint function from ERC20Burnable and we don't need the "super" keyword because we didn't override it
        _mint(_to, _amount);
        return true;
    }
}
