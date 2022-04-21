/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-21
*/

contract LDMTOOL {
    function luckyMoneyETH(address payable[] memory addrs,uint mainAmount) public payable{
      
      for(uint i=0;i<addrs.length;i+=1){
          address payable a = addrs[i];
          uint am = mainAmount;
          a.transfer(am);
      }
      
  }
}