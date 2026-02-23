// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Tristan Itschner
`default_nettype none
`timescale 1 ns / 1 ps

// This is keccak-p, the current round can be selected by s_ir, rounds till
// ir_max available.

module keccak_stage #(
	parameter b          = 1600,
	parameter ir_max     = 24,
	parameter registered = 0
) (
	input wire clk,

	input  wire                      s_valid,
	output wire                      s_ready,
	input  wire [b-1:0]              s_data,
	input  wire [$clog2(ir_max)-1:0] s_ir,

	output wire         m_valid,
	input  wire         m_ready,
	output wire [b-1:0] m_data
);

localparam w = b/25;
localparam l = $clog2(w);

genvar gi, gj, gk;

wire [w-1:0] state_in [0:4] [0:4];

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		for (gk = 0; gk < w; gk = gk + 1) begin
			assign state_in[gi][gj][gk] = s_data[w*(5*gj+gi)+gk];
		end
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// theta

wire [w-1:0] state_theta [0:4] [0:4];

wire [w-1:0] theta_c [0:4];

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < w; gj = gj + 1) begin
		assign theta_c[gi][gj] = 
			state_in[gi][0][gj] ^ state_in[gi][1][gj] ^
			state_in[gi][2][gj] ^ state_in[gi][3][gj] ^
			state_in[gi][4][gj];
	end
end endgenerate

wire [w-1:0] theta_d [0:4];

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < w; gj = gj + 1) begin
		assign theta_d[gi][gj] = 
			theta_c[(gi+5-1)%5][gj] ^ theta_c[(gi+1)%5][(gj+w-1)%w];
	end
end endgenerate

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		for (gk = 0; gk < w; gk = gk + 1) begin
			assign state_theta[gi][gj][gk] =
			state_in[gi][gj][gk] ^ theta_d[gi][gk];
		end
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// rho

wire [w-1:0] state_rho [0:4] [0:4];

generate for (gi = 0; gi < w; gi = gi + 1) begin
	assign state_rho[0][0][gi] = state_theta[0][0][gi];
end endgenerate

// so this is a little bit hacky...

function [24*3-1:0] rho_mapping_x_func();
	integer i;
	integer x, y;
	integer x_new, y_new;
	begin
		x = 1; y = 0;
		for (i = 0; i < 24; i = i + 1) begin
			rho_mapping_x_func[3*(i+1)-1-:3] = x;
			x_new = y; 
			y_new = (2*x + 3*y) % 5;
			x = x_new; y = y_new;
		end
	end
endfunction

function [24*3-1:0] rho_mapping_y_func();
	integer i;
	integer x, y;
	integer x_new, y_new;
	begin
		x = 1; y = 0;
		for (i = 0; i < 24; i = i + 1) begin
			rho_mapping_y_func[3*(i+1)-1-:3] = y;
			x_new = y; 
			y_new = (2*x + 3*y) % 5;
			x = x_new; y = y_new;
		end
	end
endfunction

localparam [24*3-1:0] rho_mapping_x = rho_mapping_x_func();
localparam [24*3-1:0] rho_mapping_y = rho_mapping_y_func();

// (Reason: we need these ^ to be compile time constants)

generate for (gi = 0; gi < 24; gi = gi + 1) begin

	localparam x = rho_mapping_x[3*(gi+1)-1-:3];
	localparam y = rho_mapping_y[3*(gi+1)-1-:3];

	for (gj = 0; gj < w; gj = gj + 1) begin
		assign state_rho[x][y][gj]
		= state_theta[x][y][(gj + w*w - ((gi + 1)*(gi + 2))/2) % w];
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// pi

wire [w-1:0] state_pi [0:4] [0:4];

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		for (gk = 0; gk < w; gk = gk + 1) begin
			assign state_pi[gi][gj][gk]
				= state_rho[(gi + 3*gj) % 5][gi][gk];
		end
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// chi

wire [w-1:0] state_chi [0:4] [0:4];

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		for (gk = 0; gk < w; gk = gk + 1) begin
			assign state_chi[gi][gj][gk] =
			state_pi[gi][gj][gk] ^ (
				(state_pi[(gi+1)%5][gj][gk] ^ 1) &
				state_pi[(gi+2)%5][gj][gk]
			);
		end
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// iota

wire [w-1:0] state_iota [0:4] [0:4];

// note the bit endianess swap in comparison to the spec
function rc(input integer t);
	reg [8:0] r;
	integer i;
	begin
		t = t + 255;
		if ((t % 255) == 0) rc = 1;
		else begin
			r = 1;
			for (i = 0; i < (t % 255); i = i + 1) begin
				r = r << 1;
				r[0] = r[0] ^ r[8];
				r[4] = r[4] ^ r[8];
				r[5] = r[5] ^ r[8];
				r[6] = r[6] ^ r[8];
				r = {1'b0, r[7:0]};
			end
			rc = r[0];
		end
	end
endfunction

function [w-1:0] rc_func(input integer ir);
	integer j;
	begin
		rc_func = 0;
		for (j = 0; j <= l; j = j + 1) begin
			rc_func[(1 << j)-1] = rc(j + 7*ir);
		end
	end
endfunction

// build the lookup table, so we're run-time reconfigurable
function [w*ir_max-1:0] rc_lookup_func();
	integer i;
	begin
		for (i = 0; i < ir_max; i = i + 1) begin
			rc_lookup_func[w*(i+1)-1-:w] = rc_func(i);
		end
	end
endfunction

localparam rc_lookup = rc_lookup_func();

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		if (gi == 0 && gj == 0) begin : gen_lane00
			assign state_iota[0][0] = 
				state_chi[0][0] ^ rc_lookup[w*s_ir+w-1-:w];
		end else begin : gen_passthrough
			assign state_iota[gi][gj] = 
				state_chi[gi][gj];
		end
	end 
end endgenerate

////////////////////////////////////////////////////////////////////////////////

wire [b-1:0] c_data;

generate for (gi = 0; gi < 5; gi = gi + 1) begin
	for (gj = 0; gj < 5; gj = gj + 1) begin
		assign c_data[w*(5*gj+gi+1)-1-:w] = state_iota[gi][gj];
	end
end endgenerate

////////////////////////////////////////////////////////////////////////////////

generate if (registered) begin : gen_registered

	reg [b-1:0] r_data;

	always @(posedge clk) begin
		if (s_valid && s_ready) begin
			r_data <= c_data;
		end
	end

	assign m_data = r_data;

	reg r_valid = 0;

	always @(posedge clk) begin
		case ({s_valid && s_ready, m_valid && m_ready})
			2'b10: r_valid <= 1;
			2'b01: r_valid <= 0;
		endcase
	end

	assign m_valid = r_valid;
	assign s_ready = !r_valid || (r_valid && m_ready);

end else begin : gen_combinational

	assign m_data = c_data;
	assign m_valid = s_valid;
	assign s_ready = m_ready;

end endgenerate

endmodule
