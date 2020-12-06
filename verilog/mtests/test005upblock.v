// SPDX-FileCopyrightText: Copyright 2020 Jecel Mattos de Assumpcao Jr
// 
// SPDX-License-Identifier: Apache-2.0 
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     https://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This tests the user_proj_example in Caravel with the version that has
// a single 16x16 yblock attached to the logic analyzer pins.
// This reads a file with test vectors and it applies it to the device under
// test (DUT) and checks that the output is expected. Only the wires and
// outputs of the device are used, not the internal signals. This allows
// these to be regression tests that do not depend on internal changes to
// the DUT.

// this circuit was derived from the one described in
// https://syssec.ethz.ch/content/dam/ethz/special-interest/infk/inst-infsec/system-security-group-dam/education/Digitaltechnik_14/14_Verilog_Testbenches.pdf

`timescale 1ns/1ps
`include "../rtl/defines.v"
`include "../morphle/ycell.v"
`include "../morphle/yblock.v"
`include "../morphle/user_proj_block.v"

module test005upblock;

  reg [51:0] tvout;
  reg [47:0] xtvin;
  

  reg[31:0] vectornum, errors;   // bookkeeping variables
  reg[99:0]  testvectors[10000:0];// array of testvectors/
  reg clk;   // DUT is asynchronous, but the test circuit can't be
  // generate clock
  always     // no sensitivity list, so it always executes
  begin
    clk= 0; #5; clk= 1; #5;// 10ns period
  end

    wire vdda1 = 1'b1;	// User area 1 3.3V supply
    wire vdda2 = 1'b1;	// User area 2 3.3V supply
    wire vssa1 = 1'b0;	// User area 1 analog ground
    wire vssa2 = 1'b0;	// User area 2 analog ground
    wire vccd1 = 1'b1;	// User area 1 1.8V supply
    wire vccd2 = 1'b1;	// User area 2 1.8v supply
    wire vssd1 = 1'b0;	// User area 1 digital ground
    wire vssd2 = 1'b0;	// User area 2 digital ground

    // Wishbone Slave ports (WB MI A)
    wire wb_clk_i = clk;
    wire wb_rst_i = tvout[97];
    wire wbs_stb_i = 1'b0;
    wire wbs_cyc_i = 1'b0;
    wire wbs_we_i = 1'b0;
    wire [3:0] wbs_sel_i = {4{1'b0}};
    wire [31:0] wbs_dat_i = {32{1'b0}};
    wire [31:0] wbs_adr_i = {32{1'b0}};
    wire wbs_ack_o;
    wire [31:0] wbs_dat_o;

    // Logic Analyzer Signals
    wire  [127:0] la_data_in = {{12{1'b0}},tvout,{64{1'b0}}};
    wire [127:0] la_data_out;
    wire  [127:0] la_oen;

    // IOs
    wire  [37:0] io_in = {38{1'b0}};
    wire [37:0] io_out;
    wire [37:0] io_oeb;

  
  user_proj_example  DUT (
    .vdda1(vdda1),	// User area 1 3.3V supply
    .vdda2(vdda2),	// User area 2 3.3V supply
    .vssa1(vssa1),	// User area 1 analog ground
    .vssa2(vssa2),	// User area 2 analog ground
    .vccd1(vccd1),	// User area 1 1.8V supply
    .vccd2(vccd2),	// User area 2 1.8v supply
    .vssd1(vssd1),	// User area 1 digital ground
    .vssd2(vssd2),	// User area 2 digital ground

    // Wishbone Slave ports (WB MI A)
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_cyc_i(wbs_cyc_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_dat_o(wbs_dat_o),

    // Logic Analyzer Signals
    .la_data_in(la_data_in),
    .la_data_out(la_data_out),
    .la_oen(la_oen),

    // IOs
    .io_in(io_in),
    .io_out(io_out),
    .io_oeb(io_oeb)
);
  
  initial
  begin
    $readmemh("test005.tv", testvectors); // Read vectors
    vectornum= 0; errors = 0;  // Initialize 
  end
  
  // apply test vectors on rising edge of clk
  always @(posedge clk)
  begin
    #1; {tvout,xtvin} = testvectors[vectornum][99:0];
    $display("just read vector %d %h %h", vectornum, tvout, xtvin);
    if (xtvin === 48'bx)
    begin
      $display("%d tests completed with %d errors", vectornum-1, errors);
      $finish;   // End simulation
    end
  end
  
  wire reset = la_data_in[113];
  
  // check results on falling edge of clk
  always @(negedge clk)
  begin
    $display("testing vector %d %h %h", vectornum, tvout, xtvin);
    if ((!tvout[51] & la_data_out[47:32] !== xtvin[47:32]) |
        (!tvout[50] & la_data_out[31:0] !== xtvin[31:0])) 
    begin
      $display("Error: sent = %b %b %h %h",
               la_data_in[113], la_data_in[112], la_data_in[111:96], la_data_in[95:64]);
      $display("  outputs = %h %h (%h %h exp)",
               la_data_out[47:32], la_data_out[31:0],
               xtvin[47:32], xtvin[31:0]);
      errors = errors + 1;
    end
      $display(" u0  = %b %b", DUT.blk.vs[0], DUT.blk.vb[0]);
      $display(" u1  = %b %b", DUT.blk.vs[1], DUT.blk.vb[1]);
      $display(" u2  = %b %b", DUT.blk.vs[2], DUT.blk.vb[2]);
      $display(" u3  = %b %b", DUT.blk.vs[3], DUT.blk.vb[3]);
      $display(" l8  = %b %b", DUT.blk.hs[8], DUT.blk.hb[8]);
      $display(" l9  = %b %b", DUT.blk.hs[9], DUT.blk.hb[9]);
      $display(" l10 = %b %b", DUT.blk.hs[10], DUT.blk.hb[10]);
      $display(" l11 = %b %b", DUT.blk.hs[11], DUT.blk.hb[11]);
      $display(" l12 = %b %b", DUT.blk.hs[12], DUT.blk.hb[12]);
      $display(" l13 = %b %b", DUT.blk.hs[13], DUT.blk.hb[13]);
      $display(" l14 = %b %b", DUT.blk.hs[14], DUT.blk.hb[14]);
      $display(" l15 = %b %b", DUT.blk.hs[15], DUT.blk.hb[15]);
      $display(" r15 = %b %b", DUT.blk.hs[16], DUT.blk.hb[16]);
      $display(" ve0 = %b", DUT.blk.ve[0]);
      $display(" ve1 = %b", DUT.blk.ve[1]);
      $display(" ve2 = %b", DUT.blk.ve[2]);
      $display(" ve3 = %b", DUT.blk.ve[3]);
      $display(" he8  = %b", DUT.blk.he[8]);
      $display(" he9  = %b", DUT.blk.he[9]);
      $display(" he10 = %b", DUT.blk.he[10]);
      $display(" he11 = %b", DUT.blk.he[11]);
      $display(" he12 = %b", DUT.blk.he[12]);
      $display(" he13 = %b", DUT.blk.he[13]);
      $display(" he14 = %b", DUT.blk.he[14]);
      $display(" he15 = %b", DUT.blk.he[15]);
      $display(" he16 = %b", DUT.blk.he[16]);
      // increment array index and read next testvector
    vectornum= vectornum + 1;
    $display("testing vector %d next", vectornum);
  end
  
endmodule
