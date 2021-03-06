/**
 *Submitted for verification at optimistic.etherscan.io on 2022-05-10
*/

// Sources flattened with hardhat v2.6.0 https://hardhat.org

// File contracts/ToColor.sol

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library ToColor {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    function toColor(bytes3 value) internal pure returns (string memory) {
      bytes memory buffer = new bytes(6);
      for (uint256 i = 0; i < 3; i++) {
          buffer[i*2+1] = ALPHABET[uint8(value[i]) & 0xf];
          buffer[i*2] = ALPHABET[uint8(value[i]>>4) & 0xf];
      }
      return string(buffer);
    }
}


// File contracts/LoogieShipRender.sol

pragma solidity >=0.8.0 <0.9.0;

library LoogieShipRender {

  using ToColor for bytes3;

  function renderDefs(bytes3 wheelColor, bytes3 mastheadColor, bytes3 flagColor, bytes3 flagAlternativeColor, bool loogieMasthead, bool loogieFlag) public pure returns (string memory) {
    string memory render = string(abi.encodePacked(
      '<defs>',
        '<style>',
          '.cls-1,.cls-12,.cls-17,.cls-18,.cls-22,.cls-4,.cls-26{fill:none;}',
          '.cls-2{isolation:isolate;}',
          '.cls-10,.cls-11,.cls-3,.cls-4,.cls-5,.cls-7,.cls-8,.cls-9{stroke:#42210b;}',
          '.cls-10,.cls-11,.cls-12,.cls-17,.cls-18,.cls-20,.cls-21,.cls-3,.cls-4,.cls-5,.cls-7,.cls-8,.cls-9,.cls-24,.cls-25,.cls-26{stroke-miterlimit:10;}',
          '.cls-3{fill:url(#linear-gradient);}',
          '.cls-4,.cls-24{stroke-linecap:round;}',
          '.cls-18,.cls-4{stroke-width:2px;}',
          '.cls-5,.cls-9{fill:#',flagColor.toColor(),';}',
          '.cls-19,.cls-6{fill:#cbcbcb;}',
          '.cls-14,.cls-6{mix-blend-mode:multiply;}',
          '.cls-7{fill:url(#linear-gradient-2);}',
          '.cls-8{fill:url(#linear-gradient-3);}',
          '.cls-9{stroke-width:1.09px;}',
          '.cls-10{fill:url(#linear-gradient-4);}',
          '.cls-11{fill:url(#linear-gradient-5);}',
          '.cls-12{stroke:#',wheelColor.toColor(),';stroke-width:3.81px;}',
          '.cls-13{clip-path:url(#clip-path);}',
          '.cls-15{fill:url(#linear-gradient-6);}',
          '.cls-16{fill:#754c24;}',
          '.cls-17,.cls-18{stroke:#754c24;}',
          '.cls-17{stroke-width:2.13px;}',
          '.cls-20,.cls-24,.cls-25{fill:#',mastheadColor.toColor(),';}',
          '.cls-20,.cls-21,.cls-22,.cls-24,.cls-25,.cls-26{stroke:#000;}',
          '.cls-21{fill:#fff;}',
          '.cls-22{stroke-width:1.11px;}',
          '.cls-23{fill:#',flagAlternativeColor.toColor(),';}',
        '</style>',
        '<linearGradient id="linear-gradient" x1="225.7" y1="217.21" x2="231.4" y2="217.21" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#a57c52"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-2" x1="132.43" y1="152" x2="145.69" y2="152" xlink:href="#linear-gradient"/>',
        '<linearGradient id="linear-gradient-3" x1="115.36" y1="81.99" x2="162.22" y2="81.99" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#c59b6d"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
        '<linearGradient id="linear-gradient-4" x1="333.74" y1="147.55" x2="345.01" y2="147.55" xlink:href="#linear-gradient"/>',
        '<linearGradient id="linear-gradient-5" x1="116.69" y1="135.07" x2="309.22" y2="265.47" xlink:href="#linear-gradient-3"/>',
        '<clipPath id="clip-path">',
          '<path class="cls-1" d="M326.13,245.17c1.23,0,2.45.05,3.66.13,2.29-16.67,3-16.92,3-16.92H232.33l-4.18,16h-53.4c0,50.86,11.44,71.92,99.53,71.37a54.36,54.36,0,0,1,51.85-70.56Z"/>',
        '</clipPath>',
        '<linearGradient id="linear-gradient-6" x1="174.75" y1="263.16" x2="333.86" y2="263.16" gradientUnits="userSpaceOnUse">',
          '<stop offset="0" stop-color="#8b6239"/>',
          '<stop offset="1" stop-color="#603813"/>',
        '</linearGradient>',
      '</defs>'
      ));

      return render;
  }

  function renderShip(bytes3 wheelColor, bytes3 mastheadColor, bytes3 flagColor, bytes3 flagAlternativeColor, bool loogieMasthead, bool loogieFlag) public pure returns (string memory) {

    string memory masthead;
    string memory flag;

    if (loogieMasthead) {
      masthead = string(abi.encodePacked(
        '<path class="cls-20" d="M48.49,183.39s-1.76,5.12.91,6.59,6.54-1.15,10.31,1.09.44,12.21,15,18.11c18,7.32,21.13,7.87,25,10.58s1.61,6.46,4.32,13.7c6.69-3.1,4.35-13.77,4.35-13.77s8,4.39,13.74,1.46c-1.57-6.24-16.85-9.59-16.85-9.59s-6.88-2.17-11.14-7.21-9.29-10.43-15.72-14.13-12.21-5.09-12.94-9.3-3.89-8.48-7.63-7.83-9.24-3.21-9.24-3.21l-3.33,3s4.39,3.08,4.33,5.5A17.63,17.63,0,0,1,48.49,183.39Z"/>',
        '<path class="cls-20" d="M56.7,173.21s13.07-1.79,20,3.33,7.48,9.45,9.61,10.2c.69.24,3.86-.08,5.92,1.32s3.11,2.83,1.1,4.43-6-1-6-1a5,5,0,0,1,.17,2.68c-.39,1-1.89.16-2.72-1.19s-4.74-7.93-8.34-10.95-15.48-2.71-15.48-2.71"/>',
        '<circle class="cls-20" cx="43.68" cy="171.22" r="8.5"/>',
        '<circle class="cls-21" cx="36.52" cy="166.34" r="3.89"/>',
        '<circle class="cls-21" cx="40.6" cy="163.75" r="3.89"/>',
        '<circle cx="40.6" cy="163.75" r="1"/>',
        '<circle cx="35.08" cy="166.99" r="1"/>',
        '<path class="cls-22" d="M38,177.34a7.2,7.2,0,0,0,9.26-4.09"/>'
      ));
    } else {
      masthead = string(abi.encodePacked(
        '<circle class="cls-21" cx="47.27" cy="161.33" r="5.83"/>',
        '<circle cx="45.29" cy="159.92" r="1.5"/>',
        '<path class="cls-24" d="M73.1,166.34c8.26-1.44,28-9.26,25.8,3.39,7.49-2.18,10,7.26,5.13,8.47,5.3,1.51,6.62,13.59-3.8,10.45"/>',
        '<path class="cls-25" d="M35.77,168.34s11,25.07,29.63,34.48,24.54.43,36.38,9.09c7.61,5.56,9,11.22,6.56,17.3-3.63,8.9-2.72,14.17-2.72,14.17s12.08-2.22,15.07-11.26a32.67,32.67,0,0,0,16.16,9.08,23.66,23.66,0,0,0-7.26-18.53c-4.14-4.14-7.09-4.81-9.26-10.53S109.55,184.8,88,172.44C60,156.4,35.77,168.34,35.77,168.34Z"/>',
        '<circle class="cls-21" cx="56.11" cy="166.37" r="5.83"/>',
        '<circle cx="54.71" cy="165.52" r="1.5"/>',
        '<path class="cls-25" d="M44.81,170.55c1.82-13.75-26-12.9-5.4-1.55-4.31-2.37-13.71-2.27-8.06,3.21C35.14,176,44.23,175,44.81,170.55Z"/>',
        '<path class="cls-26" d="M68,189.46s5.87,12.69,24.5,9.77C94,186.2,79,178.38,79,178.38"/>',
        '<path class="cls-20" d="M41.5,167.19s-2.72.72-3.54,4.45"/>'
      ));
    }

    if (loogieFlag) {
      flag = string(abi.encodePacked(
        '<path class="cls-23" d="M105.35,131.91c3.06-1.37,6.46-2.54,9.76-1l1.73-6.14c-2.65-1.5-4.23-4.22-5.18-7-1.42-3.55-8.29,0-5.57,4.31,1,3.32-5.46,2.81-4,7.09C102.22,129.39,103.41,132.51,105.35,131.91Z"/>',
        '<path class="cls-23" d="M114.42,157.18c1.08-3.18,2.54-6.46,5.94-7.8L117,143.93c-2.9.92-6,.22-8.67-1-3.57-1.37-5.62,6.09-.64,7,3.12,1.43-1.61,6,2.51,7.72C110.44,157.75,113.54,159,114.42,157.18Z"/>',
        '<path class="cls-23" d="M171.46,131.91c-3.07-1.37-6.47-2.54-9.76-1L160,124.81c2.65-1.5,4.23-4.22,5.18-7,1.43-3.55,8.29,0,5.57,4.31-1,3.32,5.46,2.81,3.95,7.09C174.58,129.39,173.4,132.51,171.46,131.91Z"/>',
        '<path class="cls-23" d="M162.38,157.18c-1.07-3.18-2.53-6.46-5.93-7.8.15,0,3.24-5.82,3.5-5.4,4.59,2.39,9.37-4.4,12,1.14,1.75,4.87-4.12,3.17-4,7.5C170.11,155.91,165.65,160.24,162.38,157.18Z"/>',
        '<path class="cls-23" d="M155.86,121.83A11.16,11.16,0,1,0,138.2,108.7,11.16,11.16,0,1,0,121,122.27a21.27,21.27,0,1,0,34.84-.44Zm-7.72-17a8.9,8.9,0,1,1-8.9,8.9A8.89,8.89,0,0,1,148.14,104.87Zm-19.88,0a8.9,8.9,0,1,1-8.91,8.9A8.9,8.9,0,0,1,128.26,104.87Zm24.61,32.42H123.81v-2h29.06Z"/>'
      ));
    } else {
      flag = string(abi.encodePacked(
        '<polygon class="cls-23" points="187.25 123.39 181.98 104.15 138.63 123.3 100.18 103.16 94.85 122.63 137.9 145.18 187.25 123.39"/>',
        '<polygon class="cls-23" points="173.77 91.71 108.8 91.71 137.81 106.91 173.77 91.71"/>',
        '<polygon class="cls-23" points="192.26 141.67 138.78 164.16 90.57 138.27 85.22 157.79 106.41 169.17 177.76 169.17 197.52 160.86 192.26 141.67"/>'
      ));
    }

    string memory render = string(abi.encodePacked(
      '<g id="ship" class="cls-2">',
        '<g id="Layer_1" data-name="Layer 1">',
          '<polygon class="cls-3" points="231.4 235.82 225.7 235.82 226.56 198.59 230.54 198.59 231.4 235.82"/>',
          '<circle class="cls-4" cx="230.7" cy="185.42" r="12.87"/>',
          '<line class="cls-4" x1="225.45" y1="169.28" x2="235.95" y2="201.55"/>',
          '<line class="cls-4" x1="246.84" y1="180.17" x2="214.56" y2="190.67"/>',
          '<line class="cls-4" x1="238.4" y1="170.29" x2="223" y2="200.54"/>',
          '<line class="cls-4" x1="245.82" y1="193.11" x2="215.58" y2="177.72"/>',
          '<path class="cls-5" d="M394.77,120.67c-13.62-3.82-15.26-3.82-9.81-21.25S340.28,88,340.28,88l.55,28.34s24.52-4.91,20.7,11.44c-2,8.41,10.54,13.44,26.16,8.17,10.32-3.48,24-4.9,31.06,5.45C423.11,124.48,408.39,124.48,394.77,120.67Z"/>',
          '<path class="cls-6" d="M340.28,88l.55,28.34a28.26,28.26,0,0,1,10.1-.54c-.46-9.52.38-19,.24-28.63C344.9,87.42,340.28,88,340.28,88Z"/>',
          '<polygon class="cls-7" points="145.69 223.66 132.43 223.66 134.43 80.35 143.69 80.35 145.69 223.66"/>',
          '<path class="cls-6" d="M143.69,80.35h-9.26l-1.36,97.74,12,2.67Z"/>',
          '<polygon class="cls-8" points="152.22 93.97 125.36 93.97 115.36 70 162.22 70 152.22 93.97"/>',
          '<polygon class="cls-9" points="179.12 90.71 103.37 90.71 81.58 170.26 200.91 170.26 179.12 90.71"/>',
          '<polygon class="cls-10" points="345.01 208.39 333.74 208.39 335.44 86.7 343.31 86.7 345.01 208.39"/>',
          '<path class="cls-11" d="M326.13,255.76a43.13,43.13,0,0,1,13.94,2.31c1.75-11.37,3.5-22.15,3.5-22.15,1.47-10.36,9.47-18.14,19.36-20.85a1.72,1.72,0,0,0,1.08-1.22l9-39.78c-1.18.41-65.9,11.43-66.51,13.4-4.49,13-13.62,26.51-29,25.92H224.72a1.69,1.69,0,0,0-1.61,1.16l-4.93,16.75a1.69,1.69,0,0,1-1.61,1.16H157a12.35,12.35,0,0,1-11.75-8.53c-2-7.67-6.65-14.57-13.9-18.09L42.53,161l-3.09,8.72s74.83,43.68,75.92,58.94c8.74,101.78,153.1,95.18,170.55,94.91,1.51,0,3-.1,4.42-.21a43.27,43.27,0,0,1,35.8-67.59Z"/>',
          '<g class="wheel">',
            '<circle class="cls-12" cx="326.36" cy="299.54" r="30.05"/>',
            '<line class="cls-12" x1="326.36" y1="259.91" x2="326.36" y2="339.17"/>',
            '<line class="cls-12" x1="365.99" y1="299.54" x2="286.73" y2="299.54"/>',
            '<line class="cls-12" x1="354.39" y1="271.51" x2="298.34" y2="327.56"/>',
            '<line class="cls-12" x1="354.39" y1="327.56" x2="298.34" y2="271.51"/>',
            '<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="0 326.36 299.54" to="360 326.36 299.54" begin="0s" dur="4s" repeatCount="indefinite" additive="sum" />',
          '</g>',
          '<g class="cls-13">',
            '<g class="cls-14">',
              '<path class="cls-15" d="M326.13,245.17c1.23,0,2.45.05,3.66.13,2.29-16.67,4.07-34.72,4.07-34.72H229.24l-8.17,33.78H174.75c0,50.86,11.44,71.92,99.53,71.37a54.36,54.36,0,0,1,51.85-70.56Z"/>',
            '</g>',
            '<circle class="cls-16" cx="271.29" cy="247.93" r="2.9"/>',
            '<circle class="cls-16" cx="281.37" cy="241.09" r="2.9"/>',
            '<circle class="cls-16" cx="259.51" cy="253.66" r="2.72"/>',
            '<line class="cls-17" x1="257.57" y1="253.12" x2="289.45" y2="262.25"/>',
            '<line class="cls-18" x1="271.47" y1="248.18" x2="282.23" y2="271.33"/>',
            '<line class="cls-18" x1="281.28" y1="241.36" x2="284.41" y2="267.52"/>',
          '</g>',
          masthead,
          flag,
        '</g>',
      '</g>'
      ));

    return render;
  }
}