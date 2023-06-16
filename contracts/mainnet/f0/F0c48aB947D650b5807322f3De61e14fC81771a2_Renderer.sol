//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./SVG.sol";
import "./Utils.sol";

contract Renderer {
    function tokenURI(uint256 _tokenId, uint256 _tokenBalance, uint256 _unlockTime, uint256 _lockedBalance) public view returns (string memory) {
        // Assuming font size is 24px, the width of monospace is roughly 14px wide.
        uint256 balanceWidth = 14 * (bytes(thousandSeparator(_tokenBalance)).length + 11);
        uint256 lockedWidth = 14 * (bytes(thousandSeparator(_lockedBalance)).length + 10);
        return
            string.concat(
                '<svg width="711" height="1101" fill="none" xmlns="http://www.w3.org/2000/svg">'
                '<rect x="1.5" y="1.5" width="708" height="1098" rx="81.5" fill="#0F0F0F"/><rect x="1.5" y="1.5" width="708" height="1098" rx="81.5" stroke="url(#paint0_linear)" stroke-width="3"/><rect x="1.5" y="1.5" width="708" height="1098" rx="81.5" stroke-width="3"/><g clip-path="url(#clip0)"><rect x="29" y="29" width="653" height="653" rx="76" fill="url(#paint2_linear)"/><rect x="29" y="29" width="653" height="653" rx="76" fill="url(#paint3_radial)" fill-opacity="0.2"/><rect x="29" y="29" width="653" height="653" rx="76" fill="url(#paint4_linear)" fill-opacity="0.2"/><g style="mix-blend-mode:overlay" opacity="0.24"><path d="M355.001 419C354.976 383.664 326.337 355.025 291.001 355C326.337 354.975 354.976 326.336 355.001 291C355.026 326.336 383.665 354.975 419.001 355C383.665 355.025 355.026 383.664 355.001 419Z" fill="black"/></g><g style="mix-blend-mode:overlay" opacity="0.24"><path d="M355.001 419C354.976 383.664 326.337 355.025 291.001 355C326.337 354.975 354.976 326.336 355.001 291C355.026 326.336 383.665 354.975 419.001 355C383.665 355.025 355.026 383.664 355.001 419Z" fill="black"/></g><g style="mix-blend-mode:multiply"><path d="M77.2366 435.022L98.1501 435.022L125.537 435.022L154.667 426.552L180.309 413.345L208.944 392.166L235.083 358.526L248.779 336.348L264.712 289.505L332.185 248.888L358.324 235.184L407.372 215.251L454.677 193.571L489.531 171.397L539.577 132.026L597.837 64L600.325 68.7344L602.814 78.2018L602.814 94.8972L599.079 112.09L584.641 146.476L562.233 187.094L542.065 215.5L507.708 255.368L520.406 255.12L566.465 244.404L599.828 235.433L631.694 219.487L734.77 171.894L726.804 188.838L706.636 218.989L690.703 238.673L665.803 268.824L682.733 266.333L724.063 272.312L746.223 261.845L784.067 229.95L813.692 167.158L815.187 241.664L807.469 264.837L805.477 271.563L802.24 277.294L769.128 308.94L787.553 313.176L820.167 338.594L896.352 387.181L921 402.132L882.162 521.239L790.29 669.25L647.879 772.905L508.205 817.758L382.475 820L396.416 785.117L437.001 776.643L482.811 764.435L529.367 745.746L577.917 723.071L625.968 696.907L670.784 662.521L720.329 609.446L723.069 601.722L725.061 596.239L725.558 589.265L725.309 574.811L725.558 559.86L721.326 551.639L714.354 542.17L699.167 522.735L682.982 503.549L660.329 482.867L641.407 466.42L611.529 448.978L580.406 431.036L557.75 421.816L531.362 410.606L504.97 403.379L495.509 401.137L495.758 395.655L503.724 389.423L518.663 381.947L541.817 374.973L590.367 375.47L611.032 381.699L663.314 402.629L693.192 420.572L735.267 447.234L752.943 459.442L789.793 493.828L783.57 481.371L772.614 469.159L755.435 449.724L737.756 433.278L707.133 405.621L684.476 392.166L655.845 377.464L643.398 370.237L615.761 362.761L588.873 355.787L568.705 353.293L548.54 352.546L527.375 350.056L510.196 352.049L496.007 355.538L489.531 357.03L482.065 364.257L473.35 372.23L468.121 380.704L466.626 390.421L466.626 401.635L470.112 411.601L477.333 423.812L490.032 439.51L506.962 458.944L524.141 476.386L500.735 471.405L481.068 467.667L459.657 462.185L440.487 459.691L427.291 458.198L406.875 457.946L389.696 462.931L370.025 474.144L356.581 484.11L352.349 492.083L319.238 489.593L275.167 488.846L254.254 492.833L246.039 496.322L237.575 502.302L228.363 507.784L223.134 512.517L215.664 521.488L212.427 528.466L210.435 534.943L209.689 538.432L187.53 537.185L171.348 536.439L152.426 529.212L134.5 518.496L125.039 510.772L113.586 501.804L102.881 489.593L95.6604 477.882L88.4403 465.173L81.7179 450.971L77.2366 439.758L74 435.022L77.2366 435.022Z" fill="url(#paint5_linear)"/></g><g style="mix-blend-mode:multiply"><path d="M77.2366 435.022L98.1501 435.022L125.537 435.022L154.667 426.552L180.309 413.345L208.944 392.166L235.083 358.526L248.779 336.348L264.712 289.505L332.185 248.888L358.324 235.184L407.372 215.251L454.677 193.571L489.531 171.397L539.577 132.026L597.837 64L600.325 68.7344L602.814 78.2018L602.814 94.8972L599.079 112.09L584.641 146.476L562.233 187.094L542.065 215.5L507.708 255.368L520.406 255.12L566.465 244.404L599.828 235.433L631.694 219.487L734.77 171.894L726.804 188.838L706.636 218.989L690.703 238.673L665.803 268.824L682.733 266.333L724.063 272.312L746.223 261.845L784.067 229.95L813.692 167.158L815.187 241.664L807.469 264.837L805.477 271.563L802.24 277.294L769.128 308.94L787.553 313.176L820.167 338.594L896.352 387.181L921 402.132L882.162 521.239L790.29 669.25L647.879 772.905L508.205 817.758L382.475 820L396.416 785.117L437.001 776.643L482.811 764.435L529.367 745.746L577.917 723.071L625.968 696.907L670.784 662.521L720.329 609.446L723.069 601.722L725.061 596.239L725.558 589.265L725.309 574.811L725.558 559.86L721.326 551.639L714.354 542.17L699.167 522.735L682.982 503.549L660.329 482.867L641.407 466.42L611.529 448.978L580.406 431.036L557.75 421.816L531.362 410.606L504.97 403.379L495.509 401.137L495.758 395.655L503.724 389.423L518.663 381.947L541.817 374.973L590.367 375.47L611.032 381.699L663.314 402.629L693.192 420.572L735.267 447.234L752.943 459.442L789.793 493.828L783.57 481.371L772.614 469.159L755.435 449.724L737.756 433.278L707.133 405.621L684.476 392.166L655.845 377.464L643.398 370.237L615.761 362.761L588.873 355.787L568.705 353.293L548.54 352.546L527.375 350.056L510.196 352.049L496.007 355.538L489.531 357.03L482.065 364.257L473.35 372.23L468.121 380.704L466.626 390.421L466.626 401.635L470.112 411.601L477.333 423.812L490.032 439.51L506.962 458.944L524.141 476.386L500.735 471.405L481.068 467.667L459.657 462.185L440.487 459.691L427.291 458.198L406.875 457.946L389.696 462.931L370.025 474.144L356.581 484.11L352.349 492.083L319.238 489.593L275.167 488.846L254.254 492.833L246.039 496.322L237.575 502.302L228.363 507.784L223.134 512.517L215.664 521.488L212.427 528.466L210.435 534.943L209.689 538.432L187.53 537.185L171.348 536.439L152.426 529.212L134.5 518.496L125.039 510.772L113.586 501.804L102.881 489.593L95.6604 477.882L88.4403 465.173L81.7179 450.971L77.2366 439.758L74 435.022L77.2366 435.022Z" fill="url(#paint6_linear)"/></g></g>',
                svg.text(
                    string.concat(
                        svg.prop('x', '64px'),
                        svg.prop('y', '640px'),
                        svg.prop('font-family', 'Helvetica, Arial, sans-serif'),
                        svg.prop('font-weight', 'bold'),
                        svg.prop('font-size', '62px'),
                        svg.prop('fill', '#25282B')
                    ),
                    string.concat(
                        svg.cdata('#'),
                        utils.uint2str(_tokenId)
                    )
                ),
                '<text x="410px" y="638px" font-family="Helvetica, Arial, sans-serif" font-size="22px" fill="#25282B">vote-escrowed Iron Bank</text><g style="transform:translate(49px, 830px)"><text font-family="Helvetica, Arial, sans-serif" font-size="140px" fill="url(\'#paint7_linear\')">Iron Bank</text></g>'
                '<g style="transform:translate(55px, 937px)">',
                svg.rect(
                    string.concat(
                        svg.prop('width', utils.uint2str(balanceWidth)),
                        svg.prop('height', '40'),
                        svg.prop('rx', '8'),
                        svg.prop('fill', '#151A26'),
                        svg.prop('fill-opacity', '0.5')
                    ),
                    utils.NULL
                ),
                svg.text(
                    string.concat(
                        svg.prop('x', '12px'),
                        svg.prop('y', '30px'),
                        svg.prop('font-family', '\'Courier New\', monospace'),
                        svg.prop('font-size', '30px'),
                        svg.prop('fill', '#FFFFFF')
                    ),
                    string.concat(
                        'Balance: ',
                        thousandSeparator(_tokenBalance)
                    )
                ),
                '</g>',
                '<g style="transform:translate(55px, 993px)">',
                svg.rect(
                    string.concat(
                        svg.prop('width', utils.uint2str(lockedWidth)),
                        svg.prop('height', '40'),
                        svg.prop('rx', '8'),
                        svg.prop('fill', '#151A26'),
                        svg.prop('fill-opacity', '0.5')
                    ),
                    utils.NULL
                ),
                svg.text(
                    string.concat(
                        svg.prop('x', '12px'),
                        svg.prop('y', '30px'),
                        svg.prop('font-family', '\'Courier New\', monospace'),
                        svg.prop('font-size', '30px'),
                        svg.prop('fill', '#FFFFFF')
                    ),
                    string.concat(
                        'Locked: ',
                        thousandSeparator(_lockedBalance)
                    )
                ),
                '</g>',
                '<text x="646px" y="966px" text-anchor="end" font-family="Helvetica, Arial, sans-serif" font-size="30px" fill="white">Unlock in</text>',
                svg.text(
                    string.concat(
                        svg.prop('x', '646px'),
                        svg.prop('y', '1023px'),
                        svg.prop('font-family', '\'Helvetica, Arial\', sans-serif'),
                        svg.prop('font-size', '42px'),
                        svg.prop('fill', '#FFFFFF'),
                        svg.prop('text-anchor', 'end')
                    ),
                    formatUnlockDuration(_unlockTime)
                ),
                '<defs><linearGradient id="paint0_linear" x1="355.5" y1="3" x2="355.5" y2="1098" gradientUnits="userSpaceOnUse"><stop stop-color="#292929"/><stop offset="1" stop-color="#523E35" stop-opacity="0"/></linearGradient><linearGradient id="paint2_linear" x1="29" y1="51.5" x2="682" y2="682" gradientUnits="userSpaceOnUse"><stop stop-color="#8FBDA1"/><stop offset="0.494792" stop-color="#c7ecd5"/><stop offset="0.677" stop-color="#a8ddbc"/><stop offset="1" stop-color="#8FBDA1"/><animateTransform attributeName="gradientTransform" type="translate" from="-530 -400" to="600 520" begin="0s" dur="3s" repeatCount="indefinite"/></linearGradient><radialGradient id="paint3_radial" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(355.5 355.5) rotate(90) scale(326.5)"><stop/><stop offset="1" stop-opacity="0"/></radialGradient><linearGradient id="paint4_linear" x1="355.5" y1="29" x2="355.5" y2="682" gradientUnits="userSpaceOnUse"><stop stop-color="#9DC9B0"/><stop offset="0.505208" stop-color="#51695E"/><stop offset="1" stop-color="#8FBAA0"/></linearGradient><linearGradient id="paint5_linear" x1="136.908" y1="248.985" x2="812.456" y2="703.066" gradientUnits="userSpaceOnUse"><stop stop-color="#D1D3D4"/><stop offset="1" stop-color="#E6E7E8"/></linearGradient><linearGradient id="paint6_linear" x1="136.908" y1="248.985" x2="812.457" y2="703.066" gradientUnits="userSpaceOnUse"><stop stop-color="#D1D3D4"/><stop offset="1" stop-color="#E6E7E8"/></linearGradient><linearGradient id="paint7_linear" x1="0" y1="750" x2="254.867" y2="801.602" gradientUnits="userSpaceOnUse"><stop stop-color="white"/><stop offset="0.4" stop-color="#798F84"/><stop offset="0.7" stop-color="#8FAD9C"/><stop offset="1" stop-color="white"/><animateTransform attributeName="gradientTransform" type="translate" from="-120 -1300" to="160 3100" begin="0s" dur="3s" repeatCount="indefinite"/></linearGradient><clipPath id="clip0"><rect x="29" y="29" width="653" height="653" rx="76" fill="white"/></clipPath></defs>'
                '</svg>'
            );
    }

    function thousandSeparator(uint256 number) internal pure returns (string memory output) {
        string memory r = '';
        for (uint256 i = 0; i < 6; i++) {
            if (number > 1000) {
                r = utils.uint2str(number % 1000);
                uint256 length = bytes(r).length;
                r = length == 2 ? string.concat("0", r) : length == 1 ? string.concat("00", r) : r;
                output = string.concat(",", r, output);
            } else {
                r = utils.uint2str(number);
                output = string.concat(r, output);
                break;
            }
            number = number / 1000;
        }
        return output;
    }

    function formatUnlockDuration(uint256 timestamp) internal view returns (string memory output) {
        if (blockTimestamp() >= timestamp) {
            return "0D";
        }

        uint256 dt = timestamp - blockTimestamp();
        // we want to round up after the division, so adding (1 days - 1) here
        uint256 remainderDays = (dt + 1 days - 1) / 1 days;

        uint256 numYears = remainderDays / 365;
        if (numYears > 0) {
            remainderDays = remainderDays % 365;
            output = string.concat(utils.uint2str(numYears), "Y");
        }

        uint256 numWeeks = remainderDays / 7;
        if (numWeeks > 0) {
            remainderDays = remainderDays % 7;
            if (numYears > 0) {
                uint256 carry = remainderDays > 0 ? 1 : 0;
                output = string.concat(output, " ", utils.uint2str(numWeeks + carry), "W");
                return output;
            } else {
                output = string.concat(utils.uint2str(numWeeks), "W");
            }
        }

        if (remainderDays == 0) {
            return output;
        }

        if ((numYears > 0 || numWeeks > 0)) {
            output = string.concat(output, " ", utils.uint2str(remainderDays), "D");
        } else {
            output = string.concat(utils.uint2str(remainderDays), "D");
        }
    }

    function blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import './Utils.sol';

// Core SVG utilitiy library which helps us construct
// onchain SVG's with a simple, web-like API.
library svg {
    /* MAIN ELEMENTS */
    function g(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('g', _props, _children);
    }

    function path(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('path', _props, _children);
    }

    function text(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('text', _props, _children);
    }

    function line(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('line', _props, _children);
    }

    function circle(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('circle', _props, _children);
    }

    function circle(string memory _props)
        internal
        pure
        returns (string memory)
    {
        return el('circle', _props);
    }

    function rect(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('rect', _props, _children);
    }

    function rect(string memory _props)
        internal
        pure
        returns (string memory)
    {
        return el('rect', _props);
    }

    function filter(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('filter', _props, _children);
    }

    function cdata(string memory _content)
        internal
        pure
        returns (string memory)
    {
        return string.concat('<![CDATA[', _content, ']]>');
    }

    /* GRADIENTS */
    function radialGradient(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('radialGradient', _props, _children);
    }

    function linearGradient(string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el('linearGradient', _props, _children);
    }

    function gradientStop(
        uint256 offset,
        string memory stopColor,
        string memory _props
    ) internal pure returns (string memory) {
        return
            el(
                'stop',
                string.concat(
                    prop('stop-color', stopColor),
                    ' ',
                    prop('offset', string.concat(utils.uint2str(offset), '%')),
                    ' ',
                    _props
                )
            );
    }

    function animateTransform(string memory _props)
        internal
        pure
        returns (string memory)
    {
        return el('animateTransform', _props);
    }

    function image(string memory _href, string memory _props)
        internal
        pure
        returns (string memory)
    {
        return
            el(
                'image',
                string.concat(prop('href', _href), ' ', _props)
            );
    }

    /* COMMON */
    // A generic element, can be used to construct any SVG (or HTML) element
    function el(
        string memory _tag,
        string memory _props,
        string memory _children
    ) internal pure returns (string memory) {
        return
            string.concat(
                '<',
                _tag,
                ' ',
                _props,
                '>',
                _children,
                '</',
                _tag,
                '>'
            );
    }

    // A generic element, can be used to construct any SVG (or HTML) element without children
    function el(
        string memory _tag,
        string memory _props
    ) internal pure returns (string memory) {
        return
            string.concat(
                '<',
                _tag,
                ' ',
                _props,
                '/>'
            );
    }

    // an SVG attribute
    function prop(string memory _key, string memory _val)
        internal
        pure
        returns (string memory)
    {
        return string.concat(_key, '=', '"', _val, '" ');
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// Core utils used extensively to format CSS and numbers.
library utils {
    // used to simulate empty strings
    string internal constant NULL = '';

    // formats a CSS variable line. includes a semicolon for formatting.
    function setCssVar(string memory _key, string memory _val)
        internal
        pure
        returns (string memory)
    {
        return string.concat('--', _key, ':', _val, ';');
    }

    // formats getting a css variable
    function getCssVar(string memory _key)
        internal
        pure
        returns (string memory)
    {
        return string.concat('var(--', _key, ')');
    }

    // formats getting a def URL
    function getDefURL(string memory _id)
        internal
        pure
        returns (string memory)
    {
        return string.concat('url(#', _id, ')');
    }

    // formats rgba white with a specified opacity / alpha
    function white_a(uint256 _a) internal pure returns (string memory) {
        return rgba(255, 255, 255, _a);
    }

    // formats rgba black with a specified opacity / alpha
    function black_a(uint256 _a) internal pure returns (string memory) {
        return rgba(0, 0, 0, _a);
    }

    // formats generic rgba color in css
    function rgba(
        uint256 _r,
        uint256 _g,
        uint256 _b,
        uint256 _a
    ) internal pure returns (string memory) {
        string memory formattedA = _a < 100
            ? string.concat('0.', utils.uint2str(_a))
            : '1';
        return
            string.concat(
                'rgba(',
                utils.uint2str(_r),
                ',',
                utils.uint2str(_g),
                ',',
                utils.uint2str(_b),
                ',',
                formattedA,
                ')'
            );
    }

    // checks if two strings are equal
    function stringsEqual(string memory _a, string memory _b)
        internal
        pure
        returns (bool)
    {
        return
            keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    }

    // returns the length of a string in characters
    function utfStringLength(string memory _str)
        internal
        pure
        returns (uint256 length)
    {
        uint256 i = 0;
        bytes memory string_rep = bytes(_str);

        while (i < string_rep.length) {
            if (string_rep[i] >> 7 == 0) i += 1;
            else if (string_rep[i] >> 5 == bytes1(uint8(0x6))) i += 2;
            else if (string_rep[i] >> 4 == bytes1(uint8(0xE))) i += 3;
            else if (string_rep[i] >> 3 == bytes1(uint8(0x1E)))
                i += 4;
                //For safety
            else i += 1;

            length++;
        }
    }

    // converts an unsigned integer to a string
    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return '0';
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}