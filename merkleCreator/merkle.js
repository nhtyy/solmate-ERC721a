import Web3 from 'web3';

const web3 = new Web3("https://eth-mainnet.gateway.pokt.network/v1/5f3453978e354ab992c4da79");

let x = web3.eth.abi.encodeParameter(
    {
        "Proof": {
            "one": 'address',
            "two": 'uint256' 
        }
    },
    {
        "one": '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4',
        "two": 10
    }
)

console.log(x);