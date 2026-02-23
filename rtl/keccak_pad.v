// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// Description:
// * perform the sha3 / shake padding
// * only byte = 8 bits supported
// * keep filled from right
// * supports "empty" packet
// * as far as I understand it, simply add a byte "06" (now magic byte) and pad 0 till end of
//   word
// * god hell no I have no idea how it works, but the testcases seems all to
//   be happy now that I have added an additional bit :)

// Note:
// * we don't actually need to mask, but do it anyways, remove it if area is
//   of concern
// * this is not just the keccak padding, it is more generic by the magic byte,
//   but padding more than 7 bits arbitrary bits is not supported

module keccak_pad #(
	parameter  dw = 224,
	parameter  magic = 8'h06,
	localparam kw = dw/8
) (
	input wire clk,

	input  wire          s_valid,
	output wire          s_ready,
	input  wire          s_last,
	input  wire [dw-1:0] s_data,
	input  wire [kw-1:0] s_keep,

	output wire          m_valid,
	input  wire          m_ready,
	output wire          m_last,
	output wire [dw-1:0] m_data
);

function [$clog2(kw):0] keepcount(input [kw-1:0] keep);
	integer i;
	begin
		keepcount = 0;
		for (i = 0; i < kw; i = i + 1) begin
			if (keep[i]) begin
				keepcount = keepcount + 1;
			end
		end
	end
endfunction

wire [$clog2(kw):0] s_keepcount = keepcount(s_keep);

function [dw-1:0] mask_data(input [dw-1:0] data, input [$clog2(kw):0] keepcount);
	integer i;
	begin
		mask_data = 0;
		for (i = 0; i < kw; i = i + 1) begin
			if (i < keepcount) mask_data[8*(i+1)-1-:8] = data[8*(i+1)-1-:8];
		end
	end
endfunction

// wire [dw-1:0] s_data_masked = mask_data(s_data, s_keepcount);
wire [dw-1:0] s_data_padded = s_data | {{(dw-8){1'b0}}, magic} << (8*s_keepcount);

wire extra_beat_needed = s_valid && s_last && (s_keepcount == kw);

reg r_extra = 0;
always @(posedge clk) begin
	if (m_valid && m_ready) begin
		r_extra <= 0;
	end
	if (s_valid && s_ready) begin
		if (extra_beat_needed) begin
			r_extra <= 1;
		end
	end
end

assign m_data = r_extra ? {1'b1, {(dw-9){1'b0}}, magic} : 
	        (s_last && !extra_beat_needed) ? s_data_padded | {1'b1, {(dw-1){1'b0}}} : 
		s_data_padded;

assign m_valid = s_valid || r_extra;

assign s_ready = !r_extra && m_ready;

assign m_last = (s_last && !extra_beat_needed) || r_extra;

endmodule
