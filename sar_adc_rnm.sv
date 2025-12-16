`timescale 1ns/1ps

module sar_adc_rnm #(
    parameter int N = 10,
    parameter real vrefp = 1.0,
    parameter real vrefn = 0.0,
    parameter real comp_offset = 1e-3,
    parameter real mismatch_sigma = 0.002
)(
    input  wreal vin,                  // analog input in RNM world
    input  logic clk,                  // SAR clock
    output logic [N-1:0] dout
);

    //=======================
    // Internal storage
    //=======================
    real sample_value;
    real weight[N];
    real weight_mis[N];
    int bit_ptr;
    logic [N-1:0] sar_reg;

    //=======================
    // Generate CDAC mismatch
    //=======================
    initial begin
        for (int i = 0; i < N; i++) begin
            weight[i] = (vrefp - vrefn) / (2.0 ** (i+1));
            weight_mis[i] = weight[i] * (1.0 + $dist_normal($urandom(), 0, mismatch_sigma));
        end
    end

    //=======================
    // Sampling
    //=======================
    always @(posedge clk) begin
        sample_value = vin;
        bit_ptr = N-1;
        sar_reg = '0;
    end

    //=======================
    // SAR Decision Loop
    //=======================
    always @(negedge clk) begin
        if (bit_ptr >= 0) begin
            real trial = dac_value(sar_reg, bit_ptr);
            real comp  = sample_value - trial;

            if (comp >= comp_offset)
                sar_reg[bit_ptr] = 1;
            else
                sar_reg[bit_ptr] = 0;

            bit_ptr--;
        end
    end

    //=======================
    // Output latch
    //=======================
    always @(posedge clk) begin
        if (bit_ptr < 0)
            dout <= sar_reg;
    end

    //=======================
    // DAC Calculation Function
    //=======================
    function real dac_value(input logic [N-1:0] code, input int trial_bit);
        logic [N-1:0] temp = code;
        temp[trial_bit] = 1;
        real sum = 0;

        for (int i = 0; i < N; i++)
            if (temp[i]) sum += weight_mis[i];

        return (vrefn + sum);
    endfunction

endmodule
