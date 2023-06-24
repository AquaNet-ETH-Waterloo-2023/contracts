// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/AquaNet.sol";

contract TestSepolia is Script {
    AquaNet aquaNet;

    function run() public {
        // string memory rpcUrl = vm.envString("RPC_URL");
        // vm.createSelectFork(rpcUrl, 3754996);
        aquaNet = AquaNet(0xabe39d05d4c99dfea4818967042cCA20cd54C8d2);

        uint privateKey = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(privateKey);

        vm.startPrank(me);
        aquaNet.safeMint(0xB9fD992D24C237682Cc9bf5b8c298B8c67A451a5, 1);
        vm.stopPrank();
    }
}
