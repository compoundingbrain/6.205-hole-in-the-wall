`define MAIN
`define MAIN
`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
  input wire          clk_100mhz,
  output logic [15:0] led,
  // camera bus
  input wire [7:0]    camera_d, // 8 parallel data wires
  output logic        cam_xclk, // XC driving camera
  input wire          cam_hsync, // camera hsync wire
  input wire          cam_vsync, // camera vsync wire
  input wire          cam_pclk, // camera pixel clock
  inout wire          i2c_scl, // i2c inout clock
  inout wire          i2c_sda, // i2c inout data
  input wire [15:0]   sw,
  input wire [2:0]    rgb0,
  input wire [2:0]    rgb1,
  input wire [3:0]    btn,
`ifdef MAIN
  input wire [7:0]    pmodb,
`elsif SECONDARY
  output logic [7:0] pmodb,
`endif
  // seven segment
  output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
  output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
  output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
  output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
  // hdmi port
  output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
  output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
  output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
  // DDR3 ports
  inout wire [15:0]  ddr3_dq,
  inout wire [1:0]   ddr3_dqs_n,
  inout wire [1:0]   ddr3_dqs_p,
  output wire [12:0] ddr3_addr,
  output wire [2:0]  ddr3_ba,
  output wire        ddr3_ras_n,
  output wire        ddr3_cas_n,
  output wire        ddr3_we_n,
  output wire        ddr3_reset_n,
  output wire        ddr3_ck_p,
  output wire        ddr3_ck_n,
  output wire        ddr3_cke,
  output wire [1:0]  ddr3_dm,
  output wire        ddr3_odt
);
  assign rgb0 = 0;
  assign rgb1 = 0;

  localparam SCREEN_WIDTH = 1280;
  localparam SCREEN_HEIGHT = 720;

  // Switches
  logic [1:0] display_choice;
  assign display_choice = sw[1:0];
  logic [1:0] num_players; 
  assign num_players = sw[3:2]; // 2'b00 for 1, 2'b01 for 2, 2'b10 for 3, 2'b11 for 4
  logic disable_player_tracking;
  assign disable_player_tracking = sw[14]; // 1 for disable, 0 for enable
  logic disable_wall;
  assign disable_wall = sw[15]; // 1 for disable, 0 for enable
  logic is_game_enabled; // 0 for enabled, 1 for disabled
  assign is_game_enabled = sw[13];
  logic [3:0] red_upper;
  assign red_upper = 0;
  logic [3:0] blue_upper;
  assign blue_upper = 0;
  // logic [1:0] shift_for_red_and_blue = sw[5:4];
  logic [3:0] green_lower;
  assign green_lower = 0;
  // logic [3:0] cr_upper;
  // assign cr_upper = sw[7:4];
  // logic [3:0] cb_upper;
  // assign cb_upper = sw[11:8];

  // Clock and Reset Signals: updated for a couple new clocks!
  logic          sys_rst_camera;
  logic          sys_rst_pixel;
  logic          sys_rst_game_logic;

  logic          btn_start_game;

  logic          clk_camera;
  logic          clk_pixel;
  logic          clk_5x;
  logic          clk_xc;


  logic          clk_migref;
  logic          sys_rst_migref;
  
  logic          clk_ui;
  logic          sys_rst_ui;
  
  logic          clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_pixel: 74.25MHz
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
    .clk_pixel(clk_pixel),
    .clk_tmds(clk_5x),
    .reset(0));

  cw_fast_clk_wiz wizard_migcam(
    .clk_in1(clk_100mhz),
    .clk_camera(clk_camera),
    .clk_mig(clk_migref),
    .clk_xc(clk_xc),
    .clk_100(clk_100_passthrough),
    .reset(0));

  // assign camera's xclk to pmod port: drive the operating clock of the camera!
  // this port also is specifically set to high drive by the XDC file.
  assign cam_xclk = clk_xc;

  // Buttons + Resets 
  assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
  assign sys_rst_game_logic = btn[0]; //use for resetting game logic pipeline
  assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic
  assign sys_rst_migref = btn[0];
  assign btn_start_game = btn[1];


  // video signal generator signals
  logic          hsync_hdmi;
  logic          vsync_hdmi;
  logic [10:0]   hcount_hdmi;
  logic [9:0]    vcount_hdmi;
  logic          active_draw_hdmi;
  logic          new_frame_hdmi;
  logic [5:0]    frame_count_hdmi;
  logic          nf_hdmi;

  // rgb output values
  logic [7:0]    red,green,blue;

  //============================================================================
  // Camera Pipeline
  //============================================================================

  // ** Handling input from the camera **

  // synchronizers to prevent metastability
  logic [7:0]    camera_d_buf [1:0];
  logic          cam_hsync_buf [1:0];
  logic          cam_vsync_buf [1:0];
  logic          cam_pclk_buf [1:0];

  always_ff @(posedge clk_camera) begin
    camera_d_buf[1] <= camera_d;
    camera_d_buf[0] <= camera_d_buf[1];
    cam_pclk_buf[1] <= cam_pclk;
    cam_pclk_buf[0] <= cam_pclk_buf[1];
    cam_hsync_buf[1] <= cam_hsync;
    cam_hsync_buf[0] <= cam_hsync_buf[1];
    cam_vsync_buf[1] <= cam_vsync;
    cam_vsync_buf[0] <= cam_vsync_buf[1];
  end

  logic [10:0] camera_hcount;
  logic [9:0]  camera_vcount;
  logic [15:0] camera_pixel;
  logic        camera_valid;

  // your pixel_reconstruct module, from the exercise!
  // hook it up to buffered inputs.
  pixel_reconstruct pixel_reconstruct_inst
    (.clk_in(clk_camera),
    .rst_in(sys_rst_camera),
    .camera_pclk_in(cam_pclk_buf[0]),
    .camera_hs_in(cam_hsync_buf[0]),
    .camera_vs_in(cam_vsync_buf[0]),
    .camera_data_in(camera_d_buf[0]),
    .pixel_valid_out(camera_valid),
    .pixel_hcount_out(camera_hcount),
    .pixel_vcount_out(camera_vcount),
    .pixel_data_out(camera_pixel));
  
  logic [15:0] frame_buff_dram; // data out of DRAM frame buffer
  logic [15:0] frame_buff_raw; // select between the two!
  assign frame_buff_raw = frame_buff_dram;

  // Write memory to DRAM and read it out, over a couple AXI-Stream data pipelines.
  // DRAM STUFF STARTS HERE

  logic [127:0] camera_chunk;
  logic [127:0] camera_axis_tdata;
  logic         camera_axis_tlast;
  logic         camera_axis_tready;
  logic         camera_axis_tvalid;

  // takes our 16-bit values and deserialize/stack them into 128-bit messages to write to DRAM
  // the data pipeline is designed such that we can fairly safely assume its always ready.
  stacker stacker_inst(
    .clk_in(clk_camera),
    .rst_in(sys_rst_camera),
    .pixel_tvalid(camera_valid),
    .pixel_tready(),
    .pixel_tdata(camera_pixel),
    .pixel_tlast(camera_hcount == 1279 && camera_vcount == 719), // define the tlast value
    .chunk_tvalid(camera_axis_tvalid),
    .chunk_tready(camera_axis_tready),
    .chunk_tdata(camera_axis_tdata),
    .chunk_tlast(camera_axis_tlast));
  
  logic [127:0] camera_ui_axis_tdata;
  logic         camera_ui_axis_tlast;
  logic         camera_ui_axis_tready;
  logic         camera_ui_axis_tvalid;
  logic         camera_ui_axis_prog_empty;

  // FIFO data queue of 128-bit messages, crosses clock domains to the 81.25MHz
  // UI clock of the memory interface
  ddr_fifo_wrap camera_data_fifo(
    .sender_rst(sys_rst_camera),
    .sender_clk(clk_camera),
    .sender_axis_tvalid(camera_axis_tvalid),
    .sender_axis_tready(camera_axis_tready),
    .sender_axis_tdata(camera_axis_tdata),
    .sender_axis_tlast(camera_axis_tlast),
    .receiver_clk(clk_ui),
    .receiver_axis_tvalid(camera_ui_axis_tvalid),
    .receiver_axis_tready(camera_ui_axis_tready),
    .receiver_axis_tdata(camera_ui_axis_tdata),
    .receiver_axis_tlast(camera_ui_axis_tlast),
    .receiver_axis_prog_empty(camera_ui_axis_prog_empty));

  logic [127:0] display_ui_axis_tdata;
  logic         display_ui_axis_tlast;
  logic         display_ui_axis_tready;
  logic         display_ui_axis_tvalid;
  logic         display_ui_axis_prog_full;

  // these are the signals that the MIG IP needs for us to define!
  // MIG UI --> generic outputs
  logic [26:0]  app_addr;
  logic [2:0]   app_cmd;
  logic         app_en;
  // MIG UI --> write outputs
  logic [127:0] app_wdf_data;
  logic         app_wdf_end;
  logic         app_wdf_wren;
  logic [15:0]  app_wdf_mask;
  // MIG UI --> read inputs
  logic [127:0] app_rd_data;
  logic         app_rd_data_end;
  logic         app_rd_data_valid;
  // MIG UI --> generic inputs
  logic         app_rdy;
  logic         app_wdf_rdy;
  // MIG UI --> misc
  logic         app_sr_req; 
  logic         app_ref_req;
  logic         app_zq_req; 
  logic         app_sr_active;
  logic         app_ref_ack;
  logic         app_zq_ack;
  logic         init_calib_complete;
  

  // this traffic generator handles reads and writes issued to the MIG IP,
  // which in turn handles the bus to the DDR chip.
  traffic_generator readwrite_looper(
    // Outputs
    .app_addr         (app_addr[26:0]),
    .app_cmd          (app_cmd[2:0]),
    .app_en           (app_en),
    .app_wdf_data     (app_wdf_data[127:0]),
    .app_wdf_end      (app_wdf_end),
    .app_wdf_wren     (app_wdf_wren),
    .app_wdf_mask     (app_wdf_mask[15:0]),
    .app_sr_req       (app_sr_req),
    .app_ref_req      (app_ref_req),
    .app_zq_req       (app_zq_req),
    .write_axis_ready (camera_ui_axis_tready),
    .read_axis_data   (display_ui_axis_tdata),
    .read_axis_tlast  (display_ui_axis_tlast),
    .read_axis_valid  (display_ui_axis_tvalid),
    // Inputs
    .clk_in           (clk_ui),
    .rst_in           (sys_rst_ui),
    .app_rd_data      (app_rd_data[127:0]),
    .app_rd_data_end  (app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_rdy          (app_rdy),
    .app_wdf_rdy      (app_wdf_rdy),
    .app_sr_active    (app_sr_active),
    .app_ref_ack      (app_ref_ack),
    .app_zq_ack       (app_zq_ack),
    .init_calib_complete(init_calib_complete),
    .write_axis_data  (camera_ui_axis_tdata),
    .write_axis_tlast (camera_ui_axis_tlast),
    .write_axis_valid (camera_ui_axis_tvalid),
    .write_axis_smallpile(camera_ui_axis_prog_empty),
    .read_axis_af     (display_ui_axis_prog_full),
    .read_axis_ready  (display_ui_axis_tready)
  );

  // the MIG IP!
  ddr3_mig ddr3_mig_inst 
    (
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    .sys_clk_i(clk_migref),
    .app_addr(app_addr),
    .app_cmd(app_cmd),
    .app_en(app_en),
    .app_wdf_data(app_wdf_data),
    .app_wdf_end(app_wdf_end),
    .app_wdf_wren(app_wdf_wren),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_rdy(app_rdy),
    .app_wdf_rdy(app_wdf_rdy), 
    .app_sr_req(app_sr_req),
    .app_ref_req(app_ref_req),
    .app_zq_req(app_zq_req),
    .app_sr_active(app_sr_active),
    .app_ref_ack(app_ref_ack),
    .app_zq_ack(app_zq_ack),
    .ui_clk(clk_ui), 
    .ui_clk_sync_rst(sys_rst_ui),
    .app_wdf_mask(app_wdf_mask),
    .init_calib_complete(init_calib_complete),
    // .device_temp(device_temp),
    .sys_rst(!sys_rst_migref) // active low
  );
  
  logic [127:0] display_axis_tdata;
  logic         display_axis_tlast;
  logic         display_axis_tready;
  logic         display_axis_tvalid;
  logic         display_axis_prog_empty;
  
  ddr_fifo_wrap pdfifo(
    .sender_rst(sys_rst_ui),
    .sender_clk(clk_ui),
    .sender_axis_tvalid(display_ui_axis_tvalid),
    .sender_axis_tready(display_ui_axis_tready),
    .sender_axis_tdata(display_ui_axis_tdata),
    .sender_axis_tlast(display_ui_axis_tlast),
    .sender_axis_prog_full(display_ui_axis_prog_full),
    .receiver_clk(clk_pixel),
    .receiver_axis_tvalid(display_axis_tvalid),
    .receiver_axis_tready(display_axis_tready),
    .receiver_axis_tdata(display_axis_tdata),
    .receiver_axis_tlast(display_axis_tlast),
    .receiver_axis_prog_empty(display_axis_prog_empty));

  logic frame_buff_tvalid;
  logic frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;

  unstacker unstacker_inst(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .chunk_tvalid(display_axis_tvalid),
    .chunk_tready(display_axis_tready),
    .chunk_tdata(display_axis_tdata),
    .chunk_tlast(display_axis_tlast),
    .pixel_tvalid(frame_buff_tvalid),
    .pixel_tready(frame_buff_tready),
    .pixel_tdata(frame_buff_tdata),
    .pixel_tlast(frame_buff_tlast));

  // assign frame_buff_tready
  always_comb begin
    if (active_draw_hdmi) begin
      if(frame_buff_tlast && (hcount_hdmi != 1279 || vcount_hdmi != 719))
        frame_buff_tready = 1'b0;
      else
        frame_buff_tready = 1'b1;
    end else
      frame_buff_tready = 1'b0;
  end
  
  assign frame_buff_dram = frame_buff_tvalid ? frame_buff_tdata : 16'h2277;

  // DRAM STUFF ENDS HERE

  //============================================================================
  // Color Masking
  //============================================================================

  //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
  //remapped frame_buffer outputs with 8 bits for r, g, b
  logic [7:0] fb_red, fb_green, fb_blue;
  always_ff @(posedge clk_pixel)begin
    fb_red <= {frame_buff_raw[15:11],3'b0};
    fb_green <= {frame_buff_raw[10:5], 2'b0};
    fb_blue <= {frame_buff_raw[4:0],3'b0};
  end
  // Pixel Processing pre-HDMI output

  // RGB to YCrCb

  //output of rgb to ycrcb conversion (10 bits due to module):
  logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
  //bottom 8 of y, cr, cb conversions:
  logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
  //Convert RGB of full pixel to YCrCb
  //See lecture 07 for YCrCb discussion.
  //Module has a 3 cycle latency
  rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_pixel),
    .r_in(fb_red),
    .g_in(fb_green),
    .b_in(fb_blue),
    .y_out(y_full),
    .cr_out(cr_full),
    .cb_out(cb_full)
  );

  //channel select module (select which of six color channels to mask):
  logic [2:0] channel_sel;
  // logic [7:0] selected_channel; //selected channels
  //selected_channel could contain any of the six color channels depend on selection

  //threshold module (apply masking threshold):
  logic [7:0] lower_green_threshold;
  logic [7:0] upper_green_threshold;
  logic [7:0] lower_red_threshold;
  logic [7:0] upper_red_threshold;
  logic [7:0] lower_blue_threshold;
  logic [7:0] upper_blue_threshold;
  logic [7:0] lower_cr_threshold;
  logic [7:0] upper_cr_threshold;
  logic [7:0] lower_cb_threshold;
  logic [7:0] upper_cb_threshold;
  logic       green_mask; //Whether or not thresholded pixel is 1 or 0
  logic       red_mask;
  logic       blue_mask;
  logic       is_green_screen;
  logic       is_in_game_window; // define a window inside the screen that will not be considered a player
  logic       is_player;
  logic       cr_mask;
  logic       cb_mask;
  // assign is_green_screen = (green_mask) & (fb_green > (fb_red >> shift_for_red_and_blue)) & (fb_green > (fb_blue >> shift_for_red_and_blue));
  assign is_green_screen = cr_mask & cb_mask;
  assign is_in_game_window = (hcount_hdmi >= 65) & (hcount_hdmi <= 1279-85) & (vcount_hdmi >= 0) & (vcount_hdmi <= 719-85);
  assign is_player = ~is_green_screen & is_in_game_window;

  //take lower 8 of full outputs.
  // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
  assign y = y_full[7:0];
  assign cr = {!cr_full[7],cr_full[6:0]};
  assign cb = {!cb_full[7],cb_full[6:0]};

  // * 3'b000: green
  // * 3'b001: red
  // * 3'b010: blue
  // * 3'b011: not valid
  // * 3'b100: y (luminance)
  // * 3'b101: Cr (Chroma Red)
  // * 3'b110: Cb (Chroma Blue)
  // * 3'b111: not valid
  //Channel Select: Takes in the full RGB and YCrCb information and
  // chooses one of them to output as an 8 bit value
  // channel_select green_mcs(
  //   .sel_in(3'b000), // for green screen
  //   .r_in(fb_red),    
  //   .g_in(fb_green),  
  //   .b_in(fb_blue),   
  //   .y_in(y),
  //   .cr_in(cr),
  //   .cb_in(cb),
  //   .channel_out(selected_channel)
  // );

  // Threshold: Looking for not green screen, so low green, higher red and blues

  //threshold values used to determine what value  passes:
  assign lower_green_threshold = {green_lower,4'b0};
  assign upper_green_threshold = {4'b1111,4'b0};
  assign lower_red_threshold = {4'b0000,4'b0};
  assign upper_red_threshold = {red_upper,4'b0};
  assign lower_blue_threshold = {4'b0000,4'b0};
  assign upper_blue_threshold = {blue_upper,4'b0};
  assign lower_cr_threshold = {4'b0000,4'b0};
  assign upper_cr_threshold = {4'b1001,4'b0};
  assign lower_cb_threshold = {4'b0000,4'b0};
  assign upper_cb_threshold = {4'b1001,4'b0};

  //Thresholder: Takes in the full selected channedl and
  //based on upper and lower bounds provides a binary mask bit
  // * 1 if selected channel is within the bounds (inclusive)
  // * 0 if selected channel is not within the bounds
  // threshold green_mt(
  //   .clk_in(clk_pixel),
  //   .rst_in(sys_rst_pixel),
  //   .pixel_in(fb_green),
  //   .lower_bound_in(lower_green_threshold),
  //   .upper_bound_in(upper_green_threshold),
  //   .mask_out(green_mask) //single bit if pixel within mask.
  // );

  // threshold red_mt(
  //   .clk_in(clk_pixel),
  //   .rst_in(sys_rst_pixel),
  //   .pixel_in(fb_red),
  //   .lower_bound_in(lower_red_threshold),
  //   .upper_bound_in(upper_red_threshold),
  //   .mask_out(red_mask) //single bit if pixel within mask.
  // );

  // threshold blue_mt(
  //   .clk_in(clk_pixel),
  //   .rst_in(sys_rst_pixel),
  //   .pixel_in(fb_blue),
  //   .lower_bound_in(lower_blue_threshold),
  //   .upper_bound_in(upper_blue_threshold),
  //   .mask_out(blue_mask) //single bit if pixel within mask.
  // );

  threshold cr_mt(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .pixel_in(cr),
    .lower_bound_in(lower_cr_threshold),
    .upper_bound_in(upper_cr_threshold),
    .mask_out(cr_mask) //single bit if pixel within mask.
  );

  threshold cb_mt(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .pixel_in(cb),
    .lower_bound_in(lower_cb_threshold),
    .upper_bound_in(upper_cb_threshold),
    .mask_out(cb_mask) //single bit if pixel within mask.
  );


  logic [6:0] ss_c;
  //modified version of seven segment display for showing
  // thresholds and selected channel
  // special customized version
  lab05_ssc mssc(.clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .lt_in(lower_green_threshold),
    .ut_in(upper_green_threshold),
    .channel_sel_in(channel_sel),
    .cat_out(ss_c),
    .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c; //control upper four digit's cathodes!
  assign ss1_c = ss_c; //same as above but for lower four digits!

  //============================================================================
  // Center of Mass Logic
  //============================================================================

  // Kmeans outputs
  logic com_valid_out;
  logic [10:0] x_com_out [3:0];
  logic [9:0] y_com_out [3:0];
  logic [10:0] last_valid_x_com_out [3:0];
  logic [9:0] last_valid_y_com_out [3:0];
  logic [1:0] pixel_player_num;

  moving_frame_k_means kmeans (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_in(hcount_hdmi),
    .y_in(vcount_hdmi),
    .valid_in(is_player & active_draw_hdmi), // is player in mask
    .tabulate_in(nf_hdmi),
    .num_players(num_players),
    .x_out(x_com_out),
    .y_out(y_com_out),
    .valid_out(com_valid_out),
    .player_out(pixel_player_num)
  );

  always_ff @(posedge clk_pixel) begin
    if (sys_rst_pixel) begin
      for(int i = 0; i < 4; i++) begin
        last_valid_x_com_out[i] <= 0;
        last_valid_y_com_out[i] <= 0;
      end
    end else if (com_valid_out) begin
      for(int i = 0; i<4; i++) begin
        last_valid_x_com_out[i] <= x_com_out[i];
        last_valid_y_com_out[i] <= y_com_out[i];
      end
    end
  end

  // Transmit/Recieve COM via UART
  localparam UART_BAUD_RATE = 115200;
  logic [10:0] secondary_com_x [3:0];
  logic [9:0] secondary_com_y [3:0];
`ifdef SECONDARY
  genvar tx_i;
  generate
    for (tx_i = 0; tx_i < 4; tx_i++) begin
      // Send x and y COMs along 8 wires. For simplicity pad y com to 11 bits 
      // and then only take bottom 10 bits after rx.
      uart_transmit #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_tx_x (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_byte_in(last_valid_x_com_out[tx_i]),
        .trigger_in(com_valid_out),
        .busy_out(),
        .tx_wire_out(pmodb[tx_i])
      );
      uart_transmit #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_tx_y (
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_byte_in({1'b0, last_valid_y_com_out[tx_i]}),
        .trigger_in(com_valid_out),
        .busy_out(),
        .tx_wire_out(pmodb[tx_i+4])
      );
    end
  endgenerate
`elsif MAIN 

    // Buffer input wires to avoid metastability, note iVerilog warnings here are OK
    logic [1:0] uart_rx_x_buf [3:0];
    logic [1:0] uart_rx_y_buf [3:0];
    always_ff @(posedge clk_pixel) begin
      for (int i = 0; i < 4; i++) begin
        uart_rx_x_buf[i][1] <= pmodb[i];
        uart_rx_x_buf[i][0] <= uart_rx_x_buf[i][1];
        uart_rx_y_buf[i][1] <= pmodb[i+4];
        uart_rx_y_buf[i][0] <= uart_rx_y_buf[i][1];
      end
    end

    logic [3:0] uart_rx_x_trigger;
    logic [3:0] uart_rx_y_trigger;
    logic [10:0] temp_secondary_com_x [3:0];
    logic [10:0] temp_secondary_com_y [3:0];
    genvar rx_i;
    generate
      for (rx_i = 0; rx_i < 4; rx_i++) begin
        uart_receive #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_rx_x (
          .clk_in(clk_pixel),
          .rst_in(sys_rst_pixel),
          .rx_wire_in(uart_rx_x_buf[rx_i][0]),
          .new_data_out(uart_rx_x_trigger[rx_i]),
          .data_byte_out(temp_secondary_com_x[rx_i])
        );
        uart_receive #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_rx_y (
          .clk_in(clk_pixel),
          .rst_in(sys_rst_pixel),
          .rx_wire_in(uart_rx_y_buf[rx_i][0]),
          .new_data_out(uart_rx_y_trigger[rx_i]),
          .data_byte_out(temp_secondary_com_y[rx_i])
        );
      end
    endgenerate

    // Store COM on recieve
    always_ff @(posedge clk_pixel) begin
      for (int i = 0; i < 4; i++) begin
        if (uart_rx_x_trigger[i]) begin
          secondary_com_x[i] <= temp_secondary_com_x[i];
        end
        if (uart_rx_y_trigger[i]) begin
          secondary_com_y[i] <= temp_secondary_com_y[i][9:0];
        end
      end
    end
`endif

  // Calculate player depths via parallax
  logic [7:0] player_depths [3:0];
  localparam SENSOR_WIDTH = 1;
  localparam FOCAL_LENGTH = 1;
  localparam BASELINE_DISTANCE = 1;
`ifdef MAIN
  logic [9:0] zeroed_y [3:0];
  assign zeroed_y[0] = 0;
  assign zeroed_y[1] = 0;
  assign zeroed_y[2] = 0;
  assign zeroed_y[3] = 0;
  parallax_over #(
    .RESOLUTION_WIDTH(SCREEN_WIDTH),
    .SENSOR_WIDTH(SENSOR_WIDTH),
    .FOCAL_LENGTH(FOCAL_LENGTH),
    .BASELINE_DISTANCE(BASELINE_DISTANCE)
  ) plax_over (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_valid_in(com_valid_out),
    .x_in_1(last_valid_x_com_out),
    .y_in_1(zeroed_y),
    .x_in_2(temp_secondary_com_x),
    .y_in_2(zeroed_y),
    .depth_out(player_depths)
  );
`endif

  //============================================================================
  // Game Logic Pipeline
  //============================================================================

  logic [7:0] wall_depth;
  logic pixel_is_wall;
  logic pixel_is_collision;
  logic [2:0] game_state;

  // game wall bounds parameters
  localparam GOAL_DEPTH = 60;
  localparam GOAL_DEPTH_DELTA = 10; 
  localparam MAX_WALL_DEPTH = GOAL_DEPTH + GOAL_DEPTH_DELTA +5;

`ifdef MAIN
  game_logic_controller #(
    .SCREEN_WIDTH(SCREEN_WIDTH), 
    .SCREEN_HEIGHT(SCREEN_HEIGHT), 
    .GOAL_DEPTH(GOAL_DEPTH),
    .GOAL_DEPTH_DELTA(GOAL_DEPTH_DELTA),
    .MAX_WALL_DEPTH(MAX_WALL_DEPTH),
    .MAX_FRAMES_PER_WALL_TICK(15), // slowest speed of wall movement
    .BIT_MASK_DOWN_SAMPLE_FACTOR(16),
    .MAX_ROUNDS(3),
    .COLLISION_THRESHOLD(256)
  ) game_controller (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_game_logic),
    .start_game_in(btn_start_game),
    .hcount_in(hcount_hdmi),
    .vcount_in(vcount_hdmi),
    .num_players(num_players),
    .data_valid_in(active_draw_hdmi),
    .is_person_in(disable_player_tracking ? 1'b0 :is_player),
    .player_depth_in(player_depths[0]),
    .hcount_out(),
    .vcount_out(),
    .data_valid_out(),
    .wall_depth_out(wall_depth),
    .player_depth_out(),
    .is_wall_out(pixel_is_wall),
    .is_person_out(),
    .is_collision_out(pixel_is_collision),
    .game_state(game_state)
  );
  // TODO: pipeline signals through game controller
`endif

  //============================================================================
  // Graphics Pipeline
  //============================================================================

  //image_sprite output:
  logic [7:0] img_red, img_green, img_blue;

  // HDMI video signal generator
  video_sig_gen vsg
    (
    .pixel_clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_out(hcount_hdmi),
    .vcount_out(vcount_hdmi),
    .vs_out(vsync_hdmi),
    .hs_out(hsync_hdmi),
    .nf_out(nf_hdmi),
    .ad_out(active_draw_hdmi),
    .fc_out(frame_count_hdmi)
  );

  // Video Mux: select from the different display modes based on switch values
  //used with switches for display selections
  logic [1:0] target_choice;
  logic [7:0] graphics_red, graphics_green, graphics_blue;

  assign target_choice = sw[5:4];

  //crosshair output:
  logic [7:0] ch_red, ch_green, ch_blue;
  logic crosshair_valid;

  always_comb begin
    // Initialize colors to zero
    ch_red   = 8'h00;
    ch_green = 8'h00;
    ch_blue  = 8'h00;

    crosshair_valid = 1'b0;

    // Crosshair for centroid 0 - Red
    if ((vcount_hdmi == last_valid_y_com_out[0]) ||
        (hcount_hdmi == last_valid_x_com_out[0])) begin
      ch_red = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for centroid 1 - Green
    if ((vcount_hdmi == last_valid_y_com_out[1]) ||
        (hcount_hdmi == last_valid_x_com_out[1])) begin
      ch_green = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for centroid 2 - Blue
    if ((vcount_hdmi == last_valid_y_com_out[2]) ||
        (hcount_hdmi == last_valid_x_com_out[2])) begin
      ch_blue = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for centroid 3 - White
    if ((vcount_hdmi == last_valid_y_com_out[3]) ||
        (hcount_hdmi == last_valid_x_com_out[3])) begin
      ch_red   = 8'hFF;
      ch_green = 8'hFF;
      ch_blue  = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for secondary centroid 1 - Yellow
    if ((vcount_hdmi == secondary_com_y[0]) ||
        (hcount_hdmi == secondary_com_x[0])) begin
      ch_red   = 8'hFF;
      ch_green = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for secondary centroid 2 - Purple
    if ((vcount_hdmi == secondary_com_y[1]) ||
        (hcount_hdmi == secondary_com_x[1])) begin
      ch_red   = 8'hFF;
      ch_green = 8'h00;
      ch_blue  = 8'hFF;
      crosshair_valid = 1'b1;
    end

    // Crosshair for secondary centroid 3 - Orange
    if ((vcount_hdmi == secondary_com_y[2]) ||
        (hcount_hdmi == secondary_com_x[2])) begin
      ch_red   = 8'hFF;
      ch_green = 8'h80;
      ch_blue  = 8'h00;
      crosshair_valid = 1'b1;
    end

    // Crosshair for secondary centroid 4 - Black
    if ((vcount_hdmi == secondary_com_y[3]) ||
        (hcount_hdmi == secondary_com_x[3])) begin
      ch_red   = 8'h00;
      ch_green = 8'h00;
      ch_blue  = 8'h00;
      crosshair_valid = 1'b1;
    end
  end

  //choose what to display from the camera:
  // * 'b00:  normal camera out
  // * 'b01:  selected channel image in grayscale
  // * 'b10:  masked pixel (all on if 1, all off if 0)
  // * 'b11:  chroma channel with mask overtop as magenta
  //
  //then choose what to use with center of mass:
  // * 'b00: nothing
  // * 'b01: crosshair
  // * 'b10: sprite on top
  // * 'b11: nothing

  video_mux mvm(
    .bg_in(display_choice), //choose background
    .target_in(target_choice), //choose target
    .camera_pixel_in({fb_red, fb_green, fb_blue}), 
    .camera_y_in(y), //luminance 
    .channel_in(8'h00), // selected_channel), //current channel being drawn 
    .thresholded_pixel_in(is_player), //one bit mask signal
    .crosshair_in(crosshair_valid), 
    .crosshair_color_in({ch_red, ch_green, ch_blue}),
    .com_sprite_pixel_in({img_red, img_green, img_blue}), 
    .pixel_out({graphics_red, graphics_green, graphics_blue}) //output to tmds
  );
  // Pipeline pixel to avoid long combination path
  logic [7:0] piped_graphics_red, piped_graphics_green, piped_graphics_blue;
  always @(posedge clk_pixel) begin
    piped_graphics_red <= graphics_red;
    piped_graphics_green <= graphics_green;
    piped_graphics_blue <= graphics_blue;
  end

  // Graphics Controller
  graphics_controller #(
    .ACTIVE_H_PIXELS(1280), .ACTIVE_LINES(720),
    .GOAL_DEPTH(GOAL_DEPTH), .GOAL_DEPTH_DELTA(GOAL_DEPTH_DELTA), .MAX_WALL_DEPTH(MAX_WALL_DEPTH),
    .WALL_COLOR(24'hFF0080), .COLLISION_COLOR(24'h800000)
  )
  gc (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_in(hcount_hdmi),
    .vcount_in(vcount_hdmi),
    .pixel_player_num(pixel_player_num),
    .wall_depth(wall_depth),
    .player_depths(player_depths),
    .num_players(num_players),
    .is_wall(disable_wall ? 1'b0 : pixel_is_wall),
    .is_collision(disable_player_tracking ? 1'b0 : pixel_is_collision),
    .pixel_in({piped_graphics_red, piped_graphics_green, piped_graphics_blue}),
    .game_state_in(is_game_enabled ? 1'b1 : game_state),
    .pixel_out({red, green, blue})
  );

  // HDMI Output: just like before!
  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
  logic       tmds_signal [2:0]; //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  //note green should have no control signal like red
  //the blue channel DOES carry the two sync signals:
  //  * control_in[0] = horizontal sync signal
  //  * control_in[1] = vertical sync signal

  tmds_encoder tmds_red(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_in(red),
    .control_in(2'b0),
    .ve_in(active_draw_hdmi),
    .tmds_out(tmds_10b[2]));

  tmds_encoder tmds_green(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_in(green),
    .control_in(2'b0),
    .ve_in(active_draw_hdmi),
    .tmds_out(tmds_10b[1]));

  tmds_encoder tmds_blue(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_in(blue),
    .control_in({vsync_hdmi,hsync_hdmi}),
    .ve_in(active_draw_hdmi),
    .tmds_out(tmds_10b[0]));


  //three tmds_serializers (blue, green, red):
  //MISSING: two more serializers for the green and blue tmds signals.
  tmds_serializer red_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst_pixel),
    .tmds_in(tmds_10b[2]),
    .tmds_out(tmds_signal[2]));
  tmds_serializer green_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst_pixel),
    .tmds_in(tmds_10b[1]),
    .tmds_out(tmds_signal[1]));
  tmds_serializer blue_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst_pixel),
    .tmds_in(tmds_10b[0]),
    .tmds_out(tmds_signal[0]));

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));


  // Nothing To Touch Down Here:
  // register writes to the camera

  // The OV5640 has an I2C bus connected to the board, which is used
  // for setting all the hardware settings (gain, white balance,
  // compression, image quality, etc) needed to start the camera up.
  // We've taken care of setting these all these values for you:
  // "rom.mem" holds a sequence of bytes to be sent over I2C to get
  // the camera up and running, and we've written a design that sends
  // them just after a reset completes.

  // If the camera is not giving data, press your reset button.

  logic  busy, bus_active;
  logic  cr_init_valid, cr_init_ready;

  logic  recent_reset;
  always_ff @(posedge clk_camera) begin
    if (sys_rst_camera) begin
      recent_reset <= 1'b1;
      cr_init_valid <= 1'b0;
    end
    else if (recent_reset) begin
      cr_init_valid <= 1'b1;
      recent_reset <= 1'b0;
    end else if (cr_init_valid && cr_init_ready) begin
      cr_init_valid <= 1'b0;
    end
  end

  logic [23:0] bram_dout;
  logic [7:0]  bram_addr;

  // ROM holding pre-built camera settings to send
  xilinx_single_port_ram_read_first
    #(
    .RAM_WIDTH(24),
    .RAM_DEPTH(256),
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
    .INIT_FILE("rom.mem")
  ) registers
      (
    .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
    .clka(clk_camera),     // Clock
    .wea(1'b0),            // Write enable
    .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
    .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
    .regcea(1'b1),         // Output register enable
    .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
  );

  logic [23:0] registers_dout;
  logic [7:0]  registers_addr;
  assign registers_dout = bram_dout;
  assign bram_addr = registers_addr;

  logic       con_scl_i, con_scl_o, con_scl_t;
  logic       con_sda_i, con_sda_o, con_sda_t;

  // NOTE these also have pullup specified in the xdc file!
  // access our inouts properly as tri-state pins
  IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
  IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

  // provided module to send data BRAM -> I2C
  camera_registers crw
    (.clk_in(clk_camera),
    .rst_in(sys_rst_camera),
    .init_valid(cr_init_valid),
    .init_ready(cr_init_ready),
    .scl_i(con_scl_i),
    .scl_o(con_scl_o),
    .scl_t(con_scl_t),
    .sda_i(con_sda_i),
    .sda_o(con_sda_o),
    .sda_t(con_sda_t),
    .bram_dout(registers_dout),
    .bram_addr(registers_addr));

  // a handful of debug signals for writing to registers
  assign led[0] = 0;
  assign led[1] = cr_init_valid;
  assign led[2] = cr_init_ready;
  assign led[14:3] = 0;
  assign led[15] = pmodb[0];

endmodule // top_level


`default_nettype wire
