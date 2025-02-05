//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDistributionCreator} from "./IDistributionCreator.sol";

interface WrappedSonic is IERC20 {
    function deposit() external payable;
}

contract JayFeeSplitter is Ownable2Step, ReentrancyGuard {
    /*
     * Name: splitFees
     * Purpose: Tranfer SONIC to guage and team
     * Parameters: n/a
     * Return: n/a
     */
    using SafeERC20 for WrappedSonic;
    address payable private TEAM_WALLET;

    uint256 public lastDistributionBlock;

    /// @notice The address of the Merkl distribution contract on Arbitrum.
    IDistributionCreator public constant DISTRIBUTION_CREATOR =
        IDistributionCreator(0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd);

    /// @notice The wSONIC token used for rewards distribution within the gauge.
    address public wS;

    /// @notice The campaign parameters used for reward distribution.
    IDistributionCreator.CampaignParameters public s_campaignParameters;

    event RewardNotified(uint256 indexed amount);

    event CampaignParametersUpdated(
        address indexed gauge,
        IDistributionCreator.CampaignParameters oldCampaignParameters,
        IDistributionCreator.CampaignParameters newCampaignParameters
    );
    constructor(
        address sonic_,
        IDistributionCreator.CampaignParameters memory campaignParameters_
    ) Ownable(msg.sender) {
        wS = sonic_;
        s_campaignParameters = campaignParameters_;
        lastDistributionBlock = block.timestamp;
    }

    function updateCampaignParameters(
        IDistributionCreator.CampaignParameters calldata newCampaignParameters_
    ) external onlyOwner {
        emit CampaignParametersUpdated(
            address(this),
            s_campaignParameters,
            newCampaignParameters_
        );
        s_campaignParameters = newCampaignParameters_;
    }

    receive() external payable {
        notifyRewardAmount(msg.value);
    }
    function notifyRewardAmount(uint256 amount_) internal {
        uint256 duration = block.timestamp - lastDistributionBlock;
        if (duration >= 1 weeks) {
            WrappedSonic m_sonic = WrappedSonic(wS);
            uint256 m_balance = address(this).balance / (2);
            m_sonic.deposit{value: m_balance}();
            if (
                (m_balance * 1 hours) / duration >=
                DISTRIBUTION_CREATOR.rewardTokenMinAmounts(address(m_sonic))
            ) {
                m_sonic.approve(address(DISTRIBUTION_CREATOR), m_balance);
                IDistributionCreator.CampaignParameters
                    memory m_campaignParameters = s_campaignParameters;
                m_campaignParameters.amount = m_balance;
                m_campaignParameters.startTimestamp = uint32(
                    lastDistributionBlock
                );
                m_campaignParameters.duration = uint32(block.timestamp);
                DISTRIBUTION_CREATOR.createCampaign(m_campaignParameters);
                sendSonic(TEAM_WALLET, m_balance);
                lastDistributionBlock = block.timestamp;
            }
        }
        emit RewardNotified(amount_);
    }

    function setTEAMWallet(address _address) external onlyOwner {
        require(_address != address(0x0));
        TEAM_WALLET = payable(_address);
    }

    /*
     * Name: sendSonic
     * Purpose: Tranfer SONIC tokens
     * Parameters:
     *    - @param 1: Address
     *    - @param 2: Value
     * Return: n/a
     */
    function sendSonic(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "SONIC Transfer failed.");
    }
}
