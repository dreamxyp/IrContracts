pragma solidity ^0.4.0;

contract chromosphere {

    uint8 private constant PRICE = 2;
    uint8 private constant RADIX = 6;
    uint8 private constant MAXRED = 33;
    uint8 private constant MAXBLUE = 16;
    uint8 private constant MAXBALL = 7;
    uint256 private constant COOLDOWN = 86400;
    uint256 private constant BOUNSPOOL = 5000000 ether;

    struct Gambler {
        address addr;
        bool[MAXRED] reds;
        bool[MAXBLUE] blues;
    }

    uint256 public deadline;
    address public founder;
    address public pool;
    string public name;
    string public symbol;
    bool private active;

    // index 0 and 1 is the percent of rewards amount pre bet
    // index 2-5 are fixed rewards pre bet
    uint256[6] private rewards = [uint256(70), 30, 3000, 200, 10, 5];
    uint8[MAXBALL] private answer;
    Gambler[] private gamblers;

    constructor(string _name, string _symbol) public payable {
        name = _name;
        symbol = _symbol;
        founder = msg.sender;
        active = false;
    }

    function answerOf() external view returns (uint8[7] balls) {
        balls = answer;
    }

    function open(address _currency, uint256 _deadline) public {
        require(!active);
        require(founder == msg.sender);
        require(_currency != address(this));
        require(_deadline >= COOLDOWN + now);
        require(now >= COOLDOWN + deadline);

        delete gamblers;
        delete answer;
        if (_currency == address(0)) {
            assert(address(this).balance >= BOUNSPOOL);
        } else {
            // TODO fix msg.origin bug
            assert(_currency.call(bytes4(keccak256("transferFrom")), msg.sender, address(this), BOUNSPOOL));
            assembly {}
        }
        deadline = _deadline;
        pool = _currency;
        active = true;
    }

    function lottery() public {
        require(active);
        require(msg.sender == founder);
        require(now >= deadline);
        uint256 number = block.number;
        for (uint8 i = 0; i < MAXBALL; i++) {
            if (i < RADIX) {
                answer[i] = _randBall(blockhash(number - i), MAXRED);
            } else {
                answer[i] = _randBall(blockhash(number - i), MAXBLUE);
            }
        }
        deadline = now;
        active = false;
        assert(answer.length == MAXBALL);
    }

    function enter(uint8[] _reds, uint8[] _blues) public payable {
        require(active);
        require(now < deadline);
        require(_reds.length >= RADIX && _blues.length >= 1);
        require(_reds.length <= MAXRED && _blues.length <= MAXBLUE);
        uint256 stake = _evalStake(uint8(_reds.length), uint8(_blues.length));
        if (pool == address(0)) {
            assert(msg.value >= stake);
        } else {
            // TODO fix msg.origin bug
            assert(pool.call(bytes4(keccak256("transferFrom")), msg.sender, address(this), stake));
        }

        bool[MAXRED] memory reds;
        bool[MAXBLUE] memory blues;
        for (uint8 i = 0; i <= _reds.length; i++) {
            reds[_reds[i]] = true;
        }
        for (uint8 i = 0; i <= _blues.length; i++) {
            blues[_blues[i]] = true;
        }
        Gambler memory gambler = Gambler(msg.sender, reds, blues);
        gamblers.push(gambler);
    }

    function takePrize() public returns (bool) {
        require(!active);
        require(now < deadline + COOLDOWN);
        for (uint256 i = 0; i < gamblers.length; i++) {
            Gambler memory gambler = gamblers[i];
            if (gambler.addr == msg.sender) {
                delete gamblers[i];
                uint8 awardLevel = _evalvel(gambler);
                if (awardLevel == 0) {
                    return false;
                } else {
                    _takePrize(gambler.addr, awardLevel);
                    return true;
                }
            }
        }
        return false;
    }

    function _takePrize(address _winner, uint8 _level) private {
        uint256 bonus = 0;
        if (_level == 1) {

        }
        if (pool == address(0)) {
            assert(address(this).balance >= bonus);
            _winner.transfer(bonus);
        } else {
            assert(pool.call(bytes4(keccak256("transfer")), _winner, bonus));
        }
    }

    function _evalvel(Gambler memory _gambler) private constant returns (uint8) {
        (uint8 reds, uint8 blues) = (0, 0);
        for (uint8 i = 0; i < MAXBALL; i++) {
            if (i < RADIX) {
                if (_gambler.reds[answer[i]]) {
                    reds += 1;
                }
            } else {
                if (_gambler.reds[answer[i]]) {
                    blues += 1;
                }
            }
        }
        return _picklevel(reds, blues);
    }

    function _picklevel(uint8 _reds, uint8 _blues) private pure returns (uint8) {
        uint8 winings = _reds + _blues;
        if (winings == MAXBALL) {
            return 1;
        } else if (winings == MAXBALL - 1) {
            if (_blues == 0) {
                return 2;
            } else {
                return 3;
            }
        } else if (winings == MAXBALL - 2) {
            return 4;
        } else if (winings == MAXBALL - 3) {
            return 5;
        } else if (_blues > 0) {
            return 6;
        } else {
            return 0;
        }
    }

    function _evalStake(uint8 _reds, uint8 _blues) private pure returns (uint256) {
        return _fact(_reds) / _fact(RADIX) / _fact(_reds - RADIX) * _blues * PRICE;
    }

    function _fact(uint8 n) private pure returns (uint256 ret) {
        for (; n > 0; n--) {
            ret *= n;
        }
    }

    // DISCLAIMER: This is pretty random... but not truly random.
    function _randBall(bytes32 _hash, uint8 _r) private constant returns (uint8) {
        bytes memory b = abi.encodePacked(block.difficulty, block.coinbase, now, _hash);
        return uint8(uint256(keccak256(b)) % _r) + 1;
    }
}
