`include "../utils/defines2.vh"
`include "../utils/control_signal_define.vh"
`timescale 1ns / 1ps
`define INST_SET_BRANCH `BEQ, `BNE, `BGTZ, `BLEZ, `BG_EXT_INST
`define INST_SET_IMMEDIATE `ADDI, `ANDI, `LUI, `ORI, `XORI, `ADDIU, `SLTI, `SLTIU

module maindec(
    input [5:0] op,
    input [4:0] rs,
    input [4:0] rt,
    input [4:0] rd,
    input [5:0] funct,
    output reg regwrite,
    output reg regdst,
    output reg alusrc,
    output reg branch,
    output reg bal,
    output reg jal,
    output reg jr,
    output reg [3:0] memWrite,
    output reg [3:0] memReadWidth,
    output reg memLoadIsSign,
    output reg memToReg,
    output reg jump,
    output reg hilowrite,
    output reg regToHilo_hi,regToHilo_lo,
    output reg mdToHilo,
    output reg mulOrdiv,
    output reg mdIsSign,
    output reg hiloToReg,
    output reg hilosrc
    );

    // regwrite
    always @(*) begin
        case(op)
            `R_TYPE: begin
                case(funct)
                    `ADD,       `ADDU,
                    `SUB,       `SUBU,
                    `SLT,       `SLTU,
                    `AND,       `NOR,
                    `OR,        `XOR,
                    `SLLV,      `SLL,
                    `SRAV,      `SRA,
                    `SRLV,      `SRL,
                    `JALR,      `MFHI,
                    `MFLO:      regwrite = `SET_ON;
                    default:    regwrite = `SET_OFF;
                endcase
            end

            `ADDI,      `ADDIU,
            `ADDIU,     `SLTI,
            `SLTIU,     `ANDI,
            `LUI,       `ORI,
            `XORI,      `BNE:   regwrite = `SET_ON;

            `BG_EXT_INST: begin
                case(rt)
                    `BGEZAL,    `BLTZAL:    regwrite = `SET_ON;
                    default:                regwrite = `SET_OFF;
                endcase
            end

            `JAL,       `LB,
            `LBU,       `LH,
            `LHU,       `LW:    regwrite = `SET_ON;

            default:            regwrite = `SET_OFF;
        endcase
    end
    // regdst
    always @(*) begin
        case(op)
            `R_TYPE: regdst = `regdst_RD;
            default: regdst = `regdst_RT;
        endcase
    end
    // alusrc
    always @(*) begin
        case(op)
            `ADDI,      `ADDIU,
            `SLTI,      `SLTIU,
            `ANDI,      `LUI,
            `ORI,       `XORI,
            `LB,        `LBU,
            `LH,        `LHU,
            `LW,        `SB,
            `SH,        `SW:    alusrc = `alusrc_IMM;
            default:            alusrc = `alusrc_RD;
        endcase
    end
    // branch & bal
    always @(*) begin
        case(op)
            `BEQ,       `BNE,
            `BGTZ,      `BLEZ:          begin branch = `SET_ON;  bal = `SET_OFF; end

            `BG_EXT_INST: begin
                case(rt)
                `BGEZ,      `BLTZ:      begin branch = `SET_ON;  bal = `SET_OFF; end
                `BGEZAL,    `BLTZAL:    begin branch = `SET_ON;  bal = `SET_ON;  end
                default:                begin branch = `SET_OFF; bal = `SET_OFF; end
                endcase
            end
            default:                    begin branch = `SET_OFF; bal = `SET_OFF; end
        endcase
    end
    // memWrite
    always @(*) begin
        case(op)
            `SW:            memWrite = `memWrite_WORD;
            `SH:            memWrite = `memWrite_HALF;
            `SB:            memWrite = `memWrite_BYTE;
            default:        memWrite = `memWrite_OFF;
        endcase
    end
    // memReadWidth 决定LW/LH/LB时，读取的数据宽度（注意，读取时memWrite仍然为全0。是读取整字之后再根据宽度取出想要的部分）
    always @(*) begin
        case(op)
            `LW:            memReadWidth = `memReadWidth_WORD;
            `LH:            memReadWidth = `memReadWidth_HALF;
            `LHU:           memReadWidth = `memReadWidth_HALF;
            `LB:            memReadWidth = `memReadWidth_BYTE;
            `LBU:           memReadWidth = `memReadWidth_BYTE;
            default:        memReadWidth = `memReadWidth_OFF;
        endcase
    end
    // memLoadIsSign - 判断Load指令是否是有符号的（如LHU和LBU）
    always @(*) begin
        case(op)
            `LBU,       `LHU:     memLoadIsSign = `SET_OFF;
            default:              memLoadIsSign = `SET_ON;
        endcase
    end
    // memToReg
    always @(*) begin
        case(op)
            `LW,        `LB,
            `LBU,       `LH,
            `LHU:           memToReg = `memToReg_MEM;
            default:        memToReg = `memToReg_ALU;
        endcase
    end
    // jump && jal && jr
    always @(*) begin
        case(op)
            `J:     begin jump = `SET_ON; jal = `SET_OFF; jr = `SET_OFF; end
            `JAL:   begin jump = `SET_ON; jal = `SET_ON; jr = `SET_OFF; end
            `R_TYPE: begin
                case(funct)
                    `JR:        begin jump = `SET_OFF; jal = `SET_OFF; jr = `SET_ON; end
                    `JALR :     begin jump = `SET_OFF; jal = `SET_ON; jr = `SET_ON; end
                    default:    begin jump = `SET_OFF; jal = `SET_OFF; jr = `SET_OFF; end
                endcase
            end
            default: begin jump = `SET_OFF; jal = `SET_OFF; jr = `SET_OFF; end
        endcase
    end

    // hilowrite - 是否要写hilo_reg
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MTHI,`MTLO,`MULT,`MULTU,`DIV,`DIVU:    hilowrite = `SET_ON;
                default:        hilowrite = `SET_OFF;
            endcase
            default:            hilowrite = `SET_OFF;
        endcase
    end
    // regToHilo_hi - 是否将寄存器rs的值写入HI
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MTHI:          regToHilo_hi =   `SET_ON;
                default:        regToHilo_hi =   `SET_OFF;
            endcase
            default:            regToHilo_hi = `SET_OFF;
        endcase
    end
    // regToHilo_lo - 是否将寄存器rs的值写入LO
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MTLO:          regToHilo_lo =   `SET_ON;
                default:        regToHilo_lo =   `SET_OFF;
            endcase
            default:            regToHilo_lo = `SET_OFF;
        endcase
    end
    // mdToHilo - 是否将乘法器/除法器的结果写入hilo_reg
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MULT,`MULTU,`DIV,`DIVU: mdToHilo = `SET_ON;
                default: mdToHilo = `SET_OFF;
            endcase
            default: mdToHilo = `SET_OFF;
        endcase
    end
    // mulOrdiv - 写入hilo_reg的是乘法结果还是除法结果
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MULT,`MULTU: mulOrdiv = `mulOrdiv_MUL;
                default: mulOrdiv = `mulOrdiv_DIV;
            endcase
            default: mulOrdiv = `SET_OFF;
        endcase
    end
    // mdIsSign - 判断乘除法是否是有符号的
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `ADD,`SUB,`MULT,`DIV,`SLT: mdIsSign = `SET_ON;
                default: mdIsSign = `SET_OFF;
            endcase
            `ADDI,`SLTI: mdIsSign = `SET_ON;
            default: mdIsSign = `SET_ON;
        endcase
    end
    // hiloToReg - 是否将HI/LO的值写入rd
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MFHI,`MFLO:    hiloToReg = `SET_ON;
                default:        hiloToReg = `SET_OFF;
            endcase
            default:            hiloToReg = `SET_OFF;
        endcase
    end
    // hilosrc - 写入rd的值是来自于HI还是LO
    always @(*) begin
        case(op)
            `R_TYPE:case(funct)
                `MFHI:          hilosrc = `hilosrc_HI;
                default:        hilosrc = `hilosrc_LO;
            endcase
            default:            hilosrc = `SET_OFF;
        endcase
    end

    // //顺序按表5
    // always@(*)begin
    //     case(op)
    //         6'b000000:begin     //R-type
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b1100000;
    //             aluop=2'b10;
    //         end
    //         6'b100011:begin     //lw
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b1010010;
    //             aluop=2'b00;
    //         end
    //         6'b101011:begin     //sw
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b0010100;
    //             aluop=2'b00;
    //         end
    //         6'b000100:begin     //beq
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b0001000;
    //             aluop=2'b01;
    //         end
    //         6'b001000:begin     //I-type
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b1010000;
    //             aluop=2'b00;
    //         end
    //         6'b000010:begin     //jump
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'b0000001;
    //             aluop=2'b00;
    //         end
    //         default:begin
    //             {regwrite,regdst,alusrc,branch,memWrite,memToReg,jump}=7'd0;
    //             aluop=2'b00;
    //         end
    //     endcase
    // end
endmodule
