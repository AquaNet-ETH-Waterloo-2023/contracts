// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Account as TBA, NotAuthorized} from "tokenbound-account/src/Account.sol";
import "tokenbound-account/src/AccountGuardian.sol";
import "tokenbound-account/src/AccountProxy.sol";
import "account-abstraction/core/EntryPoint.sol";
import "erc6551/ERC6551Registry.sol";

import "./mocks/MockERC721.sol";
import "./mocks/MockERC20.sol";

import "src/AquaNet.sol";

contract AquaNetTest is Test {
    TBA implementation;
    ERC6551Registry public registry;
    AccountGuardian public guardian;
    AccountProxy public proxy;
    IEntryPoint public entryPoint;

    AquaNet public aqua;

    event AquaCreated(
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 aquaId
    );

    function setUp() public {
        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new TBA(address(guardian), address(entryPoint));
        proxy = new AccountProxy(address(implementation));

        registry = new ERC6551Registry();

        aqua = new AquaNet(address(registry), address(implementation));
    }

    function testEmit() public {
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), 1);

        vm.prank(address(1337));
        vm.expectEmit();
        emit AquaCreated(address(mock), 1, 1);
        aqua.safeMint(address(mock), 1);
    }

    function testCanOnlyMintOnce() public {
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), 1);

        vm.startPrank(address(1337));
        aqua.safeMint(address(mock), 1);
        vm.expectRevert("This address already has a token.");
        aqua.safeMint(address(mock), 1);
        vm.stopPrank();
    }

    // the tokenAddress does not have supportsInterface function
    function testTokenAddressMustBeERC721(address tokenAddress) public {
        vm.startPrank(address(1337));
        vm.expectRevert();
        aqua.safeMint(tokenAddress, 1);
        vm.stopPrank();
    }

    // the tokenAddress has supportsInterface function but is not ERC721
    function testTokenAddressMustBeERC721() public {
        MockERC20 mock = new MockERC20();
        vm.startPrank(address(1337));
        vm.expectRevert();
        aqua.safeMint(address(mock), 1);
        vm.stopPrank();
    }

    function testSetApprovalForAllAllowsMint() public {
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), 1);

        vm.prank(address(1337));
        mock.setApprovalForAll(address(8008), true);

        vm.prank(address(8008));
        aqua.safeMint(address(mock), 1);

        vm.prank(address(1337));
        mock.setApprovalForAll(address(8008), false);

        vm.expectRevert(
            "You must be the owner or approved to perform this action."
        );
        vm.prank(address(8008));
        aqua.safeMint(address(mock), 1);
    }

    function testSingleApprovalAllowsMint() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        mock.approve(address(8008), tokenId);

        vm.prank(address(8008));
        aqua.safeMint(address(mock), tokenId);

        vm.prank(address(1337));
        mock.approve(address(0), tokenId);

        vm.expectRevert(
            "You must be the owner or approved to perform this action."
        );
        vm.prank(address(8008));
        aqua.safeMint(address(mock), tokenId);
    }

    function testApprovedAddressCanBurn() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        mock.approve(address(8008), tokenId);

        vm.prank(address(1337));
        aqua.safeMint(address(mock), tokenId);

        vm.prank(address(8008));
        aqua.burnAsEOA(address(mock), tokenId);
    }

    function testOwnerCanBurn() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        aqua.safeMint(address(mock), tokenId);

        vm.prank(address(1337));
        aqua.burnAsEOA(address(mock), tokenId);
    }

    function testApprovedForAllAddressCanBurn() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        mock.setApprovalForAll(address(8008), true);

        vm.prank(address(1337));
        aqua.safeMint(address(mock), tokenId);

        vm.prank(address(8008));
        aqua.burnAsEOA(address(mock), tokenId);
    }

    function testTBACanBurn() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        aqua.safeMint(address(mock), tokenId);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(mock),
            tokenId,
            0,
            ""
        );
        vm.deal(accountAddress, 1 ether);
        TBA account = TBA(payable(accountAddress));

        vm.prank(address(1337));
        account.executeCall(
            address(aqua),
            0,
            abi.encodeWithSignature("burn(uint256)", tokenId)
        );
    }

    function testNonApprovedTBACannotBurn() public {
        uint tokenId = 1;
        MockERC721 mock = new MockERC721();
        mock.mint(address(1337), tokenId);

        vm.prank(address(1337));
        aqua.safeMint(address(mock), tokenId);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(mock),
            tokenId,
            0,
            ""
        );
        vm.deal(accountAddress, 1 ether);
        TBA account = TBA(payable(accountAddress));

        vm.prank(address(8008));
        vm.expectRevert(NotAuthorized.selector);
        account.executeCall(
            address(aqua),
            0,
            abi.encodeWithSignature("burn(uint256)", tokenId)
        );
    }
}
