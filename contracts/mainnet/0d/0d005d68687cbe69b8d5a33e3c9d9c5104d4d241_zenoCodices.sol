/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-01-03
*/

/*
```_____````````````_````_`````````````````_``````````````_````````````
``/`____|``````````|`|``|`|```````````````|`|````````````|`|```````````
`|`|`````___```___`|`|`_|`|__```___```___`|`|`__```````__|`|`_____```__
`|`|````/`_`\`/`_`\|`|/`/`'_`\`/`_`\`/`_`\|`|/`/``````/`_``|/`_`\`\`/`/
`|`|___|`(_)`|`(_)`|```<|`|_)`|`(_)`|`(_)`|```<```_``|`(_|`|``__/\`V`/`
``\_____\___/`\___/|_|\_\_.__/`\___/`\___/|_|\_\`(_)``\__,_|\___|`\_/``
```````````````````````````````````````````````````````````````````````
```````````````````````````````````````````````````````````````````````
*/

// -> Cookbook is a free smart contract marketplace. Find, deploy and contribute audited smart contracts.
// -> Follow Cookbook on Twitter: https://twitter.com/cookbook_dev
// -> Join Cookbook on Discord:https://discord.gg/WzsfPcfHrk

// -> Find this contract on Cookbook: https://www.cookbook.dev/contracts/Information-Storage?utm=code





// SPDX-License-Identifier: MIT

 ///  $$$$$$            /$$$$$$                                              /$$     /$$                            /$$$$$$   /$$                                            
//  |_  $$_/           /$$__  $$                                            | $$    |__/                           /$$__  $$ | $$                                            
  //  | $$   /$$$$$$$ | $$  \__//$$$$$$   /$$$$$$  /$$$$$$/$$$$   /$$$$$$  /$$$$$$   /$$  /$$$$$$  /$$$$$$$       | $$  \__//$$$$$$    /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$ 
  //  | $$  | $$__  $$| $$$$   /$$__  $$ /$$__  $$| $$_  $$_  $$ |____  $$|_  $$_/  | $$ /$$__  $$| $$__  $$      |  $$$$$$|_  $$_/   /$$__  $$ /$$__  $$ /$$__  $$ /$$__  $$
  //  | $$  | $$  \ $$| $$_/  | $$  \ $$| $$  \__/| $$ \ $$ \ $$  /$$$$$$$  | $$    | $$| $$  \ $$| $$  \ $$       \____  $$ | $$    | $$  \ $$| $$  \__/| $$$$$$$$| $$  \__/
  //  | $$  | $$  | $$| $$    | $$  | $$| $$      | $$ | $$ | $$ /$$__  $$  | $$ /$$| $$| $$  | $$| $$  | $$       /$$  \ $$ | $$ /$$| $$  | $$| $$      | $$_____/| $$      
 //  /$$$$$$| $$  | $$| $$    |  $$$$$$/| $$      | $$ | $$ | $$|  $$$$$$$  |  $$$$/| $$|  $$$$$$/| $$  | $$      |  $$$$$$/ |  $$$$/|  $$$$$$/| $$      |  $$$$$$$| $$      
//  |______/|__/  |__/|__/     \______/ |__/      |__/ |__/ |__/ \_______/   \___/  |__/ \______/ |__/  |__/       \______/   \___/   \______/ |__/       \_______/|__/      


//By BraverElliot.eth (send me your money)



pragma solidity ^0.8.7;

contract zenoCodices{

    address public owner;
    uint256 private counter;

    constructor()   {
        counter = 0;
        owner = msg.sender;
    }
    struct store    {
        address storer;
        uint256 id;
        string Fielda;
        string Fieldb;
    }

    event storeCreated   (
        address storer,
        uint256 id,
        string Fielda,
        string Fieldb
    );

    mapping(uint256 => store) Storers;    


    function addStore(

        string memory Fielda,
        string memory Fieldb
    ) public payable {
        require(msg.value ==  1 wei, "Please submit 0.000000000000000001 Eth"); //submit 0.000000000000000001 for anti-spam protection
        store storage newStore = Storers[counter];
        newStore.Fielda = Fielda;
        newStore.Fieldb = Fieldb;
        newStore.storer = msg.sender;
        newStore.id = counter;


        emit storeCreated(
                msg.sender,
                counter,
                Fielda,
                Fieldb
            );

        counter++;

        payable(owner).transfer(msg.value);


    }

    function getInfo(uint256 id) public view returns(
            string memory,
            string memory,
            address
        ){
            require(id<counter, "No such Post");
            store storage t = Storers[id];
            return(t.Fielda,t.Fieldb,t.storer);
        }


}