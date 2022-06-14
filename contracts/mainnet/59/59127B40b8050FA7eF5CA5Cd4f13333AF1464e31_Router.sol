//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// GENERATED CODE - do not edit manually!!
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

contract Router {
    error UnknownSelector(bytes4 sel);

    address private constant _ELECTION_INSPECTOR_MODULE = 0xbe897831ee9e19d83604612f205351629F2df30C;
    address private constant _ELECTION_MODULE = 0xED7947E253f84F7932278284a6B62387ee2EEEDD;
    address private constant _OWNER_MODULE = 0x823005379687567B5590fcc701CE4a9DeC7b4e09;
    address private constant _UPGRADE_MODULE = 0x27169242Fce0D089bc2114c49338C2Fa90424Ddc;

    fallback() external payable {
        _forward();
    }

    receive() external payable {
        _forward();
    }

    function _forward() internal {
        // Lookup table: Function selector => implementation contract
        bytes4 sig4 = msg.sig;
        address implementation;

        assembly {
            let sig32 := shr(224, sig4)

            function findImplementation(sig) -> result {
                if lt(sig,0x8625c053) {
                    if lt(sig,0x447068ef) {
                        if lt(sig,0x2810e1d6) {
                            if lt(sig,0x0ebf4796) {
                                switch sig
                                case 0x0166451a { result := _ELECTION_MODULE } // ElectionModule.initializeElectionModule()
                                case 0x0438d06e { result := _ELECTION_MODULE } // ElectionModule.setMinimumActiveMembers()
                                case 0x086146d2 { result := _ELECTION_MODULE } // ElectionModule.getCurrentPeriod()
                                case 0x09eef43e { result := _ELECTION_MODULE } // ElectionModule.hasVoted()
                                case 0x0a8b471a { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getBallotCandidatesInEpoch()
                                leave
                            }
                            switch sig
                            case 0x0ebf4796 { result := _ELECTION_MODULE } // ElectionModule.setDebtShareContract()
                            case 0x0f98dfba { result := _ELECTION_MODULE } // ElectionModule.getDefaultBallotEvaluationBatchSize()
                            case 0x1209644e { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.hasVotedInEpoch()
                            case 0x1627540c { result := _OWNER_MODULE } // OwnerModule.nominateNewOwner()
                            case 0x205569c2 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.wasNominated()
                            leave
                        }
                        switch sig
                        case 0x2810e1d6 { result := _ELECTION_MODULE } // ElectionModule.resolve()
                        case 0x2c3c5ba3 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getBallotVotesInEpoch()
                        case 0x33f3f3de { result := _ELECTION_MODULE } // ElectionModule.setCrossChainDebtShareMerkleRoot()
                        case 0x35eb2824 { result := _OWNER_MODULE } // OwnerModule.isOwnerModuleInitialized()
                        case 0x362c906d { result := _ELECTION_MODULE } // ElectionModule.getEpochEndDate()
                        case 0x3659cfe6 { result := _UPGRADE_MODULE } // UpgradeModule.upgradeTo()
                        case 0x37143233 { result := _ELECTION_MODULE } // ElectionModule.evaluate()
                        case 0x3a3e6c81 { result := _ELECTION_MODULE } // ElectionModule.isNominated()
                        case 0x3ac1c5fe { result := _ELECTION_MODULE } // ElectionModule.setMaxDateAdjustmentTolerance()
                        leave
                    }
                    if lt(sig,0x718fe928) {
                        if lt(sig,0x606a6b76) {
                            switch sig
                            case 0x447068ef { result := _ELECTION_MODULE } // ElectionModule.getNextEpochSeatCount()
                            case 0x49aed35c { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getBallotVotedAtEpoch()
                            case 0x4b5dacac { result := _ELECTION_MODULE } // ElectionModule.setNextEpochSeatCount()
                            case 0x53a47bb7 { result := _OWNER_MODULE } // OwnerModule.nominatedOwner()
                            case 0x54520478 { result := _ELECTION_MODULE } // ElectionModule.upgradeCouncilToken()
                            leave
                        }
                        switch sig
                        case 0x606a6b76 { result := _ELECTION_MODULE } // ElectionModule.getCouncilMembers()
                        case 0x624bd96d { result := _OWNER_MODULE } // OwnerModule.initializeOwnerModule()
                        case 0x64deab73 { result := _ELECTION_MODULE } // ElectionModule.setDefaultBallotEvaluationBatchSize()
                        case 0x655aaaca { result := _ELECTION_MODULE } // ElectionModule.getBallotCandidates()
                        case 0x714d8d0e { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getEpochStartDateForIndex()
                        leave
                    }
                    switch sig
                    case 0x718fe928 { result := _OWNER_MODULE } // OwnerModule.renounceNomination()
                    case 0x793b9a9d { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getCandidateVotesInEpoch()
                    case 0x796c5c80 { result := _ELECTION_MODULE } // ElectionModule.getDeclaredCrossChainDebtShare()
                    case 0x79ba5097 { result := _OWNER_MODULE } // OwnerModule.acceptOwnership()
                    case 0x7a3bc0ee { result := _ELECTION_MODULE } // ElectionModule.getBallotVotes()
                    case 0x7d264ccb { result := _ELECTION_MODULE } // ElectionModule.declareCrossChainDebtShare()
                    case 0x82e28473 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getVotingPeriodStartDateForIndex()
                    case 0x84ae670c { result := _ELECTION_MODULE } // ElectionModule.cast()
                    case 0x85160425 { result := _ELECTION_MODULE } // ElectionModule.getMinimumActiveMembers()
                    leave
                }
                if lt(sig,0xca80a2ed) {
                    if lt(sig,0xaeff252a) {
                        if lt(sig,0x9a25eaf3) {
                            switch sig
                            case 0x8625c053 { result := _ELECTION_MODULE } // ElectionModule.getMinEpochDurations()
                            case 0x8da5cb5b { result := _OWNER_MODULE } // OwnerModule.owner()
                            case 0x8f701997 { result := _ELECTION_MODULE } // ElectionModule.tweakEpochSchedule()
                            case 0x95ff6584 { result := _ELECTION_MODULE } // ElectionModule.getBallotVoted()
                            case 0x9636f67c { result := _ELECTION_MODULE } // ElectionModule.getNominees()
                            leave
                        }
                        switch sig
                        case 0x9a25eaf3 { result := _ELECTION_MODULE } // ElectionModule.dismissMembers()
                        case 0x9a9a8e1a { result := _ELECTION_MODULE } // ElectionModule.declareAndCast()
                        case 0xa0f42837 { result := _ELECTION_MODULE } // ElectionModule.setDebtShareSnapshotId()
                        case 0xa25a9f3a { result := _ELECTION_MODULE } // ElectionModule.setMinEpochDurations()
                        case 0xaaf10f42 { result := _UPGRADE_MODULE } // UpgradeModule.getImplementation()
                        leave
                    }
                    switch sig
                    case 0xaeff252a { result := _ELECTION_MODULE } // ElectionModule.getDebtShareContract()
                    case 0xb55c43d2 { result := _ELECTION_MODULE } // ElectionModule.getCrossChainDebtShareMerkleRoot()
                    case 0xb749be55 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getNominationPeriodStartDateForIndex()
                    case 0xba9a5b25 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getEpochEndDateForIndex()
                    case 0xbb9c0920 { result := _ELECTION_MODULE } // ElectionModule.getVotePower()
                    case 0xc07de0d3 { result := _ELECTION_MODULE } // ElectionModule.getCouncilToken()
                    case 0xc14d0528 { result := _ELECTION_MODULE } // ElectionModule.modifyEpochSchedule()
                    case 0xc5798523 { result := _ELECTION_MODULE } // ElectionModule.isElectionModuleInitialized()
                    case 0xc7f62cda { result := _UPGRADE_MODULE } // UpgradeModule.simulateUpgradeTo()
                    leave
                }
                if lt(sig,0xe327b585) {
                    switch sig
                    case 0xca80a2ed { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getNomineesAtEpoch()
                    case 0xcce32c52 { result := _ELECTION_INSPECTOR_MODULE } // ElectionInspectorModule.getElectionWinnersInEpoch()
                    case 0xce04e44c { result := _ELECTION_MODULE } // ElectionModule.getEpochStartDate()
                    case 0xd11801cf { result := _ELECTION_MODULE } // ElectionModule.withdrawNomination()
                    case 0xd82f25f0 { result := _ELECTION_MODULE } // ElectionModule.getCandidateVotes()
                    case 0xd83eb231 { result := _ELECTION_MODULE } // ElectionModule.withdrawVote()
                    case 0xd9617851 { result := _ELECTION_MODULE } // ElectionModule.getCrossChainDebtShareMerkleRootBlockNumber()
                    case 0xdfe7cd3a { result := _ELECTION_MODULE } // ElectionModule.getDebtShareSnapshotId()
                    case 0xe1509015 { result := _ELECTION_MODULE } // ElectionModule.getVotingPeriodStartDate()
                    leave
                }
                switch sig
                case 0xe327b585 { result := _ELECTION_MODULE } // ElectionModule.isElectionEvaluated()
                case 0xe420d7f9 { result := _ELECTION_MODULE } // ElectionModule.getNominationPeriodStartDate()
                case 0xedc968ba { result := _ELECTION_MODULE } // ElectionModule.calculateBallotId()
                case 0xee695137 { result := _ELECTION_MODULE } // ElectionModule.initializeElectionModule()
                case 0xf2516dbf { result := _ELECTION_MODULE } // ElectionModule.getElectionWinners()
                case 0xf2e56dea { result := _ELECTION_MODULE } // ElectionModule.getDebtShare()
                case 0xfcd7e1d7 { result := _ELECTION_MODULE } // ElectionModule.nominate()
                case 0xffe7f643 { result := _ELECTION_MODULE } // ElectionModule.getEpochIndex()
                case 0xfff17b8e { result := _ELECTION_MODULE } // ElectionModule.getMaxDateAdjustmenTolerance()
                leave
            }

            implementation := findImplementation(sig32)
        }

        if (implementation == address(0)) {
            revert UnknownSelector(sig4);
        }

        // Delegatecall to the implementation contract
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}