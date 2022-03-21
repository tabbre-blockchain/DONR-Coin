pragma solidity ^0.4.24;

/**
 * 
 * DONR CHECKER Interface Smart Contract
 * 
 */


contract DonrChecker { 


    enum checkReasonCode {
        OK, 
        FAILED_FROM_ACCT_NOT_REGISTERED,
        FAILED_FROM_ACCT_LOCKED, 
        FAILED_FROM_ACCT_FROZEN, 
        FAILED_FROM_ACCT_CONFISCATED,
        FAILED_TO_ACCT_NOT_REGISTERED,
        FAILED_TO_ACCT_LOCKED,
        FAILED_TO_ACCT_FROZEN,
        FAILED_TO_ACCT_CONFISCATED,
        FAILED_ACCT_NOT_CONFISCATED,
        FAILED_FROM_ACCT_VESTING,
        FAILED_TO_ACCT_VESTING,
        FAILED_CONTRACT_PAUSED,
        FAILED_CONTRACT_CLOSED,
        FAILED_NIL_VALUE
    }




    function check(address _from, address _to, uint256 _amount)  external view returns (checkReasonCode reason) {
            

            return checkReasonCode.OK;

    }





    function checkConfiscationAllowed(address _from)  external view returns (checkReasonCode reason) {
            

            return checkReasonCode.OK;

    }



} /* end of DonrChecker contract */


pragma solidity ^0.4.24;

/**
 * 
 * Donr LEDGER Smart Contract
 * 
 */



contract DonrLedger { 


  
    /**
     * Modifiers
     * 
     */
    modifier onlySuperUser {
        if (msg.sender != superUser) revert();
        _;
    }
    
    
    modifier onlyTreasurer {
        if (msg.sender != treasurer) revert();
        _;
    }


    modifier onlyAdmin {
        if (msg.sender != admin ) revert();
        _;
    }

     
    modifier paused {
        if (!contractPaused) revert();
        _;
    }
    
    modifier notPaused {
        if (contractPaused) revert();
        _;
    }
    
    
    modifier mintingIsAllowed {
        if (mintingFinished) revert();
        
        _;
    }

    modifier canBurn {
        require(burningAllowed);
        
        _;
    }


    /**
     * 
     * DATA
     * 
     */


    /* checker contract */

    DonrChecker checkerContract;
    
    


    // contract state 
    bool public contractPaused;
    address public checkerContractAddress;
    
    // account addresses
    // reserved token holder accounts
    address public developerAccount;        
    address public teamAccount;
    address public foundationAccount;
    address public aneAccount;
    address public reserveAccount;
    // admin accounts
    address public superUser;        
    address public treasurer;                
    address public admin;

    // Public variables of the contract
    // Public variables of the coinToken
    string public constant standard = "Token 0.1";
    string public  name;
    string public  symbol;
    uint8 public  decimals;
    //uint256 public totalSupply;
    uint256 public totalTokensInCirculation; 
    uint256 public initialSupply; // 0
    uint256 public totalMinted;
    uint256 public cap;
    
    uint256 public totalSupply_;
    



    bool mintingFinished;
    bool burningAllowed;


    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;



     /**
     * 
     * EVENTS 
     * 
     */   

    event ContractPaused();
    event ContractUnpaused();
    event NewCheckerContractAddress (address newCheckerContract);

    event Burn(uint256 numberBurnt);
    event Confiscated(address indexed acct, uint256 numberConfiscated);

    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    

    // ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event TokenSupply(uint256 totalTokenSupply, uint256 totalTokenInCirculation );

    event NewTreasurerAccount(address newTreasurer);
    event NewSuperUserAccount(address superUser);
    event NewAdminAccount(address newAdmin);



    /**
    
    
     */




    /**
     * @dev Function to mint tokens
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     * 79% of  minted coins go to Treasurer
     * 21% of minted coins go to reserved accounts
     */
    //function mint(  uint256 _amount  )    public    onlyTreasurer  notPaused returns (bool)
    function mint(  uint256 _amount  )    public    onlyTreasurer returns (bool)
    {
        address _to;
        _to = treasurer; 
        uint256 _totalMinted;
        uint256 _onePercent;
        uint256 _treasurerAmount;
        uint256 _developerAmount;        
        uint256 _reserveAmount;

    require(mintingFinished != true );
    require(contractPaused != true );
        require(_amount <= cap);
        
    _totalMinted = totalMinted + _amount;
        require(_totalMinted <= cap);



        totalMinted += _amount;
        totalSupply_ += _amount;

        emit Mint(address(0), _amount);
        _onePercent = _amount/100;

        /* mint sends 79% of tokens to Treasurer */

        _treasurerAmount = _onePercent * 79;
        

        /* 5% to Developer */
        _developerAmount = _onePercent * 5;
       

        /* 16% to reserve */
        _reserveAmount = _onePercent * 16;


        balances[treasurer] += _treasurerAmount;
        emit Transfer(address(0), treasurer, _amount);

        balances[developerAccount] += _developerAmount;
        emit Transfer(address(0), developerAccount, _developerAmount);

        balances[reserveAccount] += _reserveAmount;
        emit Transfer(address(0), reserveAccount, _reserveAmount);

        _setTotalTokensInCirculation ();


        return true;
    }



    /**
     * @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyTreasurer  notPaused returns (bool) 
    {
        mintingFinished = true;
        emit MintFinished();
        return true;
    }



    /**
     * @dev Function to burn tokens
     * @return True if the operation was successful
     * Only treasurer can burn, and only the treasures own tokens
     */

    function burn(uint256 _amountToBurn)public onlyTreasurer canBurn  notPaused returns (bool) 
    {
        require( _amountToBurn <=  balances[treasurer]);

        balances[treasurer] -= _amountToBurn;

        totalSupply_ -= _amountToBurn;

        _setTotalTokensInCirculation ();

        emit Burn(_amountToBurn);
        return true;
    }

    /**
     * @dev Function to confiscate tokens
     * @return True if the operation was successful
     * Only treasurer can confiscate tokens
     */

    function confiscate(uint256 _amountToConfiscate, address _from) public onlyTreasurer notPaused returns (bool) 
    {
        require( _amountToConfiscate <=  balances[_from]);
        
        if ( checkerContract.checkConfiscationAllowed(_from) != DonrChecker.checkReasonCode.OK) revert();
    
        balances[_from] -= _amountToConfiscate;
        balances[treasurer] += _amountToConfiscate;
    
        _setTotalTokensInCirculation ();
    
        emit Confiscated(_from, _amountToConfiscate);
        emit Transfer(_from, treasurer, _amountToConfiscate);
    
        return true;
    }


    // Record total tokens in circulation

    function _setTotalTokensInCirculation () internal {
        totalTokensInCirculation = totalSupply_ - balances[treasurer];
        emit TokenSupply(totalSupply_, totalTokensInCirculation );
    }

    /**
     * function treasurerTransfer allows the Treasurer to transfer token balances to any account with out any checks 
     * 
     */
    function treasurerTransfer(address _to, uint256 _value) public onlyTreasurer notPaused returns (bool) {
        require(_value <= balances[treasurer]);
        balances[_to] += _value;
        balances[treasurer] -= _value;

        emit Transfer( treasurer, _to, _value);
        _setTotalTokensInCirculation ();



    }


    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance( address _owner, address _spender  )    public    view    returns (uint256)     {
        return allowed[_owner][_spender];
    }

    /**
     * @dev Transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value) public notPaused returns (bool) {
        require(_value <= balances[msg.sender]);
        require(_to != address(0));

        require (checkerContract.check(msg.sender, _to, _value) == DonrChecker.checkReasonCode.OK);


        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) public notPaused returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(     address _from,    address _to,    uint256 _value  )    public  notPaused  returns (bool)  {
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        require(_to != address(0));

        require (checkerContract.check(_from, _to, _value) == DonrChecker.checkReasonCode.OK);

        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
    function increaseApproval(    address _spender,    uint256 _addedValue  )    public  notPaused  returns (bool)
    {
        allowed[msg.sender][_spender] += _addedValue;
        
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(    address _spender,    uint256 _subtractedValue  )    public   notPaused returns (bool)  {
        uint256 oldValue = allowed[msg.sender][_spender];

        if (_subtractedValue >= oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] -= _subtractedValue;
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    
    /**
     * 
     * Contract admin functions
     * 
     */

    // super user functions
    // change super user
    function superUserTransferSuperUser(address _superUser) external onlySuperUser {
        superUser = _superUser;
        emit NewSuperUserAccount(_superUser);
    }  

    //  Change contract management account - also transafers treasurer balance
    function superUserTransferTreasurership(address _newTreasurer) external  onlySuperUser {
        uint256 _xferAmount;
        
        _xferAmount = balances[treasurer];
        
        balances[_newTreasurer] += _xferAmount;

        balances[treasurer] = 0;
        treasurer = _newTreasurer;
        // record transfer
        emit NewTreasurerAccount(_newTreasurer);
        emit Transfer(treasurer, _newTreasurer, balances[_newTreasurer]);
    }  

    // change Foundation accounts, this function transfers balances of tokens from old to new accounts
    function superUserResetContractAccounts(address _NewFoundationAccount, address _newDeveloperAccount, address _NewReserveAccount)  external onlySuperUser {
        uint256 _xferAmount;
        if (_NewFoundationAccount != 0) {
            _xferAmount = balances[foundationAccount];
            balances[_NewFoundationAccount] += _xferAmount;
            balances[foundationAccount] = 0;        
            foundationAccount = _NewFoundationAccount;
            // record transfer
            emit Transfer(foundationAccount, _NewFoundationAccount, _xferAmount);            
        }
        if (_newDeveloperAccount != 0) {
            _xferAmount = balances[developerAccount];
            balances[_newDeveloperAccount] += _xferAmount;
            balances[developerAccount] = 0;
            developerAccount = _newDeveloperAccount;
            // record transfer
            emit Transfer(developerAccount, _NewReserveAccount, _xferAmount);
        }
        if (_NewReserveAccount != 0) {
            _xferAmount = balances[reserveAccount];
            balances[_NewReserveAccount] += _xferAmount;
            balances[reserveAccount] = 0;
            reserveAccount = _NewReserveAccount;
            // record transfer
            emit Transfer(reserveAccount, _NewReserveAccount, _xferAmount);
        }
    }




    // Treasurer functions 

    // change admin account
    function treasurerChangeAdminAccount(address _newAdmin ) external  onlyTreasurer {

        admin = _newAdmin;
        emit NewAdminAccount(_newAdmin);

    }  




    // Contract State functions



    function pauseContract ()  external onlyTreasurer   returns (bool success){

        contractPaused = true;
        // log change of state
        emit ContractPaused();
        return true;
    }
    function unPauseContract () external  onlyTreasurer   returns (bool success){

        contractPaused = false;
        // log change of state
        emit ContractUnpaused();
        return true;
    }
    /**
    change checkerContract address
     */

    function changeCheckerContractAddress(address _checkerContract) public onlySuperUser paused {
                
                checkerContractAddress = _checkerContract;
                
                checkerContract = DonrChecker(checkerContractAddress);
                emit NewCheckerContractAddress (checkerContractAddress);

    }

    /**
        Constructor
    */

    constructor ( address _reserveAccount, 
        address _developerAccount,    
        address _foundationAccount, 
        address _checkerContract,
        string _tokenName,
        string _tokenSymbol ) public        {
   
   
        initialSupply = 0; // 
        cap = 100000000000000000; // 10 ** 17
        totalMinted = 0;
        totalSupply_ = 0; 
        decimals = 8;
        // set up superUers, admin and treasurer accounts
        superUser = msg.sender;
        treasurer = msg.sender;
        admin = msg.sender;
        
        checkerContractAddress = _checkerContract;

        
        // make sure treasurer is not team or fees or Foundation
        if (msg.sender == _reserveAccount) revert();
        if (msg.sender == _developerAccount) revert();
        if (msg.sender == _foundationAccount) revert();

    


        
        // set up beniciary addresses
        reserveAccount = _reserveAccount;
        developerAccount = _developerAccount;
        foundationAccount = _foundationAccount;
        // set up token parameters

        name = _tokenName;                      
        symbol = _tokenSymbol;                  
        decimals = 8;                            
        


        // Contract not paused, minting allowed, burning allowed
        contractPaused = false; 
        mintingFinished = false;
        burningAllowed = true;

        emit ContractUnpaused();
        

        
    
        
        // Set  total supply
        // Update total supply        
        _setTotalTokensInCirculation();

        /* set up checker contract */
 
        checkerContract = DonrChecker(checkerContractAddress);

    } /* end of constructor */









} /* End of DonrLedger contract*/
