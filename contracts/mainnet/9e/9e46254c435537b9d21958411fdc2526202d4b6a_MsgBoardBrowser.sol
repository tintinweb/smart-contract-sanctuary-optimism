// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "./IMsgBoard.sol";

contract MsgBoardBrowser {
  struct BoardStats {
    string name;
    string symbol;
    address owner;
    uint created;
    uint msgCount;
    address[] moderators;
    int256 balance;
  }
  function stats(IMsgBoard[] memory board, address account) public view returns(BoardStats[] memory out) {
    out = new BoardStats[](board.length);
    for(uint i; i<board.length; i++){
      out[i] = BoardStats({
        name: board[i].name(),
        symbol: board[i].symbol(),
        owner: board[i].owner(),
        created: board[i].created(),
        msgCount: board[i].msgCount(),
        moderators: board[i].listModerators(),
        balance: board[i]._balanceOf(account)
      });
    }
  }

  struct MsgView {
    IMsgBoard.Msg item;
    uint8 vote;
  }

  struct ChildrenResponse {
    MsgView[] items;
    uint totalCount;
    uint lastScanned;
  }

  function fetchLatest(IMsgBoard board, address key, address voter) public view returns(MsgView memory) {
    uint versionCount = board.versionCount(key);
    require(versionCount > 0);

    IMsgBoard.Msg memory out = board.getMsg(key, 0);
    out.childCount = board.childCount(key);
    out.versionCount = versionCount;

    if(versionCount > 1) {
      out.data = board.getMsg(key, versionCount - 1).data;
    }
    return MsgView(out, board.votes(voter, key));
  }

  function fetchChildren(IMsgBoard board, address key, uint8 maxStatus, uint startIndex, uint fetchCount, address voter, bool reverseScan) external view returns(ChildrenResponse memory) {
    uint childCount = board.childCount(key);
    if(childCount == 0) return ChildrenResponse(new MsgView[](0), 0, 0);
    require(startIndex < childCount);
    if(startIndex + fetchCount >= childCount) {
      fetchCount = childCount - startIndex;
    }
    MsgView[] memory selection = new MsgView[](fetchCount);
    uint activeCount;
    uint i;
    uint childIndex = startIndex;
    if(reverseScan && startIndex == 0) {
      childIndex = childCount - 1;
    }
    while(activeCount < fetchCount && childIndex < childCount) {
      selection[i] = fetchLatest(board, board.msgChildren(key, childIndex), voter);
      if(selection[i].item.status <= maxStatus) activeCount++;
      if(reverseScan) {
        if(childIndex == 0 || activeCount == fetchCount) break;
        childIndex--;
      } else {
        childIndex++;
      }
      i++;
    }

    MsgView[] memory out = new MsgView[](activeCount);
    uint j;
    for(i=0; i<fetchCount; i++) {
      if(selection[i].item.status <= maxStatus) {
        out[j++] = selection[i];
      }
    }
    return ChildrenResponse(out, childCount, childIndex);
  }

  function fetchByAuthor(IMsgBoard board, address author, uint8 maxStatus, uint startIndex, uint fetchCount, address voter, bool reverseScan) external view returns(ChildrenResponse memory) {
    uint childCount = board.authorCount(author);
    if(childCount == 0) return ChildrenResponse(new MsgView[](0), 0, 0);
    require(startIndex < childCount);
    if(startIndex + fetchCount >= childCount) {
      fetchCount = childCount - startIndex;
    }
    MsgView[] memory selection = new MsgView[](fetchCount);
    uint activeCount;
    uint i;
    uint childIndex = startIndex;
    if(reverseScan && startIndex == 0) {
      childIndex = childCount - 1;
    }
    while(activeCount < fetchCount && childIndex < childCount) {
      selection[i] = fetchLatest(board, board.msgsByAuthor(author, childIndex), voter);
      if(selection[i].item.status <= maxStatus) activeCount++;
      if(reverseScan) {
        if(childIndex == 0 || activeCount == fetchCount) break;
        childIndex--;
      } else {
        childIndex++;
      }
      i++;
    }

    MsgView[] memory out = new MsgView[](activeCount);
    uint j;
    for(i=0; i<fetchCount; i++) {
      if(selection[i].item.status <= maxStatus) {
        out[j++] = selection[i];
      }
    }
    return ChildrenResponse(out, childCount, childIndex);
  }
}