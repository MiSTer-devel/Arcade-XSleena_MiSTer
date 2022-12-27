//@RndMnkIII 19/11/2022
//Based on the work of: Martin Donlon @wickerwaka for MiSTer Irem M72 Core. 2022
//Define where the ROM areas going to be stored and the base address for SDRAM space
`define CPU_OVERCLOCK_HACK
package xain_pkg;

    typedef struct packed {
        bit [24:0] base_addr;
        bit reorder_16;
        bit [5:0] bram_cs;
    } region_t;

//CPU OVERCLOCK HACK
`ifdef CPU_OVERCLOCK_HACK
    parameter region_t REGION_MAIN_CPU_ROM = '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b000001 }; //64Kb: 32Kb Upper ROM at 0x8000 + 16Kb x Two Banks at 0x4000
    parameter region_t REGION_SUB_CPU_ROM =  '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b000010 }; //64Kb: 32Kb Upper ROM at 0x8000 + 16Kb x Two Banks at 0x4000
    parameter region_t REGION_SND_CPU_ROM =  '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b000100 }; //32Kb
    parameter region_t REGION_ROM_MAP =      '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b001000 }; //32Kb
    parameter region_t REGION_PRIO_ROM =     '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b010000 }; //256Bytes
    parameter region_t REGION_MCU_ROM =      '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b100000 }; //2Kb
    //Reserve 0x0-0x3ffff for future CPU, MAP, MCU ROM implementations also into SDRAM
    parameter region_t REGION_ROM_BACK1 =    '{ base_addr:'h004_0000, reorder_16:0, bram_cs:6'b000000 }; //256Kb
    parameter region_t REGION_ROM_BACK2 =    '{ base_addr:'h008_0000, reorder_16:0, bram_cs:6'b000000 }; //192Kb, leave 64Kb gap
    parameter region_t REGION_ROM_OBJ =      '{ base_addr:'h00C_0000, reorder_16:0, bram_cs:6'b000000 }; //256Kb
`else
    parameter region_t REGION_SND_CPU_ROM =  '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b000100 }; //32Kb
    parameter region_t REGION_ROM_MAP =      '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b001000 }; //32Kb
    parameter region_t REGION_PRIO_ROM =     '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b010000 }; //256Bytes
    parameter region_t REGION_MCU_ROM =      '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b100000 }; //2Kb
    //Reserve 0x0-0x3ffff for future CPU, MAP, MCU ROM implementations also into SDRAM
    parameter region_t REGION_MAIN_CPU_ROM = '{ base_addr:'h000_0000, reorder_16:0, bram_cs:6'b000000 }; //64Kb: 32Kb Upper ROM at 0x8000 + 16Kb x Two Banks at 0x4000
    parameter region_t REGION_SUB_CPU_ROM =  '{ base_addr:'h001_0000, reorder_16:0, bram_cs:6'b000000 }; //64Kb: 32Kb Upper ROM at 0x8000 + 16Kb x Two Banks at 0x4000
    parameter region_t REGION_ROM_BACK1 =    '{ base_addr:'h004_0000, reorder_16:0, bram_cs:6'b000000 }; //256Kb
    parameter region_t REGION_ROM_BACK2 =    '{ base_addr:'h008_0000, reorder_16:0, bram_cs:6'b000000 }; //192Kb, leave 64Kb gap
    parameter region_t REGION_ROM_OBJ =      '{ base_addr:'h00C_0000, reorder_16:0, bram_cs:6'b000000 }; //256Kb
`endif
    parameter region_t LOAD_REGIONS[9] = '{
        REGION_MAIN_CPU_ROM,
        REGION_SUB_CPU_ROM,
        REGION_SND_CPU_ROM,
        REGION_ROM_MAP,
        REGION_PRIO_ROM,
        REGION_MCU_ROM,
        REGION_ROM_BACK1,
        REGION_ROM_BACK2,
        REGION_ROM_OBJ
    };

    //parameter region_t REGION_SHARED_RAM = '{ 'h400000, 0, 5'b00000 };

    typedef enum bit[1:0] {
        VIDEO_57HZ = 2'd0,
        VIDEO_60HZ = 2'd1
    } video_timing_t;
endpackage