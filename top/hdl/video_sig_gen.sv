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
  output logic [5:0] fc_out); //frame

  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH; //figure this out
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH; //figure this out

  // logic for everything but the counters
  always_comb begin
    if (rst_in) begin
      vs_out = 0;
      hs_out = 0;
      ad_out = 0;
      nf_out = 0;
    end else begin
      // hs_out logic
      // if in the h_sync period, set to one
      if (hcount_out >= ACTIVE_H_PIXELS + H_FRONT_PORCH && hcount_out < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH) begin
        hs_out = 1;
      end else begin
        hs_out = 0;
      end

      // vs_out logic
      // if in the v_sync period, set to one
      if (vcount_out >= ACTIVE_LINES + V_FRONT_PORCH && vcount_out < ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH) begin
        vs_out = 1;
      end else begin
        vs_out = 0;
      end

      // ad_out logic
      // high in drawing, low otherwise
      if (hcount_out < ACTIVE_H_PIXELS && vcount_out < ACTIVE_LINES) begin
        ad_out = 1;
      end else begin
        ad_out = 0;
      end

      // nf_out logic
      // when we have reached ACTIVE_H_PIXELS and ACTIVE_LINES, set to one
      if (hcount_out == ACTIVE_H_PIXELS && vcount_out == ACTIVE_LINES) begin
        nf_out = 1;
      end else begin
        nf_out = 0;
      end
    end 
  end

  // counters
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      hcount_out <= 0;
      vcount_out <= 0;
      fc_out <= 0;
    end else begin 
      // h_count logic
      if (hcount_out == TOTAL_PIXELS - 1) begin // at the last pixel of the back porch
        hcount_out <= 0;
      end else begin
        hcount_out <= hcount_out + 1;
      end

      // v_count logic
      if (hcount_out == TOTAL_PIXELS - 1) begin // at the last pixel of the h back porch
        if (vcount_out == TOTAL_LINES - 1) begin // increment on each new frame, roll back to 0 when it reaches TOTAL_LINES
          vcount_out <= 0;
        end else begin // at the last line of the v back porch
          vcount_out <= vcount_out + 1;
        end
      end

      // fc_out logic
      // increment when we pass the active region
      if (hcount_out == ACTIVE_H_PIXELS - 1 && vcount_out == ACTIVE_LINES) begin // do ACTIVE_H_PIXELS - 1 because we want this to appear at the right count when it reaches ACTIVE_H_PIXELS
        if (fc_out == FPS - 1) begin
          fc_out <= 0;
        end else begin
          fc_out <= fc_out + 1;
        end
      end
    end
  end

endmodule