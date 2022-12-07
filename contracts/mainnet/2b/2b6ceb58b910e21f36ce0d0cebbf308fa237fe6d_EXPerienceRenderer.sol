// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IRenderer {
    function render(
        uint256 tokenId,
        uint256 ownerBalance,
        address tokenOwner
    ) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../utils/Base64.sol";
import {IRenderer} from "../interfaces/IRenderer.sol";

// EthernauDAO EXPerience NFT token URI renderer
contract EXPerienceRenderer is IRenderer {
    // @Todo: improve this code, refactor more and more and make it concise and epic

    // ======================== Start - https://codepen.io/alebanfi/pen/NWyXxoL ====================================
    // =============== SVG styles and idea given by Aleta from EthernautDAO discord ================================
    // In this svg, we have two parts we need to take care of
    // First section is color description, that has to be a mapping (selected(based on ERC20 EXP balance) => colorArray)
    // Here's how the plan goes
    // EXP balance                  Color codings
    // 0                            Set a special IFPS for this, we can allow having nft even if balance is 0
    // branch: dev/for_optimism_deployment - 0 is included in levels 0 - 25
    // 1 - 25                       ['#ffffff', '#666666', '#333333']
    // 26 - 50                      ['#c5fccb', '#6cd4a1', '#027562']
    // 51 - 75                      ['#c6f7f5', '#30d5f2', '#074d87']
    // 76 - 100                     ['#fc9fc1', '#e61964', '#222b52']
    // @Todo: 100 limit has to be maintained. Confirm this once done with this implementation
    // Now every stage, svg is different + the combination of colors required depending on the level + exp display based on balance
    // Storage needs to be used in a better manner here

    bytes private constant _selectedCoreCommon =
        '</linearGradient></defs><pattern id="pattern" x="0" y="0" width="100%" height="100%"><rect x="-150%" y="0" width="200%" height="150%" fill="url(#gradient)" transform="rotate(-65)"><animate attributeType="XML" attributeName="x" from="-150%" to="50%" dur="4s" repeatCount="indefinite"/></rect><rect x="-350%" y="0" width="200%" height="150%" fill="url(#gradient)" transform="rotate(-65)"><animate attributeType="XML" attributeName="x" from="-350%" to="-150%" dur="4s" repeatCount="indefinite"/></rect></pattern>';

    bytes private constant _selectedCoreEnd =
        '<text x="50%" y="47%" class="base" fill="url(#pattern)" dominant-baseline="middle" text-anchor="middle" style="font-family: Josefin Sans, sans-serif;font-size:140px; ">';

    function _getSVGCore(uint256 tokenAmount_)
        private
        pure
        returns (bytes memory)
    {
        // Our four cores
        // 0 - 25       Codepen(Aleta): https://codepen.io/alebanfi/pen/OJQzMaQ
        // 26 - 50      https://codepen.io/alebanfi/pen/PoQEZXQ
        // 51 - 75      https://codepen.io/alebanfi/pen/vYdpLbZ
        // 76 - 100     https://codepen.io/alebanfi/pen/NWyXxoL
        // Update: Comparison changed due to allowance of floating point 0.0x limit of EXP wallet balance

        // Pack the string rightly if we know it's not going to be changed every. However, this should not be
        // the case when eventually we allow custom setting of core svg generation logic
        bytes
            memory _selectedCore1 = '<path fill="url(#pattern)" d="m280.2 51.8h-3.9v-9.7h4c1.7 0 3 0.5 3.8 1.5s1.2 2.1 1.2 3.3c0 0.7-0.2 1.5-0.5 2.2-0.3 0.8-0.9 1.4-1.7 1.9-0.6 0.5-1.6 0.8-2.9 0.8zm-79.1 31c0.1-12.1 0.6-25 1.9-36.8 1-9 2.8-17.2 4.9-23.8 15.7-6.5 32-10.2 48.1-10.2s32.4 3.7 48.2 10.2c2.1 6.5 3.9 14.8 4.9 23.8 1.3 11.8 1.7 24.7 1.9 36.8-33.9-3.7-76.1-3.7-109.9 0zm71.8-18h3.5v-9.6h3.9c2 0 3.6-0.4 5-1.2 1.3-0.8 2.3-1.8 2.8-3.1 0.6-1.3 0.9-2.6 0.9-4.1 0-2.5-0.8-4.5-2.4-5.9s-3.8-2.1-6.6-2.1h-7v26zm-30.3-3.4h-13.9v-8h12v-3.4h-12v-7.9h13.4v-3.3h-16.9v26h17.4v-3.4zm7.9 3.4 6.2-10.4 6.8 10.4h4.5l-8.6-13.2 8.2-12.9h-4.2l-5.9 9.9-6.5-9.9h-4.4l8.2 12.6-8.6 13.4h4.3zm-17.5 338.4v29c8.2 1.2 16 1.8 23 1.8s14.8-0.7 23-1.8v-29c-7.8 0.6-15.5 0.8-23 0.8s-15.2-0.3-23-0.8zm-143.8-25.7c0.2 0.4 0.6 1.2 1.7 2.2 2.5 2.2 6.7 5.2 12.1 8.4 10.9 6.4 26.5 13.8 44.2 20.6 21.2 8.2 45.4 15.7 67.7 20.4v-27.6c-39.5-5.1-79.9-18.3-108.4-44.5-3.6 1.2-7.3 3.4-10.3 6.4-4 4.1-6.5 9.4-7 14.1zm316.2-20.6c-28.5 26.1-68.9 39.3-108.4 44.5v27.6c22.4-4.7 46.6-12.1 67.7-20.4 17.7-6.9 33.3-14.2 44.2-20.6 5.4-3.2 9.7-6.2 12.1-8.4 1.1-1 1.5-1.8 1.7-2.2-0.5-4.7-3-10-7.2-14.1-2.9-3-6.6-5.2-10.1-6.4zm-301.9-22.9c29.3 43.3 96.8 60 152.5 60s123.2-16.7 152.5-60c39.2-57.8 32.5-151.3-0.5-214.8-17.5-33.6-47.9-66.1-82.6-86.3 0.6 3.6 1.1 7.4 1.5 11.2 1.5 13.7 1.9 28.2 2 41.3 18.7 3.2 33 7.7 39 13.7 32 32 75.5 134.7 16 224-37.7 56.5-218.3 56.5-256 0-59.5-89.3-16-192 16-224 6-6 20.3-10.6 39-13.7 0.1-13.1 0.5-27.6 2-41.3 0.4-3.8 0.9-7.5 1.5-11.2-34.7 20.2-65 52.7-82.6 86.3-32.9 63.5-39.5 156.9-0.3 214.8zm83-301.2zm-30.5 81.7c-26.6 20.6-43 114.8-33.5 146.8 16.6-61.8 32-124 107.9-161.3-7-1.1-14.1-1.6-21.2-1.6-17.2 0.1-37.2 3.7-53.2 16.1zm-49.4 242.4zm237 98.1c-1.7-0.7-3.4-1.1-4.9-1.1h-6.4v24.7h4.6c4.1 0 7.3-1 9.7-3.1s3.6-5.1 3.6-9c0-3.2-0.7-5.7-2-7.6-1.4-1.9-2.9-3.2-4.6-3.9zm29 16.8h7.8l-3.8-9.7-4 9.7zm-194.1-3.8c-1-0.8-2.2-1.1-3.7-1.1-2.1 0-3.7 0.7-5.1 2.2-1.3 1.4-2 3.3-2 5.5 0 0.5 0 1 0.1 1.2l13-4.8c-0.5-1.2-1.3-2.2-2.3-3zm79.7 0.6c-1.4-1-2.9-1.5-4.7-1.5-1.3 0-2.6 0.3-3.7 1-1.1 0.6-2 1.6-2.7 2.7-0.7 1.2-1 2.5-1 4 0 1.4 0.3 2.8 1 3.9 0.7 1.2 1.6 2.1 2.8 2.8s2.4 1.1 3.8 1.1c1.8 0 3.4-0.5 4.7-1.5s2.2-2.4 2.5-4.2v-4.4c-0.4-1.7-1.3-3-2.7-3.9zm164.1-13.3c-1.9-1.1-3.9-1.7-6.2-1.7s-4.3 0.6-6.2 1.7-3.3 2.7-4.4 4.6-1.6 4.1-1.6 6.5c0 2.3 0.5 4.4 1.6 6.4 1.1 1.9 2.6 3.5 4.5 4.6s4 1.7 6.3 1.7c2.2 0 4.3-0.6 6.1-1.7s3.3-2.7 4.3-4.6 1.6-4.1 1.6-6.4c0-2.4-0.5-4.5-1.6-6.5s-2.6-3.5-4.4-4.6zm71.7-32.2v74.9h-476v-74.9l59.3-39.5c0.5 0.5 1.1 1 1.6 1.5 3.9 3.5 8.9 6.9 15 10.5 12.1 7.1 28.5 14.7 46.8 21.9 36.7 14.3 81 26.6 115.3 26.6s78.6-12.3 115.3-26.6c18.3-7.1 34.7-14.8 46.8-21.9 6.1-3.6 11.1-7 15-10.5 0.5-0.5 1.1-1 1.6-1.5l59.3 39.5zm-409.2 30.6h23.8v-3.9h-23.8v3.9zm1.8 11.7v3.9h20.2v-3.9h-20.2zm22.6 16.8h-25v3.9h24.9v-3.9zm19.6-18.3h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm27.2 5.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9c-2 0-3.8 0.5-5.4 1.3-1.6 0.9-2.8 2.1-3.6 3.6v-23.5h-4.9v41.8h5v-10.5c0-1.6 0.3-3 0.9-4.3s1.4-2.3 2.5-3c1-0.7 2.2-1.1 3.5-1.1 1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.5zm12.8 9.1 17.7-6.2c-0.7-3.1-2.1-5.4-4-7.2-2-1.7-4.4-2.6-7.3-2.6-2.3 0-4.4 0.5-6.3 1.6s-3.4 2.5-4.5 4.3-1.6 3.8-1.6 6c0 2.3 0.5 4.3 1.5 6.1s2.4 3.2 4.3 4.2 4 1.5 6.5 1.5c1.3 0 2.6-0.2 4-0.7s2.7-1.1 3.9-1.9l-2.3-3.7c-1.8 1.3-3.6 1.9-5.5 1.9-1.4 0-2.7-0.3-3.8-0.9-1-0.4-1.9-1.2-2.6-2.4zm37.8-15.9c-0.9 0-1.9 0.3-3.1 0.8s-2.3 1.2-3.4 2.2c-1.1 0.9-1.9 2-2.5 3.2l-0.4-5.3h-4.5v22.4h5v-10.2c0-1.4 0.4-2.8 1.1-4.1s1.8-2.3 3.1-3 2.8-1 4.4-1l0.3-5zm27.7 6.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9-3.9 0.5-5.5 1.4-2.8 2.2-3.6 3.8l-0.3-4.3h-4.5v22.4h5v-10.5c0-2.4 0.6-4.5 1.9-6s2.9-2.4 4.9-2.4c1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.6zm31.6-5.9h-4.6l-0.4 3.6c-0.9-1.3-2-2.4-3.4-3.2s-3.1-1.2-5-1.2c-2.1 0-4.1 0.5-5.8 1.5s-3.1 2.4-4.2 4.2c-1 1.8-1.5 4-1.5 6.4s0.5 4.6 1.5 6.3c1 1.8 2.3 3.1 4 4s3.6 1.4 5.8 1.4c1.9 0 3.6-0.4 5.1-1.3s2.7-1.8 3.5-2.9v3.7h5v-22.5zm29.6 0h-5v10.4c0 1.6-0.3 3-0.9 4.3s-1.4 2.3-2.4 3.1c-1 0.7-2.1 1.1-3.3 1.1-1.3 0-2.3-0.4-3-1.2-0.7-0.7-1-1.7-1.1-3v-14.7h-5v16.5c0.1 2 0.8 3.6 2.1 4.8s3 1.9 5 1.9c1.9 0 3.7-0.5 5.3-1.4 1.6-1 2.8-2.2 3.5-3.7l0.3 4.3h4.5v-22.4zm22.1 0.1h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm40.6 3.1c0-3.6-0.7-6.9-2.2-10s-3.9-5.7-7.2-7.6c-3.3-2-7.5-2.9-12.5-2.9h-11.9v39.7h13.8c3.6 0 7-0.8 10-2.3 3-1.6 5.5-3.8 7.3-6.7 1.8-3 2.7-6.4 2.7-10.2zm37 19.2-17.9-41.3h-0.4l-17.9 41.3h7.7l3.2-7.8h13.1l3.1 7.8h9.1zm41.2-19.8c0-3.6-0.9-7-2.8-10.1s-4.3-5.6-7.5-7.5c-3.1-1.9-6.5-2.8-10.1-2.8s-7 0.9-10.1 2.8-5.6 4.3-7.4 7.5c-1.8 3.1-2.7 6.5-2.7 10.1 0 3.7 0.9 7.1 2.7 10.2s4.3 5.6 7.4 7.4 6.5 2.7 10.2 2.7c3.6 0 7-0.9 10.1-2.7s5.6-4.3 7.5-7.4c1.8-3.2 2.7-6.6 2.7-10.2z"/>';

        bytes
            memory _selectedCore2 = '<path fill="url(#pattern)" d="m280.2 51.8h-3.9v-9.7h4c1.7 0 3 0.5 3.8 1.5s1.2 2.1 1.2 3.3c0 0.7-0.2 1.5-0.5 2.2-0.3 0.8-0.9 1.4-1.7 1.9-0.6 0.5-1.6 0.8-2.9 0.8zm-79.1 31c0.1-12.1 0.6-25 1.9-36.8 1-9 2.8-17.2 4.9-23.8 15.7-6.5 32-10.2 48.1-10.2s32.4 3.7 48.2 10.2c2.1 6.5 3.9 14.8 4.9 23.8 1.3 11.8 1.7 24.7 1.9 36.8-33.9-3.7-76.1-3.7-109.9 0zm71.8-18h3.5v-9.6h3.9c2 0 3.6-0.4 5-1.2 1.3-0.8 2.3-1.8 2.8-3.1 0.6-1.3 0.9-2.6 0.9-4.1 0-2.5-0.8-4.5-2.4-5.9s-3.8-2.1-6.6-2.1h-7v26zm-30.3-3.4h-13.9v-8h12v-3.4h-12v-7.9h13.4v-3.3h-16.9v26h17.4v-3.4zm7.9 3.4 6.2-10.4 6.8 10.4h4.5l-8.6-13.2 8.2-12.9h-4.2l-5.9 9.9-6.5-9.9h-4.4l8.2 12.6-8.6 13.4h4.3zm197.7 221.6 38.2-45.8-14.5-72.4-34.1-25.5c16.1 44.9 21.3 97.1 10.4 143.7zm-215.2 116.8v29c8.2 1.2 16 1.8 23 1.8s14.8-0.7 23-1.8v-29c-7.8 0.6-15.5 0.8-23 0.8s-15.2-0.3-23-0.8zm-143.8-25.7c0.2 0.4 0.6 1.2 1.7 2.2 2.5 2.2 6.7 5.2 12.1 8.4 10.9 6.4 26.5 13.8 44.2 20.6 21.2 8.2 45.4 15.7 67.7 20.4v-27.6c-39.5-5.1-79.9-18.3-108.4-44.5-3.6 1.2-7.3 3.4-10.3 6.4-4 4.1-6.5 9.4-7 14.1zm-15-234.9-34.1 25.5-14.5 72.4 38.2 45.8c-10.9-46.5-5.7-98.7 10.4-143.7zm331.2 214.3c-28.5 26.1-68.9 39.3-108.4 44.5v27.6c22.4-4.7 46.6-12.1 67.7-20.4 17.7-6.9 33.3-14.2 44.2-20.6 5.4-3.2 9.7-6.2 12.1-8.4 1.1-1 1.5-1.8 1.7-2.2-0.5-4.7-3-10-7.2-14.1-2.9-3-6.6-5.2-10.1-6.4zm-301.9-22.9c29.3 43.3 96.8 60 152.5 60s123.2-16.7 152.5-60c39.2-57.8 32.5-151.3-0.5-214.8-17.5-33.6-47.9-66.1-82.6-86.3 0.6 3.6 1.1 7.4 1.5 11.2 1.5 13.7 1.9 28.2 2 41.3 18.7 3.2 33 7.7 39 13.7 32 32 75.5 134.7 16 224-37.7 56.5-218.3 56.5-256 0-59.5-89.3-16-192 16-224 6-6 20.3-10.6 39-13.7 0.1-13.1 0.5-27.6 2-41.3 0.4-3.8 0.9-7.5 1.5-11.2-34.7 20.2-65 52.7-82.6 86.3-32.9 63.5-39.5 156.9-0.3 214.8zm83-301.2zm-30.5 81.7c-26.6 20.6-43 114.8-33.5 146.8 16.6-61.8 32-124 107.9-161.3-7-1.1-14.1-1.6-21.2-1.6-17.2 0.1-37.2 3.7-53.2 16.1zm-49.4 242.4zm237 98.1c-1.7-0.7-3.4-1.1-4.9-1.1h-6.4v24.7h4.6c4.1 0 7.3-1 9.7-3.1s3.6-5.1 3.6-9c0-3.2-0.7-5.7-2-7.6-1.4-1.9-2.9-3.2-4.6-3.9zm29 16.8h7.8l-3.8-9.7-4 9.7zm-194.1-3.8c-1-0.8-2.2-1.1-3.7-1.1-2.1 0-3.7 0.7-5.1 2.2-1.3 1.4-2 3.3-2 5.5 0 0.5 0 1 0.1 1.2l13-4.8c-0.5-1.2-1.3-2.2-2.3-3zm79.7 0.6c-1.4-1-2.9-1.5-4.7-1.5-1.3 0-2.6 0.3-3.7 1-1.1 0.6-2 1.6-2.7 2.7-0.7 1.2-1 2.5-1 4 0 1.4 0.3 2.8 1 3.9 0.7 1.2 1.6 2.1 2.8 2.8s2.4 1.1 3.8 1.1c1.8 0 3.4-0.5 4.7-1.5s2.2-2.4 2.5-4.2v-4.4c-0.4-1.7-1.3-3-2.7-3.9zm164.1-13.3c-1.9-1.1-3.9-1.7-6.2-1.7s-4.3 0.6-6.2 1.7-3.3 2.7-4.4 4.6-1.6 4.1-1.6 6.5c0 2.3 0.5 4.4 1.6 6.4 1.1 1.9 2.6 3.5 4.5 4.6s4 1.7 6.3 1.7c2.2 0 4.3-0.6 6.1-1.7s3.3-2.7 4.3-4.6 1.6-4.1 1.6-6.4c0-2.4-0.5-4.5-1.6-6.5s-2.6-3.5-4.4-4.6zm71.7-32.2v74.9h-476v-74.9l59.3-39.5c0.5 0.5 1.1 1 1.6 1.5 3.9 3.5 8.9 6.9 15 10.5 12.1 7.1 28.5 14.7 46.8 21.9 36.7 14.3 81 26.6 115.3 26.6s78.6-12.3 115.3-26.6c18.3-7.1 34.7-14.8 46.8-21.9 6.1-3.6 11.1-7 15-10.5 0.5-0.5 1.1-1 1.6-1.5l59.3 39.5zm-409.2 30.6h23.8v-3.9h-23.8v3.9zm1.8 11.7v3.9h20.2v-3.9h-20.2zm22.6 16.8h-25v3.9h24.9v-3.9zm19.6-18.3h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm27.2 5.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9c-2 0-3.8 0.5-5.4 1.3-1.6 0.9-2.8 2.1-3.6 3.6v-23.5h-4.9v41.8h5v-10.5c0-1.6 0.3-3 0.9-4.3s1.4-2.3 2.5-3c1-0.7 2.2-1.1 3.5-1.1 1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.5zm12.8 9.1 17.7-6.2c-0.7-3.1-2.1-5.4-4-7.2-2-1.7-4.4-2.6-7.3-2.6-2.3 0-4.4 0.5-6.3 1.6s-3.4 2.5-4.5 4.3-1.6 3.8-1.6 6c0 2.3 0.5 4.3 1.5 6.1s2.4 3.2 4.3 4.2 4 1.5 6.5 1.5c1.3 0 2.6-0.2 4-0.7s2.7-1.1 3.9-1.9l-2.3-3.7c-1.8 1.3-3.6 1.9-5.5 1.9-1.4 0-2.7-0.3-3.8-0.9-1-0.4-1.9-1.2-2.6-2.4zm37.8-15.9c-0.9 0-1.9 0.3-3.1 0.8s-2.3 1.2-3.4 2.2c-1.1 0.9-1.9 2-2.5 3.2l-0.4-5.3h-4.5v22.4h5v-10.2c0-1.4 0.4-2.8 1.1-4.1s1.8-2.3 3.1-3 2.8-1 4.4-1l0.3-5zm27.7 6.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9-3.9 0.5-5.5 1.4-2.8 2.2-3.6 3.8l-0.3-4.3h-4.5v22.4h5v-10.5c0-2.4 0.6-4.5 1.9-6s2.9-2.4 4.9-2.4c1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.6zm31.6-5.9h-4.6l-0.4 3.6c-0.9-1.3-2-2.4-3.4-3.2s-3.1-1.2-5-1.2c-2.1 0-4.1 0.5-5.8 1.5s-3.1 2.4-4.2 4.2c-1 1.8-1.5 4-1.5 6.4s0.5 4.6 1.5 6.3c1 1.8 2.3 3.1 4 4s3.6 1.4 5.8 1.4c1.9 0 3.6-0.4 5.1-1.3s2.7-1.8 3.5-2.9v3.7h5v-22.5zm29.6 0h-5v10.4c0 1.6-0.3 3-0.9 4.3s-1.4 2.3-2.4 3.1c-1 0.7-2.1 1.1-3.3 1.1-1.3 0-2.3-0.4-3-1.2-0.7-0.7-1-1.7-1.1-3v-14.7h-5v16.5c0.1 2 0.8 3.6 2.1 4.8s3 1.9 5 1.9c1.9 0 3.7-0.5 5.3-1.4 1.6-1 2.8-2.2 3.5-3.7l0.3 4.3h4.5v-22.4zm22.1 0.1h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm40.6 3.1c0-3.6-0.7-6.9-2.2-10s-3.9-5.7-7.2-7.6c-3.3-2-7.5-2.9-12.5-2.9h-11.9v39.7h13.8c3.6 0 7-0.8 10-2.3 3-1.6 5.5-3.8 7.3-6.7 1.8-3 2.7-6.4 2.7-10.2zm37 19.2-17.9-41.3h-0.4l-17.9 41.3h7.7l3.2-7.8h13.1l3.1 7.8h9.1zm41.2-19.8c0-3.6-0.9-7-2.8-10.1s-4.3-5.6-7.5-7.5c-3.1-1.9-6.5-2.8-10.1-2.8s-7 0.9-10.1 2.8-5.6 4.3-7.4 7.5c-1.8 3.1-2.7 6.5-2.7 10.1 0 3.7 0.9 7.1 2.7 10.2s4.3 5.6 7.4 7.4 6.5 2.7 10.2 2.7c3.6 0 7-0.9 10.1-2.7s5.6-4.3 7.5-7.4c1.8-3.2 2.7-6.6 2.7-10.2z"/>';

        bytes
            memory _selectedCore3 = '<path fill="url(#pattern)" d="m280.2 51.8h-3.9v-9.7h4c1.7 0 3 0.5 3.8 1.5s1.2 2.1 1.2 3.3c0 0.7-0.2 1.5-0.5 2.2-0.3 0.8-0.9 1.4-1.7 1.9-0.6 0.5-1.6 0.8-2.9 0.8zm140.4 52.8c0.8 1.4 1.6 2.9 2.4 4.4l29.9 22.4-4.7-35.5c-7 5.5-15.8 8.8-25.3 8.8-0.8 0-1.6 0-2.3-0.1zm-37.8-50c1.5-6.6 4.7-12.7 9-17.7l-35.3-5.5c9.4 7 18.2 14.8 26.3 23.2zm-181.7 28.2c0.1-12.1 0.6-25 1.9-36.8 1-9 2.8-17.2 4.9-23.8 15.7-6.5 32-10.2 48.1-10.2s32.4 3.7 48.2 10.2c2.1 6.5 3.9 14.8 4.9 23.8 1.3 11.8 1.7 24.7 1.9 36.8-33.9-3.7-76.1-3.7-109.9 0zm71.8-18h3.5v-9.6h3.9c2 0 3.6-0.4 5-1.2 1.3-0.8 2.3-1.8 2.8-3.1 0.6-1.3 0.9-2.6 0.9-4.1 0-2.5-0.8-4.5-2.4-5.9s-3.8-2.1-6.6-2.1h-7v26zm-30.3-3.4h-13.9v-8h12v-3.4h-12v-7.9h13.4v-3.3h-16.9v26h17.4v-3.4zm7.9 3.4 6.2-10.4 6.8 10.4h4.5l-8.6-13.2 8.2-12.9h-4.2l-5.9 9.9-6.5-9.9h-4.4l8.2 12.6-8.6 13.4h4.3zm197.7 221.6 38.2-45.8-14.5-72.4-34.1-25.5c16.1 44.9 21.3 97.1 10.4 143.7zm-25.4-199.7c12.8 0 23-10.2 23-23s-10.2-23-23-23-23 10.2-23 23 10.2 23 23 23zm-189.8 316.5v29c8.2 1.2 16 1.8 23 1.8s14.8-0.7 23-1.8v-29c-7.8 0.6-15.5 0.8-23 0.8s-15.2-0.3-23-0.8zm-143.8-25.7c0.2 0.4 0.6 1.2 1.7 2.2 2.5 2.2 6.7 5.2 12.1 8.4 10.9 6.4 26.5 13.8 44.2 20.6 21.2 8.2 45.4 15.7 67.7 20.4v-27.6c-39.5-5.1-79.9-18.3-108.4-44.5-3.6 1.2-7.3 3.4-10.3 6.4-4 4.1-6.5 9.4-7 14.1zm-15-234.9-34.1 25.5-14.5 72.4 38.2 45.8c-10.9-46.5-5.7-98.7 10.4-143.7zm331.2 214.3c-28.5 26.1-68.9 39.3-108.4 44.5v27.6c22.4-4.7 46.6-12.1 67.7-20.4 17.7-6.9 33.3-14.2 44.2-20.6 5.4-3.2 9.7-6.2 12.1-8.4 1.1-1 1.5-1.8 1.7-2.2-0.5-4.7-3-10-7.2-14.1-2.9-3-6.6-5.2-10.1-6.4zm-301.9-22.9c29.3 43.3 96.8 60 152.5 60s123.2-16.7 152.5-60c39.2-57.8 32.5-151.3-0.5-214.8-17.5-33.6-47.9-66.1-82.6-86.3 0.6 3.6 1.1 7.4 1.5 11.2 1.5 13.7 1.9 28.2 2 41.3 18.7 3.2 33 7.7 39 13.7 32 32 75.5 134.7 16 224-37.7 56.5-218.3 56.5-256 0-59.5-89.3-16-192 16-224 6-6 20.3-10.6 39-13.7 0.1-13.1 0.5-27.6 2-41.3 0.4-3.8 0.9-7.5 1.5-11.2-34.7 20.2-65 52.7-82.6 86.3-32.9 63.5-39.5 156.9-0.3 214.8zm83-301.2zm-30.5 81.7c-26.6 20.6-43 114.8-33.5 146.8 16.6-61.8 32-124 107.9-161.3-7-1.1-14.1-1.6-21.2-1.6-17.2 0.1-37.2 3.7-53.2 16.1zm-49.4 242.4zm237 98.1c-1.7-0.7-3.4-1.1-4.9-1.1h-6.4v24.7h4.6c4.1 0 7.3-1 9.7-3.1s3.6-5.1 3.6-9c0-3.2-0.7-5.7-2-7.6-1.4-1.9-2.9-3.2-4.6-3.9zm29 16.8h7.8l-3.8-9.7-4 9.7zm-194.1-3.8c-1-0.8-2.2-1.1-3.7-1.1-2.1 0-3.7 0.7-5.1 2.2-1.3 1.4-2 3.3-2 5.5 0 0.5 0 1 0.1 1.2l13-4.8c-0.5-1.2-1.3-2.2-2.3-3zm79.7 0.6c-1.4-1-2.9-1.5-4.7-1.5-1.3 0-2.6 0.3-3.7 1-1.1 0.6-2 1.6-2.7 2.7-0.7 1.2-1 2.5-1 4 0 1.4 0.3 2.8 1 3.9 0.7 1.2 1.6 2.1 2.8 2.8s2.4 1.1 3.8 1.1c1.8 0 3.4-0.5 4.7-1.5s2.2-2.4 2.5-4.2v-4.4c-0.4-1.7-1.3-3-2.7-3.9zm164.1-13.3c-1.9-1.1-3.9-1.7-6.2-1.7s-4.3 0.6-6.2 1.7-3.3 2.7-4.4 4.6-1.6 4.1-1.6 6.5c0 2.3 0.5 4.4 1.6 6.4 1.1 1.9 2.6 3.5 4.5 4.6s4 1.7 6.3 1.7c2.2 0 4.3-0.6 6.1-1.7s3.3-2.7 4.3-4.6 1.6-4.1 1.6-6.4c0-2.4-0.5-4.5-1.6-6.5s-2.6-3.5-4.4-4.6zm71.7-32.2v74.9h-476v-74.9l59.3-39.5c0.5 0.5 1.1 1 1.6 1.5 3.9 3.5 8.9 6.9 15 10.5 12.1 7.1 28.5 14.7 46.8 21.9 36.7 14.3 81 26.6 115.3 26.6s78.6-12.3 115.3-26.6c18.3-7.1 34.7-14.8 46.8-21.9 6.1-3.6 11.1-7 15-10.5 0.5-0.5 1.1-1 1.6-1.5l59.3 39.5zm-409.2 30.6h23.8v-3.9h-23.8v3.9zm1.8 11.7v3.9h20.2v-3.9h-20.2zm22.6 16.8h-25v3.9h24.9v-3.9zm19.6-18.3h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm27.2 5.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9c-2 0-3.8 0.5-5.4 1.3-1.6 0.9-2.8 2.1-3.6 3.6v-23.5h-4.9v41.8h5v-10.5c0-1.6 0.3-3 0.9-4.3s1.4-2.3 2.5-3c1-0.7 2.2-1.1 3.5-1.1 1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.5zm12.8 9.1 17.7-6.2c-0.7-3.1-2.1-5.4-4-7.2-2-1.7-4.4-2.6-7.3-2.6-2.3 0-4.4 0.5-6.3 1.6s-3.4 2.5-4.5 4.3-1.6 3.8-1.6 6c0 2.3 0.5 4.3 1.5 6.1s2.4 3.2 4.3 4.2 4 1.5 6.5 1.5c1.3 0 2.6-0.2 4-0.7s2.7-1.1 3.9-1.9l-2.3-3.7c-1.8 1.3-3.6 1.9-5.5 1.9-1.4 0-2.7-0.3-3.8-0.9-1-0.4-1.9-1.2-2.6-2.4zm37.8-15.9c-0.9 0-1.9 0.3-3.1 0.8s-2.3 1.2-3.4 2.2c-1.1 0.9-1.9 2-2.5 3.2l-0.4-5.3h-4.5v22.4h5v-10.2c0-1.4 0.4-2.8 1.1-4.1s1.8-2.3 3.1-3 2.8-1 4.4-1l0.3-5zm27.7 6.8c0-2-0.7-3.6-2.1-4.8s-3.1-1.9-5.2-1.9-3.9 0.5-5.5 1.4-2.8 2.2-3.6 3.8l-0.3-4.3h-4.5v22.4h5v-10.5c0-2.4 0.6-4.5 1.9-6s2.9-2.4 4.9-2.4c1.4 0 2.4 0.4 3.1 1.1s1.1 1.7 1.1 3v14.8h5.1v-16.6zm31.6-5.9h-4.6l-0.4 3.6c-0.9-1.3-2-2.4-3.4-3.2s-3.1-1.2-5-1.2c-2.1 0-4.1 0.5-5.8 1.5s-3.1 2.4-4.2 4.2c-1 1.8-1.5 4-1.5 6.4s0.5 4.6 1.5 6.3c1 1.8 2.3 3.1 4 4s3.6 1.4 5.8 1.4c1.9 0 3.6-0.4 5.1-1.3s2.7-1.8 3.5-2.9v3.7h5v-22.5zm29.6 0h-5v10.4c0 1.6-0.3 3-0.9 4.3s-1.4 2.3-2.4 3.1c-1 0.7-2.1 1.1-3.3 1.1-1.3 0-2.3-0.4-3-1.2-0.7-0.7-1-1.7-1.1-3v-14.7h-5v16.5c0.1 2 0.8 3.6 2.1 4.8s3 1.9 5 1.9c1.9 0 3.7-0.5 5.3-1.4 1.6-1 2.8-2.2 3.5-3.7l0.3 4.3h4.5v-22.4zm22.1 0.1h-6.1v-9.9h-5.1v9.9h-4.1v4h4.1v18.3h5.1v-18.3h6.1v-4zm40.6 3.1c0-3.6-0.7-6.9-2.2-10s-3.9-5.7-7.2-7.6c-3.3-2-7.5-2.9-12.5-2.9h-11.9v39.7h13.8c3.6 0 7-0.8 10-2.3 3-1.6 5.5-3.8 7.3-6.7 1.8-3 2.7-6.4 2.7-10.2zm37 19.2-17.9-41.3h-0.4l-17.9 41.3h7.7l3.2-7.8h13.1l3.1 7.8h9.1zm41.2-19.8c0-3.6-0.9-7-2.8-10.1s-4.3-5.6-7.5-7.5c-3.1-1.9-6.5-2.8-10.1-2.8s-7 0.9-10.1 2.8-5.6 4.3-7.4 7.5c-1.8 3.1-2.7 6.5-2.7 10.1 0 3.7 0.9 7.1 2.7 10.2s4.3 5.6 7.4 7.4 6.5 2.7 10.2 2.7c3.6 0 7-0.9 10.1-2.7s5.6-4.3 7.5-7.4c1.8-3.2 2.7-6.6 2.7-10.2z"/>';

        //bytes memory _selectedCore4 = '';
        bytes memory _selectedCore4 = abi.encodePacked(
            _selectedCore1,
            '<path fill="url(#pattern)" d="m448.2 286.4 38.2-45.8-14.5-72.4-34.1-25.5c16.1 44.9 21.3 97.1 10.4 143.7zm-374-143.8-34.1 25.5-14.5 72.4 38.2 45.8c-10.9-46.5-5.7-98.7 10.4-143.7zm32.4 214.3z"/><path fill="url(#pattern)" d="m420.6 104.6c0.8 1.4 1.6 2.9 2.4 4.4l29.9 22.4-4.7-35.5c-7 5.5-15.8 8.8-25.3 8.8-0.8 0-1.6 0-2.3-0.1zm-37.8-50c1.5-6.6 4.7-12.7 9-17.7l-35.3-5.5c9.4 7 18.2 14.8 26.3 23.2zm40 32.1c12.8 0 23-10.2 23-23s-10.2-23-23-23-23 10.2-23 23 10.2 23 23 23z"/><path fill="url(#pattern)" d="m55 66.2v68.3l18-13.5v-54.8c4.4-3 7-7.9 7-13.2 0-8.8-7.2-16-16-16s-16 7.2-16 16c0 5.3 2.6 10.2 7 13.2z"/>'
        );

        // Return our selected core based on tokenAmount_
        if (tokenAmount_ >= 0 && tokenAmount_ <= 2500) {
            return _selectedCore1;
        } else if (tokenAmount_ > 2500 && tokenAmount_ <= 5000) {
            return _selectedCore2;
        } else if (tokenAmount_ > 5000 && tokenAmount_ <= 7500) {
            return _selectedCore3;
        } else {
            return _selectedCore4;
        }
    }

    // function _preparePackedColorStops(string[3] memory _colHexs) private pure returns (bytes memory) {
    //     bytes memory _stop_begin = '<stop offset="';
    //     bytes memory _stop_mid = '%" style="stop-color:';
    //     bytes memory _stop_end = ';"/>';

    //     // Each step contains two modifications
    //     // first is step offset, and then at that given offset - a color
    //     // This increases 100 bytes gas compared to initial strings idea
    //     // but for the lack of better optimized way, this is what I ended up with
    //     bytes memory stopPrep1_ = abi.encodePacked(_stop_begin, "0", _stop_mid, _colHexs[0], _stop_end);
    //     // Output:
    //     // <stop offset="0%" style="stop-color:#ffffff;"/>

    //     bytes memory stopPrep2_ = abi.encodePacked(_stop_begin, "10", _stop_mid, _colHexs[1], _stop_end);
    //     bytes memory stopPrep3_ = abi.encodePacked(_stop_begin, "30", _stop_mid, _colHexs[2], _stop_end);
    //     bytes memory stopPrep4_ = abi.encodePacked(_stop_begin, "70", _stop_mid, _colHexs[2], _stop_end);
    //     bytes memory stopPrep5_ = abi.encodePacked(_stop_begin, "90", _stop_mid, _colHexs[1], _stop_end);
    //     bytes memory stopPrep6_ = abi.encodePacked(_stop_begin, "100", _stop_mid, _colHexs[0], _stop_end);

    //     // This will prepare our color stops - 6 stops in total at 0%, 10%, 30%, 70%, 90%, and 100%
    //     return abi.encodePacked(stopPrep1_, stopPrep2_, stopPrep3_, stopPrep4_, stopPrep5_, stopPrep6_);
    // }

    function _preparePackedColorStops(
        string memory _colHex,
        string memory pathprogress
    ) private pure returns (bytes memory) {
        bytes memory _stop_begin = '<stop offset="';
        bytes memory _stop_mid = '%" style="stop-color:';
        bytes memory _stop_end = ';"/>';

        // Each step contains two modifications
        // first is step offset, and then at that given offset - a color
        // This increases 100 bytes gas compared to initial strings idea
        // but for the lack of better optimized way, this is what I ended up with
        return
            abi.encodePacked(
                _stop_begin,
                pathprogress,
                _stop_mid,
                _colHex,
                _stop_end
            );
        // bytes memory stopPrep1_ = abi.encodePacked(_stop_begin, pathprogress, _stop_mid, _colHexs[0], _stop_end);
        // // Output:
        // // <stop offset="0%" style="stop-color:#ffffff;"/>

        // bytes memory stopPrep2_ = abi.encodePacked(_stop_begin, "10", _stop_mid, _colHexs[1], _stop_end);
        // bytes memory stopPrep3_ = abi.encodePacked(_stop_begin, "30", _stop_mid, _colHexs[2], _stop_end);
        // bytes memory stopPrep4_ = abi.encodePacked(_stop_begin, "70", _stop_mid, _colHexs[2], _stop_end);
        // bytes memory stopPrep5_ = abi.encodePacked(_stop_begin, "90", _stop_mid, _colHexs[1], _stop_end);
        // bytes memory stopPrep6_ = abi.encodePacked(_stop_begin, "100", _stop_mid, _colHexs[0], _stop_end);

        // // This will prepare our color stops - 6 stops in total at 0%, 10%, 30%, 70%, 90%, and 100%
        // return abi.encodePacked(stopPrep1_, stopPrep2_, stopPrep3_, stopPrep4_, stopPrep5_, stopPrep6_);
    }

    // Function responsible for returning <color stops> filled with given colors
    // colors are based on tokenlevel that is checked upon returning the colorstops string - that is already abi encoded
    // _PrepareSVGStopColors
    // Note on why weird return values:
    // To prepare 6 tags of color stops, we can either prepare all tags within one function and return a string of bytes
    // Or we can create a function that generates single step based on input, and we call it 6 times to create the result
    // that we want. Although latter method seem like too much work, it actually reduces bytecode size and can be beneficial
    function _prepareSVGStopPoints(uint256 tokenAmount_)
        private
        pure
        returns (bytes memory)
    {
        // Within svg, color stops are 6
        // they start from initial color stop, goes to last, starts from last and come back to first.
        // So in total of 6 color stops, we have 3 distinct colors.
        string[3][4] memory _colors = [
            ["#ffffff", "#666666", "#333333"], // Level 1 colors
            ["#c5fccb", "#6cd4a1", "#027562"], // Level 2 colors
            ["#c6f7f5", "#30d5f2", "#074d87"], // Level 3 colors
            ["#fc9fc1", "#e61964", "#222b52"] // Level 4 colors
        ];

        // Return our selected color level
        if (tokenAmount_ >= 0 && tokenAmount_ <= 2500) {
            return
                abi.encodePacked(
                    _preparePackedColorStops(_colors[0][0], "0"),
                    _preparePackedColorStops(_colors[0][1], "10"),
                    _preparePackedColorStops(_colors[0][2], "30"),
                    _preparePackedColorStops(_colors[0][2], "70"),
                    _preparePackedColorStops(_colors[0][1], "90"),
                    _preparePackedColorStops(_colors[0][0], "100")
                );
        } else if (tokenAmount_ > 2500 && tokenAmount_ <= 5000) {
            return
                abi.encodePacked(
                    _preparePackedColorStops(_colors[1][0], "0"),
                    _preparePackedColorStops(_colors[1][1], "10"),
                    _preparePackedColorStops(_colors[1][2], "30"),
                    _preparePackedColorStops(_colors[1][2], "70"),
                    _preparePackedColorStops(_colors[1][1], "90"),
                    _preparePackedColorStops(_colors[1][0], "100")
                );
        } else if (tokenAmount_ > 5000 && tokenAmount_ <= 7500) {
            return
                abi.encodePacked(
                    _preparePackedColorStops(_colors[2][0], "0"),
                    _preparePackedColorStops(_colors[2][1], "10"),
                    _preparePackedColorStops(_colors[2][2], "30"),
                    _preparePackedColorStops(_colors[2][2], "70"),
                    _preparePackedColorStops(_colors[2][1], "90"),
                    _preparePackedColorStops(_colors[2][0], "100")
                );
        } else {
            return
                abi.encodePacked(
                    _preparePackedColorStops(_colors[3][0], "0"),
                    _preparePackedColorStops(_colors[3][1], "10"),
                    _preparePackedColorStops(_colors[3][2], "30"),
                    _preparePackedColorStops(_colors[3][2], "70"),
                    _preparePackedColorStops(_colors[3][1], "90"),
                    _preparePackedColorStops(_colors[3][0], "100")
                );
        }
    }

    // Base64 encoded version of the svg container with colors passed
    // The idea is to prepare base64 encoded image(svg) version, while adding missing parts of the svg
    // From the container and colors_
    function _base64EncodeImage(uint256 _tokenAmount)
        private
        pure
        returns (bytes memory)
    {
        // Get the svg container with svg core selected based on tokenamount
        // SVGContainer memory _svgCont = _prepareSVGContainer(_tokenAmount);
        // Get the svg color settings
        // string memory _svgStopColors = _prepareSVGStopColors(_tokenAmount);

        // Now start packing svg using the container and colors
        // Remember, each _svgColorStop member of Container, requires color and _svgColorEnd
        bytes memory _returning_svg_part1 = abi.encodePacked(
            '<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="gradient" x1="100%" y1="0%" x2="0%" y2="0%">', // Starting svg
            _prepareSVGStopPoints(_tokenAmount)
        );

        bytes memory _returning_svg = Base64.encodeBytes(
            abi.encodePacked(
                _returning_svg_part1, // Beginning of svg tag and setup
                _selectedCoreCommon, // common SVG core begis
                _getSVGCore(_tokenAmount), // SVG core part - astronaut shape/lines changes with core
                _selectedCoreEnd, // common core end part
                Strings.toString(_tokenAmount / 10**2), // Player's EXP balance ( Now to diplay accurately, reduce those borrowed 0s)
                "</text></svg>" // SVG End
            )
        );

        return abi.encodePacked("data:image/svg+xml;base64,", _returning_svg);
    }

    // Now the main function that will handle generating actual token url
    /// @param tokenId - the NFT token ID to render
    /// @param ownerBalance - Value of total EXP Token the owner of the NFT has
    /// @param tokenOwner - the address of the owner of the NFT
    function render(
        uint256 tokenId,
        uint256 ownerBalance,
        address tokenOwner
    ) external pure override returns (string memory tokenURI) {
        // cap ownerBalance at 99 tokens
        if(ownerBalance > 99 ether) ownerBalance = 99 ether;

        // ownerBalance going beyond expected values. As it's uint256, need to dial it down to 18 decimal
        // This will always result in 0 for every player that has sub-1 EXP
        // To solve this, we can increase our allow level. For example, just to be considered, have atleast 0.01 EXP or something
        // the more we dig into floating point, farther we have to reduce our divisor
        // Let's add 0.01 limit for this
        // This also means, every ownerBalance comparison would be with a 10 ** 2 number
        // If ownerBalance is 0.01 => ownerBalance = 1
        // If ownerBalance is 25.xx => ownerBalance = 25xx
        // so we will adjust our level calculation logic as well
        ownerBalance = ownerBalance / (10**16);
        // Get our image url prepared with ownerBalance
        bytes memory _imgUrl = _base64EncodeImage(ownerBalance);
        // // Get experience level that can be show in the middle of the image | Disabled until we figure out what can be returned
        // // string memory _expLevel = _getExperienceLevel(ownerBalance);
        // // Base64Encoded HTML part to identify where the problem is - Issue: Opensea isn't viewing NFT as expected
        string memory _base64Markup = string(
            abi.encodePacked(
                "data:text/html;base64,",
                Base64.encodeBytes(
                    abi.encodePacked(
                        '<!DOCTYPE html><html><object type="image/svg+xml" data="',
                        _imgUrl,
                        '" alt="EXPerience"></object></html>'
                    )
                )
            )
        );

        // Json that will be returned when tokenURI function request is received
        // This prepared the expected response format, including all the necessary data
        // to display image after call to tokenURI
        bytes memory _metaJson_start = abi.encodePacked(
            '{ "name": "Ethernaut EXPerience NFT #',
            Strings.toString(tokenId),
            "",
            '", "description": "Ethernaut EXPerience NFT.", "external_url": "https://github.com/SolDev-HP/EXPerience_Game", "attributes": [{"trait_type": "EXP Balance", "value": "',
            Strings.toString(ownerBalance / 10**2),
            '"}], "owner": "'
        );

        bytes memory _metaJson_end = abi.encodePacked(
            _metaJson_start,
            Strings.toHexString(uint160(tokenOwner)),
            '", "image":"',
            _imgUrl,
            '", "animation_url":"',
            _base64Markup,
            '"}'
        );

        tokenURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encodeBytes(_metaJson_end)
            )
        );
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

pragma solidity >=0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    bytes internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `bytes` representation.
     * As we require this function in the situations where expected result is 
     * in bytes, reduce the overhead of turning string into bytes, rather convert them once
     * and continue using them as parameters for further abi.encodePacked(arg...);
     */
    function encodeBytes(bytes memory data) internal pure returns (bytes memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        bytes memory table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        bytes memory result = new bytes(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}