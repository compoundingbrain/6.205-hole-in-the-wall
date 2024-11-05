module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60)
(
  input wire pixel_clk_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out, //vertical sync out
  output logic hs_out, //horizontal sync out
  output logic ad_out,
  output logic nf_out, //single cycle enable signal
  output logic [5:0] fc_out //frame
);

  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;

  counter h_counter(
    .clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .period_in(TOTAL_PIXELS),
    .count_out(hcount_out)
  );

  evt_counter #(.MAX_COUNT(TOTAL_LINES)) v_counter(
    .clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .evt_in(hcount_out == TOTAL_PIXELS-1),
    .count_out(vcount_out)
  );

  evt_counter #(.MAX_COUNT(FPS)) frame_counter(
    .clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .evt_in(hcount_out == ACTIVE_H_PIXELS-1 && vcount_out == ACTIVE_LINES),
    .count_out(fc_out)
  );

  always_comb begin
    if (rst_in==1 || hcount_out >= ACTIVE_H_PIXELS) 
      ad_out = 1'b0;
    else if(hcount_out < ACTIVE_H_PIXELS && vcount_out < ACTIVE_LINES)
      ad_out = 1'b1;
  end

  always_ff @(posedge pixel_clk_in) begin
    if(rst_in) begin
      hs_out <= 0;
      vs_out <= 0;
      nf_out <= 0;
    end else begin
      if(hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1)
        hs_out <= 1'b1;
      else if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1)
        hs_out <= 1'b0;
      
      if(vcount_out == ACTIVE_LINES + V_FRONT_PORCH - 1 && hcount_out == TOTAL_PIXELS - 1)
        vs_out <= 1'b1;
      else if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH - 1 && hcount_out == TOTAL_PIXELS - 1)
        vs_out <= 1'b0;

      if(hcount_out == ACTIVE_H_PIXELS-1 && vcount_out == ACTIVE_LINES)
        nf_out <= 1'b1;
      else
        nf_out <= 1'b0;
    end
  end
endmodule


// module evt_counter #(parameter MAX_COUNT = 8000)
//   ( input wire          clk_in,
//     input wire          rst_in,
//     input wire          evt_in,
//     output logic[15:0]  count_out
//   );
 
//   always_ff @(posedge clk_in) begin
//     if (rst_in) begin
//       count_out <= 16'b0;
//     end else if (evt_in) begin
//       if(count_out == MAX_COUNT-1) 
//         count_out <= 0;
//       else 
//         count_out <= count_out + 1;
//     end
//   end
// endmodule

// module counter(     input wire clk_in,
//                     input wire rst_in,
//                     input wire [31:0] period_in,
//                     output logic [31:0] count_out
//               );

//     logic [31:0] cp;
//     always_comb begin 
//       cp = count_out + 1;
//       if (cp >= period_in) begin
//         cp = 0;
//       end 
//       if (rst_in == 1) begin
//         cp = 0;
//       end
//     end

//     always_ff @(posedge clk_in) begin
//       count_out <= cp;
//     end
// endmodule
