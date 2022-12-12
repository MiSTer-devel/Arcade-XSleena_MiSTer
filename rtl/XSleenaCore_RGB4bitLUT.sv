//XSleenaCore_RGB4bitLUT.sv
//Author: @RndMnkIII
//Date: 23/08/2022

//LUT data calculated from LT Spice simulation recreating
//ASO schematics
//normalized and hex converted using the following python script:
// from matplotlib import pyplot as plt
// import numpy


//              
// raw_values = numpy.array([5.000, 4.686, 4.373, 4.059, 3.775, 3.461, 3.148, 2.834, 2.166, 1.852, 1.539, 1.225, 0.941, 0.627, 0.314, 0.000])
// norm_values = []

// max_val = numpy.amax(raw_values)
// min_val = numpy.amin(raw_values)

// rango = max_val - min_val

// for valor in raw_values:
//     norm_val = (valor - min_val) / rango
//     norm_values.append(norm_val)

// byte_val = []

// for valor2 in norm_values:
//     print(hex(int(round(valor2 * 255.0))))
    
// plt.plot(norm_values)
// plt.show()
`default_nettype none
`timescale 1ns/1ns

module XSleenaCore_RGB4bitLUT( 
    input wire   [3:0] COL_4BIT, 
    output logic [7:0] COL_8BIT
);
    reg [11:0] angle; 
    
    always_comb begin
    case (COL_4BIT) 
        4'h0: COL_8BIT = 8'h00;
        4'h1: COL_8BIT = 8'h10;
        4'h2: COL_8BIT = 8'h20;
        4'h3: COL_8BIT = 8'h30;
        4'h4: COL_8BIT = 8'h3e;
        4'h5: COL_8BIT = 8'h4e;
        4'h6: COL_8BIT = 8'h5e;
        4'h7: COL_8BIT = 8'h6e;
        4'h8: COL_8BIT = 8'h91;
        4'h9: COL_8BIT = 8'ha1;
        4'hA: COL_8BIT = 8'hb1;
        4'hB: COL_8BIT = 8'hc1;
        4'hC: COL_8BIT = 8'hcf;
        4'hD: COL_8BIT = 8'hdf;
        4'hE: COL_8BIT = 8'hef;
        4'hF: COL_8BIT = 8'hff;
    endcase 
    end 
endmodule