/**
 *Submitted for verification at optimistic.etherscan.io on 2022-07-11
*/

pragma abicoder v2;
pragma solidity ^0.7.6;

interface IERC20String {
    function symbol() external view returns (string memory);

    function name() external view returns (string memory);
}

interface IERC20Bytes32 {
    function symbol() external view returns (bytes32);

    function name() external view returns (bytes32);
}

interface IERC20Decimals { 
    function decimals() external view returns(uint8);
}
interface IERC20Balance {
    function balanceOf(address) external view returns (uint);
}

contract TokenInfo {
    struct Info {
        string symbol;
        string name;
        uint8 decimals;
        address contract_address;
        uint256 balance;
    }

    function getInfoBatch(address user, address[] memory tokens)
        external
        view
        returns (Info[] memory infos)
    {
        Info[] memory infos = new Info[](tokens.length);
        for (uint8 i = 0; i < tokens.length; i++) {
            Info memory info;
            infos[i] = this.getInfo(user, tokens[i]);
        }
        return infos;
    }

    function getInfo(address user, address token) external view returns (Info memory info) {
        // Does code exists for the token?
        uint32 size;
        assembly {
            size := extcodesize(token)
        }
        if (size == 0) {
            return info;
        }

        info.contract_address = token;
        info.decimals = this.getDecimals(token);
        info.balance = this.getBalance(user, token);

        try this.getStringProperties(token) returns (
            string memory _symbol,
            string memory _name
        ) {
            info.symbol = _symbol;
            info.name = _name;
            return info;
        } catch {}
        try this.getBytes32Properties(token) returns (
            string memory _symbol,
            string memory _name
        ) {
            info.symbol = _symbol;
            info.name = _name;
            return info;
        } catch {}
    }
function getBalance(address user, address token) 
external
view 
returns (uint256 balance)
{
    balance = IERC20Balance(token).balanceOf(user);
}

function getDecimals(address token) 
external
view 
returns (uint8 decimals)
{
    decimals = IERC20Decimals(token).decimals();
}

    function getStringProperties(address token)
        external
        view
        returns (string memory symbol, string memory name)
    {
        symbol = IERC20String(token).symbol();
        name = IERC20String(token).name();
    }

    function getBytes32Properties(address token)
        external
        view
        returns (string memory symbol, string memory name)
    {
        bytes32 symbolBytes32 = IERC20Bytes32(token).symbol();
        bytes32 nameBytes32 = IERC20Bytes32(token).name();
        symbol = bytes32ToString(symbolBytes32);
        name = bytes32ToString(nameBytes32);
    }

    function bytes32ToString(bytes32 _bytes32)
        internal
        pure
        returns (string memory)
    {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}