// SPDX-License-Identifier: UNLICENSED
// Copyright (c) Eywa.Fi, 2021-2024 - all rights reserved
pragma solidity 0.8.28;

interface IDistributionCreator {
    /// @notice Parameters defining a campaign.
    /// @param campaignId ID of the campaign. This can be left as a null bytes32 when creating campaigns on Merkl.
    /// @param creator Address of the campaign creator. If marked as address(0),
    /// it will be overridden with the address of the `msg.sender` creating the campaign.
    /// @param rewardToken Address of the token used as a reward.
    /// @param amount Total amount of `rewardToken` to distribute across all the epochs.
    /// The amount distributed per epoch is `amount/numEpoch`.
    /// @param campaignType Type of the campaign. Different campaign types can have specific rules and behaviors.
    /// @param startTimestamp Timestamp indicating when the campaign should start.
    /// @param duration Duration of the campaign in seconds. Must be a multiple of the EPOCH duration, which is 3600 seconds.
    /// @param campaignData Additional data to specify further details of the campaign.
    struct CampaignParameters {
        bytes32 campaignId;
        address creator;
        address rewardToken;
        uint256 amount;
        uint32 campaignType;
        uint32 startTimestamp;
        uint32 duration;
        bytes campaignData;
    }

    /// @notice Creates a new `campaign` to incentivize a specified pool over a certain period.
    /// @dev The campaign must be well-formed; otherwise, it will not be processed by the campaign script, and rewards could be lost.
    /// Reward tokens used in campaigns must be whitelisted beforehand, and the amount sent must exceed the minimum amount set for each token.
    /// This function reverts if the sender has not accepted the terms and conditions.
    /// @param newCampaign_ The parameters of the campaign being created.
    /// @return The unique ID of the newly created campaign.
    function createCampaign(
        CampaignParameters memory newCampaign_
    ) external returns (bytes32);

    /// @notice Checks whether the `msg.sender`'s `signature` is compatible with the message to sign and stores the signature.
    /// @dev If you signed the message once, and the message has not been modified, then you do not need to sign again.
    function sign(bytes calldata signature_) external;

    /// @notice Sets the minimum amounts per distribution epoch for different reward tokens.
    function setRewardTokenMinAmounts(
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external;

    /// @notice Returns the minimum amount for the specified reward token that must be sent per epoch for a valid distribution.
    /// @param rewardToken_ The address of the reward token.
    /// @return The minimum amount of the token required for a valid distribution.
    function rewardTokenMinAmounts(
        address rewardToken_
    ) external view returns (uint256);

    /// @notice Message that needs to be acknowledged by users creating a campaign.
    function message() external view returns (string memory);
}
