// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6; //0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoter.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

//unswap router v3 0x65669fe35312947050c450bd5d36e6361f85ec12 sepolia
address constant routerV3 = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant adrSWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant adrWETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant adrDAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant adrUSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant adrcurvePool = 0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B;
contract arbitrage{
    address admin;
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function.");
        _;
    }
    function exactueArbitrage(uint256 amountInUSDC)external onlyAdmin returns(uint256 profit) {
        require(USDC.balanceOf(address(this))>= amountInUSDC,"USDC balanceOf not enough");
        uint256 amountOutWETH;
        uint256 amountOutUSDC;
    // get price from uniswap
        uint256 ethAmountFromUniswap = this.getAmountOutUniswapV3(amountOutUSDC);
        uint256 ethAmountFromCrve = this.getAmountOutCurve(amountInUSDC);
    // get price from curve
        if(ethAmountFromUniswap > ethAmountFromCrve){
            amountOutWETH = this.buyWETHOnUniswap(amountInUSDC);
            amountOutUSDC = this.sellWETHOnCurve(amountOutWETH);
        }else{
            amountOutWETH = this.buyWETHOnCurve(amountInUSDC);
            amountOutUSDC = this.sellWETHOnUniswap(amountOutWETH);

        }
        require(amountOutUSDC>amountInUSDC, "Arbitrage profit <=0");

    //compare

    // buy
        profit = amountOutUSDC - amountInUSDC;
    }

    //func getPrice from uniswap


    IWETH private constant WETH = IWETH(adrWETH);
    IWETH private constant USDC = IWETH(adrUSDC);
    UniswapV3Router private constant uniswapV3Router = UniswapV3Router(routerV3);
    IUniswapV3Factory private constant uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    function depositWETH()external payable {
        WETH.deposit{value:msg.value}();

    }
    
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    )internal returns (uint256 amountOut){

    IERC20(tokenIn).approve(address(uniswapV3Router),amountIn);

    ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
        });

    amountOut = uniswapV3Router.exactInputSingle(params);

    }
    function sellWETHOnUniswap(uint256 amountIn)external onlyAdmin returns(uint256 amountOut){
        require(WETH.balanceOf(address(this))>= amountIn,"WETH balsenceOF not enough");
        amountOut = swapExactInputSingleHop(address(WETH), address(USDC),3000 , amountIn);
    }
    function buyWETHOnUniswap(uint256 amountIn)external onlyAdmin returns(uint256 amountOut){
        require(USDC.balanceOf(address(this))>= amountIn,"USDC balsenceOF not enough");
        amountOut = swapExactInputSingleHop(address(USDC), address(WETH),3000 , amountIn);
    }



    function getAmountOutUniswapV3(uint256 amoutIn)external  view returns (uint256 amoutOut){
        address poolAddress = uniswapV3Factory.getPool(address(USDC),address(WETH),3000);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96)* uint256(sqrtPriceX96) / (1<<192);
        amoutOut = amoutIn * price;
    }


    // curve
    ICryptoPool private constant curvePool = ICryptoPool(0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B);
    function getCoinsFromCurvePool(uint256 index)external view returns(address){
        return curvePool.coins(index);
    }
    function buyWETHOnCurve(uint256 amountIn) external onlyAdmin returns (uint256 amountOut){
        require(USDC.balanceOf(address(this))>= amountIn,"USDC balanceOf not enough");
        IERC20(address(USDC)).approve(address(curvePool),amountIn);
        amountOut = curvePool.exchange(0,2,amountIn,1);
    }
    function sellWETHOnCurve(uint256 amountIn) external onlyAdmin returns (uint256 amountOut){
        require(USDC.balanceOf(address(this))>= amountIn,"WETH balanceOf not enough");
        IERC20(address(WETH)).approve(address(curvePool),amountIn);
        amountOut = curvePool.exchange(2,0,amountIn,1);
    }
    function getAmountOutCurve(uint256 amountIn) external view returns (uint256 amoutOut){
        amoutOut = curvePool.get_dy(0,2,amountIn);

    }
}

interface IWETH is IERC20{
    function deposit()external payable ;
    function withdraw(uint256 amount) external;
}
interface UniswapV3Router is ISwapRouter {
}
interface IUniswapV3Pool{
    function slot0(
  ) external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
}
interface IUniswapV3Factory{
    function getPool(
    address tokenA,
    address tokenB,
    uint24 fee
  ) external view returns (address pool);
}
interface ICryptoPool{
    function balances(uint256) external view returns (uint256);

    function price_oracle(uint256) external view returns (uint256);

    // Some crypto pools only consist of 2 coins, one of which is usd so
    // it can be assumed that the price oracle doesn't need an argument
    // and the price of the oracle refers to the other coin.
    // This function is mutually exclusive with the price_oracle function that takes
    // an argument of the index of the coin, only one will be present on the pool
    function price_oracle() external view returns (uint256);

    function coins(uint256) external view returns (address);
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy)external returns (uint256);
    function get_dy(uint256 i, uint256 j, uint256 amount)external view returns(uint256);

}


