`timescale 1ns/1ns

module tb_i2c_registered_phase;
    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg [7:0] wr_data = 8'hA0;
    reg [7:0] wr_cnt = 8'd1;
    reg [7:0] rd_cnt = 8'd1;
    reg req = 1'b0;
    reg mode = 1'b1;
    wire scl;
    tri sda;
    wire [7:0] rd_data;
    wire busy;
    wire bus_error;
    wire sda_debug;
    integer scl_transitions = 0;

    always #5 clk = ~clk;

    // Permanently asserted low SDA models ACK=0 and read data 0x00.
    assign sda = 1'b0;

    always @(scl)
        if (rstn)
            scl_transitions = scl_transitions + 1;

    uii2c #(
        .WMEN_LEN(1),
        .RMEN_LEN(1),
        .CLK_DIV(7)
    ) dut (
        .I_clk(clk),
        .I_rstn(rstn),
        .O_iic_scl(scl),
        .IO_iic_sda(sda),
        .I_wr_data(wr_data),
        .I_wr_cnt(wr_cnt),
        .O_rd_data(rd_data),
        .I_rd_cnt(rd_cnt),
        .I_iic_req(req),
        .I_iic_mode(mode),
        .O_iic_busy(busy),
        .O_iic_bus_error(bus_error),
        .IO_iic_sda_dg(sda_debug)
    );

    initial begin
        repeat (4) @(posedge clk);
        rstn = 1'b1;
        repeat (2) @(posedge clk);
        req = 1'b1;
        @(posedge busy);
        req = 1'b0;
        wait (!busy);
        if (bus_error) $fatal(1, "unexpected I2C bus error");
        if (rd_data !== 8'h00) $fatal(1, "unexpected read data %h", rd_data);
        if (scl_transitions == 0) $fatal(1, "no SCL transitions observed");
        $display("TB_I2C_REGISTERED_PHASE_PASS busy=%b bus_error=%b rd_data=%h scl_transitions=%0d", busy, bus_error, rd_data, scl_transitions);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "I2C transaction timeout busy=%b state=%0d", busy, dut.IIC_S);
    end
endmodule
