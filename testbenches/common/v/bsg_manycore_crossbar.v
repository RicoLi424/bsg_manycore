/**
 *    bsg_manycore_crossbar.v
 *
 */


`include "bsg_noc_links.vh"


module bsg_manycore_crossbar
  import bsg_manycore_pkg::*;
  #(parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"

    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter num_in_lp=(num_in_x_p*num_in_y_p)
    , parameter lg_num_in_lp=`BSG_SAFE_CLOG2(num_in_lp)

    , parameter fwd_use_credits_p="inv"
    , parameter int fwd_num_credits_p[num_in_lp-1:0]="inv"
    , parameter rev_use_credits_p="inv"
    , parameter int rev_num_credits_p[num_in_lp-1:0]="inv"

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input  [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_i
    , output [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_o 
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_in;
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_out;
  assign links_sif_in = links_sif_i;
  assign links_sif_o = links_sif_out;


  localparam packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  localparam return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p);


  // FWD
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_in;
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign fwd_links_in[i][j] = links_sif_in[i][j].fwd;
      assign links_sif_out[i][j].fwd = fwd_links_out[i][j];
    end
  end

  localparam xbar_fwd_pkt_width_lp = packet_width_lp-x_cord_width_p-y_cord_width_p+lg_num_in_lp;
  //`declare_bsg_ready_and_link_sif_s(xbar_fwd_pkt_width_lp, xbar_fwd_link_sif_s);
  //xbar_fwd_link_sif_s [num_in_lp-1:0] xbar_fwd_links_in;
  //xbar_fwd_link_sif_s [num_in_lp-1:0] xbar_fwd_links_out;
  logic [num_in_lp-1:0] fwd_valid_lo;
  logic [num_in_lp-1:0][xbar_fwd_pkt_width_lp-1:0] fwd_data_lo;
  logic [num_in_lp-1:0] fwd_ready_li;

  logic [num_in_lp-1:0] fwd_valid_li;
  logic [num_in_lp-1:0][xbar_fwd_pkt_width_lp-1:0] fwd_data_li;
  logic [num_in_lp-1:0] fwd_ready_lo;

  bsg_manycore_link_to_crossbar #(
    .width_p(packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
  ) link_to_xbar_fwd (
    .links_sif_i(fwd_links_in)
    ,.links_sif_o(fwd_links_out)

    //,.xbar_links_sif_i(xbar_fwd_links_out)
    //,.xbar_links_sif_o(xbar_fwd_links_in)
    ,.valid_o(fwd_valid_lo) 
    ,.data_o(fwd_data_lo)
    ,.ready_i(fwd_ready_li)

    ,.valid_i(fwd_valid_li) 
    ,.data_i(fwd_data_li)
    ,.ready_o(fwd_ready_lo)
  );

  bsg_router_crossbar_o_by_i #(
    .i_els_p(num_in_lp)
    ,.o_els_p(num_in_lp)
    ,.i_width_p(xbar_fwd_pkt_width_lp)
    ,.i_use_credits_p(fwd_use_credits_p)
    ,.i_num_credits_p(fwd_num_credits_p)
    ,.drop_header_p(0)
  ) fwdx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.valid_i(fwd_valid_lo)
    ,.data_i(fwd_data_lo)
    ,.credit_ready_and_o(fwd_ready_li)

    ,.valid_o(fwd_valid_li)
    ,.data_o(fwd_data_li)
    ,.ready_and_i(fwd_ready_lo)
  );


  // REV
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_in;
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign rev_links_in[i][j] = links_sif_in[i][j].rev;
      assign links_sif_out[i][j].rev = rev_links_out[i][j];
    end
  end

  localparam xbar_rev_pkt_width_lp = return_packet_width_lp-x_cord_width_p-y_cord_width_p+lg_num_in_lp;
  //`declare_bsg_ready_and_link_sif_s(xbar_rev_pkt_width_lp,xbar_rev_link_sif_s);
  //xbar_rev_link_sif_s [num_in_lp-1:0] xbar_rev_links_in;
  //xbar_rev_link_sif_s [num_in_lp-1:0] xbar_rev_links_out;
  logic [num_in_lp-1:0] rev_valid_lo;
  logic [num_in_lp-1:0][xbar_rev_pkt_width_lp-1:0] rev_data_lo;
  logic [num_in_lp-1:0] rev_ready_li;

  logic [num_in_lp-1:0] rev_valid_li;
  logic [num_in_lp-1:0][xbar_rev_pkt_width_lp-1:0] rev_data_li;
  logic [num_in_lp-1:0] rev_ready_lo;

  bsg_manycore_link_to_crossbar #(
    .width_p(return_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
  ) link_to_xbar_rev (
    .links_sif_i(rev_links_in)
    ,.links_sif_o(rev_links_out)

    ,.valid_o(rev_valid_lo) 
    ,.data_o(rev_data_lo)
    ,.ready_i(rev_ready_li)

    ,.valid_i(rev_valid_li) 
    ,.data_i(rev_data_li)
    ,.ready_o(rev_ready_lo)
  );


  bsg_router_crossbar_o_by_i #(
    .i_els_p(num_in_lp)
    ,.o_els_p(num_in_lp)
    ,.i_width_p(xbar_rev_pkt_width_lp)
    ,.i_use_credits_p(rev_use_credits_p)
    ,.i_num_credits_p(rev_num_credits_p)
    ,.drop_header_p(0)
  ) revx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.valid_i(rev_valid_lo)
    ,.data_i(rev_data_lo)
    ,.credit_ready_and_o(rev_ready_li)

    ,.valid_o(rev_valid_li)
    ,.data_o(rev_data_li)
    ,.ready_and_i(rev_ready_lo)
  );


endmodule
