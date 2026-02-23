// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// SHAKE128(M, d) = KECCAK[256] (M || 1111, d),  1344  168   2 x 2 x 2 x 3 x 7
// SHAKE256(M, d) = KECCAK[512] (M || 1111, d).  1088  136   2 x 2 x 2 x 17
//                          ^                     ^     ^  
//                          c                     r    r/8   prime decomp
//
// dw = r = b - c

// Limitations:
// * d <= r

module shake256 #(
	parameter stages_per_clk = 2,
	parameter d              = 512
) (
	input wire clk,

	input  wire            s_valid,
	output wire            s_ready,
	input  wire            s_last,
	input  wire [1088-1:0] s_data,
	input  wire [136-1:0]  s_keep,

	output wire         m_valid,
	input  wire         m_ready,
	output wire [d-1:0] m_hash
);

localparam r = 1088;
localparam c = 512;

shake #(
	.stages_per_clk (stages_per_clk),
	.r              (r),
	.c              (c),
	.d              (d)
) shake_inst (
	.clk (clk),

	.s_valid (s_valid),
	.s_ready (s_ready),
	.s_last  (s_last),
	.s_data  (s_data),
	.s_keep  (s_keep),

	.m_valid (m_valid),
	.m_ready (m_ready),
	.m_hash  (m_hash)
);

endmodule
