// Import the 'token.aleo' program for token A
/// Import the 'token.aleo' program for token B
import token_a.aleo;
import token_b.aleo;

// The 'amm.aleo' program.
program amm.aleo;

// Interface to represent tokens in LP position
interface lp:
    // Token A address
    token_a as address.private; 
    // Token A amount
    token_a_amount as u64.private;
    // Token B address
    token_b as address.private; 
    // Token B amount
    token_b_amount as u64.private;

// Record to represent an addresses' LP position
record lp_position:
    // The LP position owner
    owner as address.private;
    // The Aleo balance
    gates as u64.private;
    // LP Position Information
    position_info as lp.private;

// Interface to represent public total liquidity for a token pair
interface pair_liquidity:
    // Token A address
    token_a as address.public; 
    // Token A amount
    token_a_amount as u64.public;
    // Token B address
    token_b as address.public; 
    // Token B amount
    token_b_amount as u64.public;

// Mapping to represent public liqudiity for a token pair
mapping liquidity:
    // Hash of lp interface for the token pair
    key lp_hash as field.public;
    // lp interface as value to access token amounts 
    value pair_liquidity as pair_liquidity.public;

// AMM functions

// add liquidity 
function add_liquidity:
    // Input the LP address
    input r0 as address.private;
    // Input the desired LP position
    input r1 as lp.private;
    // Input the LP's record for token A
    input r2 as token_a.aleo/token.record;
    // Input the LP's record for token B
    input r3 as token_b.aleo/token.record;


    // Check that position is legitimate
    // 1. Check that tokens ratio's abide by x * y = k
    // Get y / x ratio of desired lp position
    div r1.token_b_amount r1.token_a_amount into r4;

    // Get y / x ratio of current position of pool
    // First need to get the pair_liquidity interface for this LP position by hashing sum of the token addresses
    add r1.token_a r1.token_b into r5;
    hash.ped64 r5 into r6;
    div liquidity[r6].token_b_amount liquidity[r6].token_a_amount into r7;

    // Check that these two ratios are equal
    assert.eq r4 r7;

    // Transfer tokens from lp to the pool
    // Get the address of this swap program
    cast main.aleo into r8 as address;
    // Calling external token program to privately transfer token A's from lp to the pool
    call token_a.aleo/transfer_private r2 r8 r1.token_a_amount into r9 r10;
    // Calling external token program to privately transfer token B's from lp to the pool
    call token_b.aleo/transfer_private r3 r8 r1.token_b_amount into r11 r12;

    // Create a lp_position record for the lp 
    cast r0 0u64 r1 into r13 as lp_position.record;

    // Output the lp's new token A record
    output r10 as token_a.aleo/token.record;
    // Output the lp's new token B record
    output r12 as token_b.aleo/token.record;
    // Output the lp's lp_position Record
    output r13 as lp_position.record; 

    // These vars will be made public in finalize to update the global liquidity for this token pair
    // r5 here is the hash that identifies this token pair
    finalize r6 r1.token_a_amount r1.token_b_amount;

finalize add_liquidity:
    // Input the identifying hash for this token pair
    input r0 as field.public;
    // Input the token A amount
    input r1 as u64.public;
    // Input the token B amount
    input r2 as u64.public;

    // Increment the total token amount for token A and B by the amount provided by the LP
    increment liqudity[r0].token_a_amount by r1;
    increment liqudity[r0].token_b_amount by r2;
    

// swap
// to swap we need to provide the token amounts and then what?? 
// calculate how many tokens they should receive 
function swap:
    // Input the record for the token they want to swap
    input r0 as general_token.record;
    // Input the amount for the token they want to swap
    input r1 as u64.private;
    // Input the address for the token that they want to receive
    input r2 as address.private;

    // Use self.caller to get the address of the swapper

    // Check if swapper has enough of the token they want to swap
    gte r0.amount r1 into r3;
    assert.eq r3 true;

    // Get the pair_liquidity interface for this LP position by hashing sum of the token addresses
    // Sum r0 token address with the address for r1
    // This is currently the owner address and not the token address--how to differentiate between the two?? you only get the address after you deploy so??
    add r0.program_address r2 into r4;
    hash.ped64 r4 into r5;

    // How much of other token to get out

    // If input token is token A
    // Following self.y_quantity - (self.x_quantity * self.y_quantity) / (self.x_quantity + in_quantity)
    // Multiply token A liquidity by token B liquidity
    mul liquidity[r5].token_a_amount liquidity[r5].token_b_amount into r6;
    // Add token A liquidity to the amount of the token to swap
    add liquidity[r5].token_a_amount r1 into r7;
    // Divide r6 by r7
    div r6 r7 into r8;
    // Subtract token B liquidity by r8 to get the amount of token B to output
    // r9 is how much of token B to output 
    sub liquidity[r5].token_b_amount r8 into r9;

    // If input token is token B
    // Following self.x_quantity - (self.x_quantity * self.y_quantity) / (self.y_quantity + in_quantity)
    // Multiply token A liquidity by token B liquidity
    mul liquidity[r5].token_a_amount liquidity[r5].token_b_amount into r10;
    // Add token B liquidity to the amount of the token to swap
    add liquidity[r5].token_b_amount r1 into r11;
    // Divide r6 by r7
    div r10 r11 into r12;
    // Subtract token A liquidity by r8 to get the amount of token B to output
    // r9 is how much of token A to output 
    sub liquidity[r5].token_a_amount r12 into r13;

    // Boolean to see which token is being swapped
    // if true then input token is A 
    // if false then input token is B 
    is.eq r2 liquidity[r5].token_a into r14;

    // Ternary to see which token amount to return stored in r15 
    // If r14 is true then input token is token A and return r9 token amount for token B
    // if r14 is false then input token is token B and return r13 token amount for token A
    ternary r14 r9 r13 into r15;

    // Transfer input token amount to AMM using transfer_private
    // Takes in the sender's record, receiver's address, and the amount to transfer
    // Returns the receiver's record and the sender's changed record
    cast main.aleo into r16 as address;
    // Calling external token program but not sure if this is proper way to get the return variables
    call token.aleo/transfer_private r0 r16 r1 into r17 r18;

    // Transfer output token amount to address
    // Create token record representing the output amount to transfer 
    cast r16 0u64 r15 into r17 as token.aleo/token.record;
    // Call external token program using private_transfer again
    call token.aleo/transfer_private r16 r0 r15 into r19 r20;


    // Return new records for each token for swapper
    output r18 as token.aleo/token.record;
    output r19 as token.aleo/token.record;
    
    // Update the liquidity for this specific pair 
    finalize r5 r1 r15 r14;
    
    // Assert that there exists enough liquidity to swap this token


finalize swap:
    // Input the identifying hash for this token pair
    input r0 as field.public;
    // Input the input token amount
    input r1 as u64.public;
    // Input the output token amount
    input r2 as u64.public;
    // Input the token indicator to see if input token is token A or token B
    input r3 as boolean.public;
    
    // Positive and Negative Amounts for 
    // Ternary operation to see if AMM balance of token A should be increased by token A amount or 0
    // If r3 is true then token A is the input so its liquidity in the pool should increase
    ternary r3 r1 0u64 r4;
    // Ternary operation to see if AMM balance of token A should be decreased by token A amount or 0
    // If r3 is true then token A is the input so its liquidity should not be decreased
    ternary r3 0u64 r1 r5;
    // Ternary operation to see if AMM balance of token B should be increased by token B amount or 0
    // If r3 is false then token B is the input token so its liquidity should be increased
    ternary r3 0u64 r2 r6;
    // Ternary operation to see if AMM balance of token B should be decreased by token B amount or 0
    // If r3 is true then token B is the output token so its liquidity should be decreased
    ternary r3 r2 0u64 r7;

    // Increment the total token amount for token A and B by the amounts determined in the ternary operations above
    increment liqudity[r0].token_a_amount by r4;
    increment liqudity[r0].token_b_amount by r6;

    // Decrement the total token amount for token A and B by the amounts determined in the ternary operations above
    decrement liqudity[r0].token_a_amount by r5;
    decrement liqudity[r0].token_b_amount by r7;




// helper functions

// get pool liquidity

// get pool fee




// Questions:
// is there a way to make liqudiity private?
// could your position be private but the aggregate is public??



// MAIN ISSUE NOW
// how can we differentiate btwn different toe