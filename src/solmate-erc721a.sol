// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// @dev Note that balanceOf does not revert if passed the zero address, in defiance of the ERC.
///           tokenIds are enumerable and we assume they start at 1
abstract contract ERC721 {

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*///////////////////////////////////////////////////////////////
                            PROOF STRUCT
    //////////////////////////////////////////////////////////////*/

    struct Proof {
        address who;
        uint256 amount;
    }

    /*///////////////////////////////////////////////////////////////
                          METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*///////////////////////////////////////////////////////////////
                            ERC721 STORAGE                        
    //////////////////////////////////////////////////////////////*/

    uint internal currentId = 1;

    bytes32 public MERKLE_ROOT;

    mapping (address => bool) public minted;

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) internal _ownerships;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*///////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, bytes32 _MERKLE) {

        name = _name;
        symbol = _symbol;
        MERKLE_ROOT = _MERKLE;

    }

    /*///////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {

        address owner = ownerOf(id);

        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;

        emit Approval(owner, spender, id);

    }

    function setApprovalForAll(address operator, bool approved) public virtual {

        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);

    }

    /*///////////////////////////////////////////////////////////////
                              ERC721-A LOGIC
    //////////////////////////////////////////////////////////////*/


    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        
        address prevOwner = ownerOf(id);

        require(
            msg.sender == prevOwner || 
            isApprovedForAll[prevOwner][to] || 
            msg.sender == getApproved[id]
        );
        
        require(prevOwner == from);
        require(to != address(0));

        delete getApproved[id];

        unchecked {

            balanceOf[from]--;
            balanceOf[to]++;

            _ownerships[id] = to;

            // see {ERC721-A}
            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint nextTokenId = id + 1;
            if (_ownerships[nextTokenId] == address(0)) {
                if (_exists(nextTokenId)) {
                    _ownerships[nextTokenId] = prevOwner;
                }
            }

        }

        emit Transfer(from, to, id);

    }
    

    function ownerOf(uint id) 
        public view returns (address) {

        require(_exists(id), 'ERC721A: owner query for nonexistent token');

        // gas spent here is related to largest user batch size
        unchecked {
            for (uint256 curr = id; curr >= 0; curr--) {
                if (_ownerships[curr] != address(0)) {
                    return _ownerships[curr];
                }
            }
        }

        revert('ERC721A: unable to determine the owner of token');            

    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < currentId;
    }

    /*///////////////////////////////////////////////////////////////
                              SAFE* LOGIC
    //////////////////////////////////////////////////////////////*/
    
    function safeTransferFrom(
            address from,
            address to,
            uint256 id
    ) public virtual {

            transferFrom(from, to, id);

            require(
                to.code.length == 0 ||
                    ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                    ERC721TokenReceiver.onERC721Received.selector,
                "UNSAFE_RECIPIENT"
            );

        }

    function safeMint(
        address to,
        uint256 amount,
        bytes32[] calldata proof
    ) public virtual {

        _mint(to, amount, proof, true);

    }


    /*///////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata

    }

    /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    // bool safe == safe mint
    function _mint(
        address to, 
        uint256 amount, 
        bytes32[] calldata proof, 
        bool safe
    ) internal virtual {

        require(to != address(0));
        require(amount != 0);
        require( !minted[to] );
        require( prove(to, amount, proof) ); //admin logic here

        // can only overflow if # of tokens > 2**256
        unchecked {

            minted[to] = true;

            uint newId = currentId;
            balanceOf[to] += amount;
            _ownerships[newId] = to;

            for (uint i; i < amount; i++) {
                emit Transfer(address(0), to, newId);
                newId++;
            }

            if (safe) {

                require(
                    to.code.length == 0 ||
                    ERC721TokenReceiver(to).onERC721Received(address(0), to, newId - 1, "") ==
                    ERC721TokenReceiver.onERC721Received.selector,
                    "UNSAFE_RECIPIENT"
                );

            }

            currentId = newId;

        }

    }

    /*///////////////////////////////////////////////////////////////
                       MERKLE TREE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function prove(address who, uint amount, bytes32[] memory proof) 
        internal view returns (bool) {

            require(msg.sender == who);

            Proof memory _proof = Proof(who, amount);
            bytes32 leaf = keccak256(abi.encode(_proof));
            bytes32 computedHash = leaf;

            for (uint256 i = 0; i < proof.length; i++) {
                bytes32 proofElement = proof[i];

                if (computedHash <= proofElement) {
                    // Hash(current computed hash + current element of the proof)
                    computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
                } else {
                    // Hash(current element of the proof + current computed hash)
                    computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
                }
            }

            // Check if the computed hash (root) is equal to the provided root
            return computedHash == MERKLE_ROOT;
    }
}





/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}