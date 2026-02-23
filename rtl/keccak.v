// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// Note: this is keccak-p, fully unrolled
// (but not useful for sha3...)

module keccak #(
	parameter b      = 1600,
	parameter w      = 64,
	parameter l      = 6,
	parameter nr     = 24,
	parameter regmod = 3
) (
	input wire clk,

	input  wire         s_valid,
	output wire         s_ready,
	input  wire [b-1:0] s_data,
	output wire         m_valid,
	input  wire         m_ready,
	output wire [b-1:0] m_data
);

genvar gi;

wire [nr:0]  i_valid;
wire [nr:0]  i_ready;
wire [b-1:0] i_data [0:nr];

assign i_valid[0] = s_valid;
assign i_data[0] = s_data;
assign s_ready = i_ready[0];

generate for (gi = 0; gi < nr; gi = gi + 1) begin

	localparam registered = (gi % regmod) == regmod-1;

	keccak_stage #(
		.b          (b),
		.ir_max     (nr),
		.registered (registered)
	) keccak_stage_inst (
		.clk (clk),

		.s_valid (i_valid [gi]),
		.s_ready (i_ready [gi]),
		.s_data  (i_data  [gi]),
		.s_ir    (12 + 2*l - nr + gi),
		.m_valid (i_valid [gi+1]),
		.m_ready (i_ready [gi+1]),
		.m_data  (i_data  [gi+1])
	);

end endgenerate

assign m_valid = i_valid[nr];
assign m_data = i_data[nr];
assign i_ready[nr] = m_ready;

endmodule
