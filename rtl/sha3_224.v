// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2025 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// SHA3-224(M) = KECCAK[448]  (M || 01, 224)  1152  144   2 x 2 x 2 x 2 x 3 x 3
// SHA3-256(M) = KECCAK[512]  (M || 01, 256)  1088  136   2 x 2 x 2 x 17
// SHA3-384(M) = KECCAK[768]  (M || 01, 384)  832   104   2 x 2 x 2 x 13
// SHA3-512(M) = KECCAK[1024] (M || 01, 512)  576   72    2 x 2 x 2 x 3 x 3

module sha3_224 #(
	parameter stages_per_clk = 2
) (
	input wire clk,

	input  wire            s_valid,
	output wire            s_ready,
	input  wire            s_last,
	input  wire [1152-1:0] s_data,
	input  wire [144-1:0]  s_keep,

	output wire           m_valid,
	input  wire           m_ready,
	output wire [224-1:0] m_hash
);

localparam r = 1152;
localparam c = 448;
localparam d = 224;

sha3 #(
	.stages_per_clk (stages_per_clk),
	.r              (r),
	.c              (c),
	.d              (d)
) sha3_inst (
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
