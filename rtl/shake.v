// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// SHAKE128(M, d) = KECCAK[256] (M || 1111, d),  1344  168   2 x 2 x 2 x 3 x 7
// SHAKE256(M, d) = KECCAK[512] (M || 1111, d).  1088  136   2 x 2 x 2 x 17
//       ^                  ^                     ^     ^  
//       d                  c                     r    r/8   prime decomp
//
// dw = r = b - c

module shake #(
	parameter  stages_per_clk = 2,
	parameter  c              = 1024,
	parameter  r              = 1600 - c,
	localparam kw             = r/8,
	parameter  d              = 512
) (
	input wire clk,

	input  wire          s_valid,
	output wire          s_ready,
	input  wire          s_last,
	input  wire [r-1:0]  s_data,
	input  wire [kw-1:0] s_keep,

	output wire         m_valid,
	input  wire         m_ready,
	output wire [d-1:0] m_hash
);

wire         sp_m_valid;
wire         sp_m_ready;
wire         sp_m_last;
wire [r-1:0] sp_m_data;

keccak_pad #(
	.dw    (r),
	.magic (8'h1f)
) keccak_pad_inst (
	.clk (clk),

	.s_valid (s_valid),
	.s_ready (s_ready),
	.s_last  (s_last),
	.s_data  (s_data),
	.s_keep  (s_keep),

	.m_valid (sp_m_valid),
	.m_ready (sp_m_ready),
	.m_last  (sp_m_last),
	.m_data  (sp_m_data)
);

// these are constant for shake
localparam b  = 1600;
localparam nr = 24;

keccak_sponge #(
	.b              (b),
	.nr             (nr),
	.stages_per_clk (stages_per_clk),
	.c              (c),
	.d              (d)
) keccak_sponge_inst (
	.clk (clk),

	.s_valid (sp_m_valid),
	.s_ready (sp_m_ready),
	.s_data  (sp_m_data),
	.s_last  (sp_m_last),

	.m_valid (m_valid),
	.m_ready (m_ready),
	.m_hash  (m_hash)
);

endmodule
