import Web3 from 'web3';
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';

const web3 = new Web3("https://eth-mainnet.gateway.pokt.network/v1/5f3453978e354ab992c4da79");

// Replace with your whitelisted address and amounts
let users = [
    {
        address: '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4',
        amount: 10 
    },
    {
        address: '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2',
        amount: 5
    },
    {
        address: '0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db',
        amount: 5
    },
    {
        address: '0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB',
        amount: 7
    },
    {
        address: '0x617F2E2fD72FD9D5503197092aC168c91465E7f2',
        amount: 9
    },
    {
        address: '0x17F6AD8Ef982297579C203069C1DbfFE4348c372',
        amount: 10
    },
    {
        address: '0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678',
        amount: 15
    }
]

// ABI encodes strcut
let encoded = users.map(x => 
    web3.eth.abi.encodeParameter(
        {
            "Proof": {
                "one": 'address',
                "two": 'uint256' 
            }
        },
        {
            "one": x.address,
            "two": x.amount
        }
));


let leaves = encoded.map(x => keccak256(x));
let tree = new MerkleTree(leaves, keccak256, {sort: true});
let root = tree.getHexRoot();
console.log("[ROOT]: " + root);

//Get Proof
//replace index with index of needed proof element
let index = 4;
let leaf = leaves[index];
console.log("Proving:" + JSON.stringify(users[index]));

let proof = tree.getHexProof(leaf)
console.log(proof)