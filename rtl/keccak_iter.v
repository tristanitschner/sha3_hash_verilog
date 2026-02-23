// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// Note:
// * we could _technically_ precompute which stage in fact needs which round
//   index (with prime decomposition and stuff) and thus remove part of the
//   table (but we won't for obvious reasons, it's a huge clusterfuck)

module keccak_iter #(
	parameter b              = 1600,
	parameter nr             = 24,
	parameter stages_per_clk = 2
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

wire [b-1:0]            ks_i_data [0:stages_per_clk];
wire [$clog2(nr)-1:0]   ks_i_ir   [0:stages_per_clk-1];

generate for (gi = 0; gi < stages_per_clk; gi = gi + 1) begin

	keccak_stage #(
		.b          (b),
		.ir_max     (nr),
		.registered (0)
	) keccak_stage_inst (
		.clk (clk),

		.s_valid (),
		.s_ready (),
		.s_data  (ks_i_data  [gi]),
		.s_ir    (ks_i_ir    [gi]),

		.m_valid (),
		.m_ready (),
		.m_data  (ks_i_data  [gi+1])
	);

end endgenerate

localparam stages_needed = nr/stages_per_clk + ((nr%stages_per_clk) ? 1 : 0);
localparam last_stage_mod = nr % stages_per_clk;

reg r_running = 0;
always @(posedge clk) begin
	if (m_valid && m_ready) begin
		r_running <= 0;
	end
	if (s_valid && s_ready) begin
		r_running <= 1;
	end
end

wire stall = m_valid && !m_ready;

wire do_something = (s_valid && s_ready) || (r_running && !stall);

reg [$clog2(stages_needed)-1:0] counter = 0;
wire last_stage = counter == stages_needed-1;
always @(posedge clk) begin
	if (do_something) begin
		counter <= counter + 1;
	end
	if (last_stage) begin
		counter <= 0;
	end
end

wire [b-1:0] c_data;

reg [b-1:0] r_data;
always @(posedge clk) begin
	if (do_something) begin
		r_data <= c_data;
	end
end

reg r_valid = 0;
always @(posedge clk) begin
	if (last_stage) begin
		r_valid <= 1;
	end
	if (m_valid && m_ready) begin
		r_valid <= 0;
	end
end

assign m_valid = r_valid;

assign m_data = r_data;

assign c_data = 
	last_stage ? (
		last_stage_mod == 0 ? ks_i_data[stages_per_clk]
		                    : ks_i_data[last_stage_mod]
	) : ks_i_data[stages_per_clk];

assign s_ready = !r_running || (m_valid && m_ready);

assign ks_i_data[0] = (s_valid && s_ready) ? s_data : r_data;

generate for (gi = 0; gi < stages_per_clk; gi = gi + 1) begin

	assign ks_i_ir[gi] = stages_per_clk*counter + gi;

end endgenerate

endmodule
