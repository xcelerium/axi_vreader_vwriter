// Copyright 2020-2022 Xcelerium, Inc.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Hamza Khan <hamza@xcelerium.com>

`ifndef __LIB_PKG_SVH__
`define __LIB_PKG_SVH__

package lib_pkg;

  // -------------------------------
  // byte shifter function
  // -------------------------------
  function automatic [128-1:0][7:0] byte_shifter_i256_o128 (logic left_shift, int shift_amount, logic [128+128-1:0][7:0] in_bytes);
    if (left_shift)
      for (int i=0; i<(128+128); i++)
        byte_shifter_i256_o128[i] = (i < shift_amount) ? 8'b0 : in_bytes[i-shift_amount];
    else
      for (int i=0; i<128; i++)
        byte_shifter_i256_o128[i] = in_bytes[i+shift_amount];
  endfunction

  function automatic [256-1:0][7:0] byte_shifter_i256_o256 (logic left_shift, int shift_amount, logic [128+128-1:0][7:0] in_bytes);
    if (left_shift)
      for (int i=0; i<(128+128); i++)
        byte_shifter_i256_o256[i] = (i < shift_amount) ? 8'b0 : in_bytes[i-shift_amount];
    else
      for (int i=0; i<(128+128); i++)
        byte_shifter_i256_o256[i] = (i+shift_amount) >= 256 ? '0 : in_bytes[i+shift_amount];
  endfunction

  // -------------------------------
  // Modulo Increment
  // -------------------------------
  //           mod_inc(a, MOD_MAX) 
  `define LIB__MOD_INC(a, MOD_MAX) (a == MOD_MAX) ? '0 : a + 1'b1

  // -------------------------------
  // flop
  // -------------------------------
  // flop           clk, rstn, enable, rst_val, inp, out, bypass
  `define LIB__flop(CLK, RSTN, ENABLE, RST_VAL, INP, OUT, BYPASS) \
    if (BYPASS == 1)           \
      assign OUT = INP;        \
    else begin                 \
      always_ff @(posedge CLK or negedge RSTN) \
        if (!RSTN)             \
          OUT <= RST_VAL;      \
        else if (ENABLE)       \
          OUT <= INP;          \
    end  

  // -------------------------------
  // counter
  // -------------------------------
  // counter           clk, rstn, enable, count, max
  `define LIB__counter(CLK, RSTN, ENABLE, COUNT, MAX_COUNT)                              \
  // flop      clk, rstn, enable, rst_val, inp,                            out,   bypass \
    `LIB__flop(CLK, RSTN, ENABLE, '0,     `LIB__MOD_INC(COUNT, MAX_COUNT), COUNT, '0)

  // -------------------------------
  // 1-stage pipe
  // -------------------------------
  // 1 entry pipe     (clk, rstn, in_val, in_d, in_rdy, out_val, out_d, out_rdy, bypass)
  `define LIB__pipe_1(CLK, RSTN, IN_VAL, IN_D, IN_RDY, OUT_VAL, OUT_D, OUT_RDY, BYPASS) \
    // generate                                                 \
      if (BYPASS == 1) begin \
        assign OUT_VAL = IN_VAL;                                \
        assign IN_RDY  = OUT_RDY;                               \
        assign OUT_D   = IN_D;                                  \
      end \
      else begin \
        // control                                              \
        always_ff @(posedge CLK or negedge RSTN) begin          \
          if (!RSTN)                                            \
            OUT_VAL <= '0;                                      \
          else if (IN_VAL)                                      \
            OUT_VAL <= 1'b1;                                    \
          else if (OUT_RDY)                                     \
            OUT_VAL <= 1'b0;                                    \
        end                                                     \
        assign IN_RDY = OUT_RDY | !OUT_VAL;                     \
        // data                                                 \
        always_ff @(posedge CLK) begin                          \
          if (IN_VAL && IN_RDY)                                 \
            OUT_D <= IN_D;                                      \
        end                                                     \
      end \
    // endgenerate  

endpackage

// -------------------------------
// n-stage FIFO 
// -------------------------------
//      n entry pipe     (num_entry, clk, rstn, in_val, in_d, in_rdy, out_val, out_d, out_rdy, bypass)
module lib_pipe_n #(
    parameter NUM_ENTRY = 4,
    parameter NUM_BITS  = 32,
    parameter BYPASS    = 0
  )
  (
    input  logic clk,
    input  logic rstn,
    input  logic in_val,
    input  logic [NUM_BITS-1:0] in_d,
    output logic in_rdy,
    output logic out_val,
    output logic [NUM_BITS-1:0] out_d,
    input  logic out_rdy
  );

  generate                                                                            
    if (BYPASS == 1 || NUM_ENTRY == 0) begin : n_stage_bypass
      assign out_val = in_val;                                                            
      assign in_rdy  = out_rdy;                                                           
      assign out_d   = in_d;                                                              
    end : n_stage_bypass
    else begin : n_stage
      logic [0:NUM_ENTRY-1][$bits(in_d)-1:0] fifo;
      logic [$clog2(NUM_ENTRY)-1:0]          wptr;
      logic [$clog2(NUM_ENTRY)-1:0]          rptr;
      logic                                  c_wptr;
      logic                                  c_rptr;
      // control                                                                          
      always_ff @(posedge clk or negedge rstn) begin                                                      
        if (!rstn) begin                                                                  
          wptr   <= '0;                                                 
          rptr   <= '0;                                                 
          c_wptr <= '0;                                                 
          c_rptr <= '0;                                                 
        end                                                                               
        else begin                                                                        
          if (in_val && in_rdy) begin                                                     
            wptr <= `LIB__MOD_INC(wptr, NUM_ENTRY-1); 
            if (wptr == NUM_ENTRY-1)                                    
              c_wptr <= ~c_wptr;                       
          end                                                                             
          if (out_val && out_rdy) begin                                                   
            rptr <= `LIB__MOD_INC(rptr, NUM_ENTRY-1); 
            if (rptr == NUM_ENTRY-1)                                    
              c_rptr <= ~c_rptr;                       
          end                                                                             
        end                                                                               
      end                                                                                 
      assign out_val = {c_wptr,wptr} != {c_rptr,rptr};                 
      assign in_rdy  = ~((wptr == rptr) & (c_wptr != c_rptr));         
      // data                                                                             
      always_ff @(posedge clk) begin                                                      
        if (in_val && in_rdy)                                                             
          fifo[wptr] <= in_d;                         
      end                                                                                 
      assign out_d = fifo[rptr];                      
    end : n_stage
  endgenerate  

endmodule
//
// -------------------------------
// Round-robin arbiter
// -------------------------------
//      rr_arb     (clk, rstn, enable, req, gnt)
module lib_rr_arb #(
    parameter NUM = 4
  )
  (
    input  logic clk,
    input  logic rstn,
    input  logic enable,
    input  logic [NUM-1:0] req,
    output logic [NUM-1:0] gnt
  );

  logic [$bits(req)-1:0] rr_arb_mask;
  logic [$bits(req)-1:0] rr_arb_req0;
  logic [$bits(req)-1:0] rr_arb_req1;
  logic [$bits(req)-1:0] rr_arb_mask0;
  logic [$bits(req)-1:0] rr_arb_mask1;
  logic [$bits(req)-1:0] rr_arb_gnt0;
  logic [$bits(req)-1:0] rr_arb_gnt1;
  // priority mask                                                                         
  always_ff @(posedge clk or negedge rstn)                                                                 
    if (!rstn)                                                                             
      rr_arb_mask <= '0;                                                        
    else if (enable) begin                                                                 
      if (req != '0)                                                                       
        rr_arb_mask <= (rr_arb_gnt0 == '0) ? rr_arb_mask1 : rr_arb_mask0;  
    end                                                                                    
  assign rr_arb_req0 = enable ? req & ~rr_arb_mask : '0;                           
  assign rr_arb_req1 = enable ? req &  rr_arb_mask : '0;                           
  // arbitration                                                                           
  always_comb begin                                                                        
    rr_arb_gnt0      = '0;                                                      
    rr_arb_gnt1      = '0;                                                      
    rr_arb_mask0     = '0;                                                      
    rr_arb_mask1     = '0;                                                      
    for (int i=0; i<$bits(req); i++) begin                                                 
      if ((rr_arb_req0[i] == 1'b1) && (rr_arb_gnt0 == '0)) begin     
        rr_arb_gnt0  = 1'b1 << i;                                               
        rr_arb_mask0 = rr_arb_mask0 | 1'b1 << i;                     
      end                                                                                  
      if ((rr_arb_req1[i] == 1'b1) && (rr_arb_gnt1 == '0)) begin     
        rr_arb_gnt1  = 1'b1 << i;                                               
        rr_arb_mask1 = rr_arb_mask1 | 1'b1 << i;                     
      end                                                                                  
    end                                                                                    
  end                                                                                      

  assign gnt = (rr_arb_gnt0 == '0) ? rr_arb_gnt1 : rr_arb_gnt0;

endmodule // lib_rr_arb

`endif // __LIB_PKG_SVH__   
