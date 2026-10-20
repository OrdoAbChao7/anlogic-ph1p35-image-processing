`timescale 1ns/1ns

module tb_i2c_single_clock_equivalence;
    parameter integer TEST_CLK_DIV = 7;
    parameter integer TEST_SLAVE_ACK_LOW = 1;
    localparam integer SCL_FULL_PERIOD = ((TEST_CLK_DIV / 2) + 1) * 2;
    localparam integer EXPECTED_COUNTER_WIDTH = $clog2(SCL_FULL_PERIOD);

    reg clk = 1'b0;
    reg rstn = 1'b1;
    reg [7:0] wr_data = 8'hA0;
    reg [7:0] wr_cnt = 8'd1;
    reg [7:0] rd_cnt = 8'd1;
    reg req = 1'b0;
    reg mode = 1'b1;

    wire scl_ref;
    wire scl_ce;
    tri sda_ref;
    tri sda_ce;
    wire [7:0] rd_data_ref;
    wire [7:0] rd_data_ce;
    wire busy_ref;
    wire busy_ce;
    wire error_ref;
    wire error_ce;
    wire sda_debug_ref;
    wire sda_debug_ce;
    integer compared_cycles = 0;

    always #5 clk = ~clk;
    assign sda_ref = TEST_SLAVE_ACK_LOW ? 1'b0 : 1'b1;
    assign sda_ce = TEST_SLAVE_ACK_LOW ? 1'b0 : 1'b1;

    uii2c #(.WMEN_LEN(1), .RMEN_LEN(1), .CLK_DIV(TEST_CLK_DIV)) reference_dut (
        .I_clk(clk), .I_rstn(rstn), .O_iic_scl(scl_ref), .IO_iic_sda(sda_ref),
        .I_wr_data(wr_data), .I_wr_cnt(wr_cnt), .O_rd_data(rd_data_ref),
        .I_rd_cnt(rd_cnt), .I_iic_req(req), .I_iic_mode(mode),
        .O_iic_busy(busy_ref), .O_iic_bus_error(error_ref),
        .IO_iic_sda_dg(sda_debug_ref)
    );

    uii2c_single_clock_candidate #(.WMEN_LEN(1), .RMEN_LEN(1), .CLK_DIV(TEST_CLK_DIV)) candidate_dut (
        .I_clk(clk), .I_rstn(rstn), .O_iic_scl(scl_ce), .IO_iic_sda(sda_ce),
        .I_wr_data(wr_data), .I_wr_cnt(wr_cnt), .O_rd_data(rd_data_ce),
        .I_rd_cnt(rd_cnt), .I_iic_req(req), .I_iic_mode(mode),
        .O_iic_busy(busy_ce), .O_iic_bus_error(error_ce),
        .IO_iic_sda_dg(sda_debug_ce)
    );

    always @(posedge clk) begin
        if (rstn) begin
            #1;
            if ({scl_ref, busy_ref, error_ref, sda_debug_ref, rd_data_ref} !==
                {scl_ce, busy_ce, error_ce, sda_debug_ce, rd_data_ce})
                $fatal(1, "I2C output mismatch cycle=%0d", compared_cycles);
            if (reference_dut.sda_o !== candidate_dut.sda_o)
                $fatal(1, "I2C master SDA drive mismatch cycle=%0d", compared_cycles);
            compared_cycles = compared_cycles + 1;
        end
    end

    initial begin
        if ($bits(candidate_dut.clkdiv) != EXPECTED_COUNTER_WIDTH)
            $fatal(1, "counter width mismatch got=%0d expected=%0d",
                $bits(candidate_dut.clkdiv), EXPECTED_COUNTER_WIDTH);
        #1 rstn = 1'b0;
        repeat (4) @(posedge clk);
        #1 rstn = 1'b1;
        repeat (2) @(posedge clk);
        req = 1'b1;
        @(posedge busy_ref);
        #1 req = 1'b0;
        wait (!busy_ref);
        repeat (3) @(posedge clk);
        if (TEST_SLAVE_ACK_LOW && error_ref) $fatal(1, "reference reported I2C bus error after ACK");
        if (rd_data_ref !== (TEST_SLAVE_ACK_LOW ? 8'h00 : 8'hFF))
            $fatal(1, "reference read data mismatch: %h", rd_data_ref);

        mode = 1'b0;
        rd_cnt = 8'd0;
        wr_data = 8'h5A;
        repeat (2) @(posedge clk);
        req = 1'b1;
        @(posedge busy_ref);
        #1 req = 1'b0;
        wait (!busy_ref);
        repeat (3) @(posedge clk);
        if (TEST_SLAVE_ACK_LOW && error_ref) $fatal(1, "reference reported I2C bus error after ACK");
        if (compared_cycles < 50) $fatal(1, "insufficient comparisons: %0d", compared_cycles);
        $display("TB_I2C_SINGLE_CLOCK_EQUIVALENCE_PASS cycles=%0d read_data=%h", compared_cycles, rd_data_ref);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "I2C equivalence timeout ref_busy=%b candidate_busy=%b state=%0d",
            busy_ref, busy_ce, reference_dut.IIC_S);
    end
endmodule
