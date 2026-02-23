// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// Note: 
// * padding not included here!
// * only keccak[c] supported (though adding support for keccak-p wouldn't be
//   that hard)

module keccak_sponge #(
	parameter  b              = 1600,
	parameter  nr             = 24,
	parameter  stages_per_clk = 1,
	parameter  c              = 1024,
	localparam r              = b - c,
	parameter  d              = 512
) (
	input wire clk,

	input  wire         s_valid,
	output wire         s_ready,
	input  wire [r-1:0] s_data,
	input  wire         s_last,

	output wire         m_valid,
	input  wire         m_ready,
	output wire [d-1:0] m_hash
);

wire         ki_s_valid;
wire         ki_s_ready;
wire [b-1:0] ki_s_data;
wire         ki_m_valid;
wire         ki_m_ready;
wire [b-1:0] ki_m_data;

keccak_iter #(
	.b              (b),
	.nr             (nr),
	.stages_per_clk (stages_per_clk)
) keccak_iter_inst (
	.clk     (clk),
	.s_valid (ki_s_valid),
	.s_ready (ki_s_ready),
	.s_data  (ki_s_data),
	.m_valid (ki_m_valid),
	.m_ready (ki_m_ready),
	.m_data  (ki_m_data)
);

reg r_running = 0;
always @(posedge clk) begin
	if (m_valid && m_ready) begin
		r_running <= 0;
	end
	if (s_valid && s_ready) begin
		r_running <= 1;
	end
end

reg r_last = 1;
always @(posedge clk) begin
	if (s_valid && s_ready) begin
		r_last <= s_last;
	end
end

wire stall = m_valid && !m_ready;

assign m_valid = r_running && r_last && ki_m_valid;

assign s_ready = ki_s_ready && !stall;

assign ki_s_data = (s_valid && s_ready && r_last) ? {{c{1'b0}}, s_data}
						  : ki_m_data ^ {{c{1'b0}}, s_data};

// assign m_hash = m_valid ? ki_m_data[d-1:0] : {d{1'b0}}; // mask for security (needed?)
assign m_hash = ki_m_data[d-1:0]; // mask for security (needed?)

assign ki_s_valid = s_valid && !stall;

assign ki_m_ready = m_valid ? m_ready : 1;

endmodule
