// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// SHA3-224(M) = KECCAK[448]  (M || 01, 224)  1152  144   2 x 2 x 2 x 2 x 3 x 3
// SHA3-256(M) = KECCAK[512]  (M || 01, 256)  1088  136   2 x 2 x 2 x 17
// SHA3-384(M) = KECCAK[768]  (M || 01, 384)  832   104   2 x 2 x 2 x 13
// SHA3-512(M) = KECCAK[1024] (M || 01, 512)  576   72    2 x 2 x 2 x 3 x 3
//       ^               ^               ^     ^     ^
//       d               c               d     r    r/8   prime decomp
//
// dw = r = b - c

module sha3 #(
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

wire         kp_m_valid;
wire         kp_m_ready;
wire         kp_m_last;
wire [r-1:0] kp_m_data;

keccak_pad #(
	.dw    (r),
	.magic (8'h06)
) keccak_pad_inst (
	.clk (clk),

	.s_valid (s_valid),
	.s_ready (s_ready),
	.s_last  (s_last),
	.s_data  (s_data),
	.s_keep  (s_keep),

	.m_valid (kp_m_valid),
	.m_ready (kp_m_ready),
	.m_last  (kp_m_last),
	.m_data  (kp_m_data)
);

// these are constant for sha3
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

	.s_valid (kp_m_valid),
	.s_ready (kp_m_ready),
	.s_data  (kp_m_data),
	.s_last  (kp_m_last),

	.m_valid (m_valid),
	.m_ready (m_ready),
	.m_hash  (m_hash)
);

endmodule
