// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./LotterySingle.sol";

contract LotteryFactory {
    LotterySingle[] public lotteries;
    uint256 public creationFee = 1 * 1e17; // 0.1 ether

    address public treasury = 0xe34010A5cb2F412B4D17d034B4aEa9A29Ba9E024;

    event LotteryCreated(address indexed lotteryAddress);

    modifier onlyTreasury() {
        require(msg.sender == treasury);
        _;
    }

    function createLottery(
        uint256 startTime,
        uint256 duration,
        IERC20 token,
        uint256 ticketPrice,
        uint8 decimals,
        uint256 maxTicketsPerWallet,
        uint256[] memory shares,
        uint256 creatorFee // Dynamic array for shares
    ) public payable returns (address) {
        require(shares.length > 0, "Invalid number of shares");
        require(creatorFee <= 30, "can't set more than 30% as creatorFee");

        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 100, "Shares must total 100%");

        // Transfer Ether and revert the transaction if the transfer fails
        (bool sent, ) = treasury.call{value: creationFee}("");
        require(sent, "Failed to send Ether");

        LotterySingle newLottery = new LotterySingle(
            startTime,
            duration,
            token,
            ticketPrice,
            decimals,
            maxTicketsPerWallet,
            shares,
            creatorFee
        );
        lotteries.push(newLottery);
        emit LotteryCreated(address(newLottery));

        return address(newLottery);
    }

    function getLotteries() public view returns (LotterySingle[] memory) {
        return lotteries;
    }

    function updateTreasury(address _treasury) external onlyTreasury {
        require(_treasury != address(0), "Can't set zero address");

        treasury = _treasury;
    }
}
