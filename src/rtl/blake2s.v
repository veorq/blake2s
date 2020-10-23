//======================================================================
//
// blake2s.v
// --------
// Top level wrapper for the blake2s hash function core providing
// a simple memory like interface with 32 bit data access.
//
//
// Author: Joachim Strömbergson// Copyright (c) 2018, Assured AB
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module blake2s(
               input wire           clk,
               input wire           reset_n,

               input wire           cs,
               input wire           we,

               input wire  [7 : 0]  address,
               input wire  [31 : 0] write_data,
               output wire [31 : 0] read_data
              );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam ADDR_NAME0       = 8'h00;
  localparam ADDR_NAME1       = 8'h01;
  localparam ADDR_VERSION     = 8'h02;

  localparam ADDR_CTRL        = 8'h08;
  localparam CTRL_INIT_BIT    = 0;
  localparam CTRL_NEXT_BIT    = 1;
  localparam CTRL_FINISH_BIT  = 2;

  localparam ADDR_STATUS      = 8'h09;
  localparam STATUS_READY_BIT = 0;

  localparam ADDR_BLOCKLEN    = 8'h0a;

  localparam ADDR_BLOCK_W00   = 8'h10;
  localparam ADDR_BLOCK_W15   = 8'h1f;

  localparam ADDR_DIGEST0     = 8'h20;
  localparam ADDR_DIGEST7     = 8'h27;


  localparam CORE_NAME0   = 32'h626c616b; // "blak"
  localparam CORE_NAME1   = 32'h65327320; // "e2s "
  localparam CORE_VERSION = 32'h302e3230; // "0.20"


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg          init_reg;
  reg          init_new;
  reg          next_reg;
  reg          next_new;
  reg          finish_reg;
  reg          finish_new;
  reg [5 : 0]  blocklen_reg;
  reg          blocklen_we;

  reg [31 : 0] block_mem [0 : 15];
  reg          block_mem_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  wire           core_ready;
  wire [511 : 0] core_block;
  wire [255 : 0] core_digest;

  reg [31 : 0]   tmp_read_data;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign core_block = {block_mem[00], block_mem[01], block_mem[02], block_mem[03],
                       block_mem[04], block_mem[05], block_mem[06], block_mem[07],
                       block_mem[08], block_mem[09], block_mem[10], block_mem[11],
                       block_mem[12], block_mem[13], block_mem[14], block_mem[15]};

  assign read_data = tmp_read_data;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  blake2s_core core(
                    .clk(clk),
                    .reset_n(reset_n),

                    .init(init_reg),
                    .next(next_reg),
                    .finish(finish_reg),

                    .block(core_block),
                    .blocklen(blocklen_reg),

                    .digest(core_digest),
                    .ready(core_ready)
                   );


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      integer i;

      if (!reset_n)
        begin
          for (i = 0 ; i < 16 ; i = i + 1)
            block_mem[i] <= 32'h0;

          init_reg     <= 1'h0;
          next_reg     <= 1'h0;
          finish_reg   <= 1'h0;
          blocklen_reg <= 6'h0;
        end
      else
        begin
          init_reg   <= init_new;
          next_reg   <= next_new;
          finish_reg <= finish_new;

          if (blocklen_we)
            blocklen_reg <= write_data[5 : 0];

          if (block_mem_we)
            block_mem[address[3 : 0]] <= write_data;
        end
    end // reg_update


  //----------------------------------------------------------------
  // api
  // The interface command decoding logic.
  //----------------------------------------------------------------
  always @*
    begin : api
      init_new      = 1'h0;
      next_new      = 1'h0;
      finish_new    = 1'h0;
      block_mem_we  = 1'h0;
      blocklen_we   = 1'h0;
      tmp_read_data = 32'h0;

      if (cs)
        begin
          if (we)
            begin
              if (address == ADDR_CTRL)
                begin
                  init_new   = write_data[CTRL_INIT_BIT];
                  next_new   = write_data[CTRL_NEXT_BIT];
                  finish_new = write_data[CTRL_FINISH_BIT];
                end

              if (address == ADDR_BLOCKLEN)
                blocklen_we = 1;

              if ((address >= ADDR_BLOCK_W00) && (address <= ADDR_BLOCK_W15))
                block_mem_we = 1;
            end // if (we)

          else
            begin
              if (address == ADDR_NAME0)
                tmp_read_data = CORE_NAME0;

              if (address == ADDR_NAME1)
                tmp_read_data = CORE_NAME1;

              if (address == ADDR_VERSION)
                  tmp_read_data = CORE_VERSION;

              if (address == ADDR_STATUS)
                tmp_read_data = {31'h0, core_ready};

              if ((address >= ADDR_DIGEST0) && (address <= ADDR_DIGEST7))
                tmp_read_data = core_digest[(3 - (address - ADDR_DIGEST0)) * 32 +: 32];
            end
        end
    end // api
endmodule // blake2s

//======================================================================
// EOF blake2s.v
//======================================================================
