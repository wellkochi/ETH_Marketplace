pragma solidity ^0.4.23;

contract Marketplace {
  address owner;
  /// TODO: make admins private
  uint globalStoreId = 0;
  // uint256
  uint public globalUnit = 1 ether;
  // TODO: make globalLockBalances private. public during beta for testing
  bool public globalLockBalances = false;
  /// TODO: make storeId private 
  mapping (address => bool) public admins;
  mapping (address => StoreOwner) public storeOwners;
  mapping (uint => Store) public stores;

  constructor() {
    owner = msg.sender;
    admins[owner] = true;
  }
  
  // TODO: do you need store ownder address in StoreOwner struct? Already in mapping 
  struct StoreOwner {
    string name;
    // TODO: bit restriction on balance?
    uint balance;
    OwnerState state;
    // TODO: cant return dynamic array so how will store owners how all the stores they own? Emit events.
    uint[] storeIdsOwned;
  }
  
  
  enum OwnerState {Deactivated, Approved}
  enum StoreState {Inactive, Active}

  struct Store {
    uint storeId;
    string name;
    address storeOwner;
    StoreState state;
    uint balance;
    mapping (uint => Product) products;
    uint nextProductSku;
  }
  struct Product {
    uint sku;
    string name;
    uint price;
    string description;
    uint inventory;
    bool active;
    // TODO: add image via string and IPFS?
  }
  
  /// modifiers for authorized access control
  modifier onlyAdmin () {
    require (admins[msg.sender] == true, "You are not an admin.");
    _;
  }
  modifier onlyStoreOwners() {
    require (storeOwners[msg.sender].state == OwnerState.Approved, "You are not a registered store owner.");
    _;
  }
  modifier onlyOwnerOfStore(uint selectedStoreId) {
    require (msg.sender == stores[selectedStoreId].storeOwner, "You do not own the store.");
    _;
  }
  
  /// Events
  event AddedNewStoreOwner (address _address);
  event AddProduct (uint skuAdded);
  event RemoveProduct (uint skuRemoved);
  event StoreIdOwned (uint storeIdOwned);
  event StoreOwnerName (string storeOwnerName);
  event StoreInfo (uint storeId, string name, address storeOwner, StoreState state, uint balance, uint nextProductSku);
  event ProductInfo (uint sku, string name, uint price, string description, uint inventory, bool active);
  event AmountRequired (uint amountRequired);
  event WithdrewFunds (uint fundsWithdrawn);
  event EventIsAdmin (bool isAdmin);
  event EventIsStoreOwner (OwnerState _ownerState);
  
  function giveFreeMoney() public payable returns (bool success) {
    stores[0].balance += msg.value;
    return true;
  }

  function addStoreOwner(address _address, string _name) 
    onlyAdmin() 
    returns (address newStoreOwner) 
  {
    storeOwners[_address] = StoreOwner({name: _name, balance: 0, state: OwnerState.Approved, storeIdsOwned: new uint[](0)});
    emit AddedNewStoreOwner(_address);
    return (_address);
  }
  
  function addStore(string storeName) 
    public 
    onlyStoreOwners() 
    returns (string newStoreName, address storeOwner) 
    {
      Store memory newStore = Store({
        storeId: globalStoreId,
        name: storeName,
        storeOwner: msg.sender,
        state: StoreState.Active,
        nextProductSku: 0,
        balance: 0
      });
    // record the new Store in stores mapping and storeOwners struct 
    stores[globalStoreId] = newStore;
    // TODO: check globalStoreId array
    storeOwners[msg.sender].storeIdsOwned.push(globalStoreId);
    require(globalStoreId + 1 > globalStoreId, "globalStoreId has reached its limit");
    globalStoreId++;
    // check for storeId over integer 
    return (stores[globalStoreId - 1].name, msg.sender);
  }
  
  function addProduct(uint storeId, string name, uint price, string description, uint inventory) 
  onlyOwnerOfStore(storeId) returns (bool success) {
    uint nextSku = stores[storeId].nextProductSku;
    // TODO: Add SafeMath library
    uint productPrice = price * globalUnit;
    Product memory newProduct = Product({
      sku: nextSku,
      name: name,
      price: productPrice,
      description: description,
      inventory: inventory,
      active: true
    });
    stores[storeId].products[nextSku] = newProduct;
    // Prevent integer overflow.
    // TODO: implement admin function or delegate call to expand product offering if over limit 
    require(stores[storeId].nextProductSku + 1 > stores[storeId].nextProductSku, "You have reached the product limit.");
    stores[storeId].nextProductSku++;
    return true;
  }
  
  function removeProduct(uint storeId, uint sku)
  onlyOwnerOfStore(storeId) returns (bool success) {
    require(stores[storeId].products[sku].active == true, "You do not have a product with that SKU.");
    delete stores[storeId].products[sku];
    emit RemoveProduct(sku);
    return true;
  }
  
  function buyProduct(uint storeId, uint sku, uint quantity) payable returns (bool success) {
    // TODO: think about if we want to only accept exact change or accept more and refund extra 
    uint price = stores[storeId].products[sku].price;
    // TODO: integrate SafeMath library
    uint requiredAmount = price * quantity;
    emit AmountRequired(requiredAmount);
    require(msg.value == requiredAmount, "You need to send exact amount required.");
    require(stores[storeId].products[sku].inventory > 0, "The request product has no more inventory.");
    stores[storeId].products[sku].inventory = stores[storeId].products[sku].inventory - quantity;
    // TODO: check for integer overflow
    require(stores[storeId].balance + msg.value > stores[storeId].balance, "You have reached the max balance limit.");
    stores[storeId].balance += msg.value;
    return true;
  }
  
  // TODO: consider allowing owners to withdraw partial store balances
  function withdrawFunds(uint storeId) onlyOwnerOfStore(storeId) payable returns (bool success) {
    // Note: Implemented mutex security pattern
    require(!globalLockBalances, "Another transfer is in process, please try again later.");
    globalLockBalances = true;
    (msg.sender).transfer(stores[storeId].balance);
    emit WithdrewFunds(stores[storeId].balance);
    stores[storeId].balance = 0;
    globalLockBalances = false;
    return true;
  }
  
  /// Fetches for testing purposes
  // TODO: limit to only store owner
  function fetchAllProductInfo(uint storeId) {
    for (uint i = 0; i < stores[storeId].nextProductSku; i++) {
      emit ProductInfo(
        stores[storeId].products[i].sku,
        stores[storeId].products[i].name,
        stores[storeId].products[i].price,
        stores[storeId].products[i].description,
        stores[storeId].products[i].inventory,
        stores[storeId].products[i].active
      );
    }
  }
  
  function fetchStoreInfo(uint storeId) public view returns (
    uint selectedStoreId,
    string name,
    address storeOwner,
    StoreState state,
    uint balance,
    uint nextProductSku
  ) {
    return (
      stores[storeId].storeId,
      stores[storeId].name,
      stores[storeId].storeOwner,
      stores[storeId].state,
      stores[storeId].balance,
      stores[storeId].nextProductSku
    );
  }
  
  function fetchAllStoreInfo() public returns (bool success) {
    for(uint i = 0; i < globalStoreId; i++) {
      emit StoreInfo(
        stores[i].storeId,
        stores[i].name,
        stores[i].storeOwner,
        stores[i].state,
        stores[i].balance,
        stores[i].nextProductSku);
    }
    return true;
  }

  function fetchStoreOwnerInfo(address _address) public returns (string name) {
    // cannot return dynamic array so emitting events instead to show owners all storeIds owned
    emit StoreOwnerName(storeOwners[_address].name);

    for (uint i = 0; i < storeOwners[_address].storeIdsOwned.length; i++) {
      emit StoreIdOwned(storeOwners[_address].storeIdsOwned[i]);
    }
    return (storeOwners[_address].name);
  }
  
  function fetchContractBalance() public returns (uint balance) {
    return this.balance;
  }
  
  function fetchContractOwner() public view returns (address contractOwner) {
    return owner;
  }


  function identifyUserRole() public returns (bool success) {
    emit EventIsAdmin(admins[msg.sender]);
    emit EventIsStoreOwner(storeOwners[msg.sender].state);
    return true;
  }
  
  function isStoreOwner() public returns (OwnerState _storeOwnerState) {
    return storeOwners[msg.sender].state;
  }
}