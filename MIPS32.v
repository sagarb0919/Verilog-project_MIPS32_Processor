module pipe_MIPS32 (clk1, clk2); 
 input clk1, clk2; // Two-phase clock 
 reg [31:0] PC, IF_ID_IR, IF_ID_NPC; 
 reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm; 
 reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type; 
 reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B; 
 reg EX_MEM_cond; 
 reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD; 
 reg [31:0] Reg [0:31]; // Register bank (32 x 32) 
 reg [31:0] Mem [0:1023]; // 1024 x 32 memory
  parameter ADD_op=6'b000000;
  parameter SUB_op=6'b000001;
  parameter AND_op=6'b000010;
  parameter OR_op=6'b000011;
  parameter SLT_op=6'b000100;
  parameter MUL_op=6'b00010;
  parameter HLT_op=6'b111111;
  parameter LW_op=6'b001000;
  parameter SW_op=6'b001001;
  parameter ADDI_op=6'b001010;
  parameter SUBI_op=6'b001011;
  parameter SLTI_op=6'b001100;
  parameter BNEQZ_op=6'b001101;
  parameter BEQZ_op=6'b001110;
  parameter RR_ALU_op=3'b000;
  parameter RM_ALU_op=3'b001;
  parameter LOAD_op=3'b010;
  parameter STORE_op=3'b011;
  parameter BRANCH_op=3'b100;
  parameter HALT_op=3'b101;
  reg HALTED; 
 // Set after HLT instruction is completed (in WB stage) 
 reg TAKEN_BRANCH; 
 // Required to disable instructions after branch

always @(posedge clk1) // IF Stage 
 if (HALTED == 0) 
 begin 
 if (((EX_MEM_IR[31:26] == BEQZ_op) && (EX_MEM_cond == 1)) || 
 ((EX_MEM_IR[31:26] == BNEQZ_op) && (EX_MEM_cond == 0))) 
 begin 
 IF_ID_IR <= #2 Mem[EX_MEM_ALUOut]; 
 TAKEN_BRANCH <= #2 1'b1; 
 IF_ID_NPC <= #2 EX_MEM_ALUOut + 1; 
 PC <= #2 EX_MEM_ALUOut + 1; 
 end
 else 
 begin 
 IF_ID_IR <= #2 Mem[PC]; 
 IF_ID_NPC <= #2 PC + 1; 
 PC <= #2 PC + 1; 
 end 
 end

always @(posedge clk2) // ID Stage 
 if (HALTED == 0) 
 begin 
 if (IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= 0; 
 else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]]; // "rs" 
 if (IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= 0; 
 else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]]; // "rt" 
 ID_EX_NPC <= #2 IF_ID_NPC; 
 ID_EX_IR <= #2 IF_ID_IR; 
 ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};

case (IF_ID_IR[31:26]) 
 ADD_op, SUB_op, AND_op, OR_op, SLT_op, MUL_op: ID_EX_type <= #2 RR_ALU_op; 
 ADDI_op, SUBI_op, SLTI_op: ID_EX_type <= #2 RM_ALU_op; 
 LW_op: ID_EX_type <= #2 LOAD_op; 
 SW_op: ID_EX_type <= #2 STORE_op; 
 BNEQZ_op, BEQZ_op: ID_EX_type <= #2 BRANCH_op; 
 HLT_op: ID_EX_type <= #2 HALT_op; 
 default: ID_EX_type <= #2 HALT_op; 
 // Invalid opcode
 endcase
 end

always @(posedge clk1) // EX Stage 
 if (HALTED == 0) 
 begin 
 EX_MEM_type <= #2 ID_EX_type; 
 EX_MEM_IR <= #2 ID_EX_IR; 
 TAKEN_BRANCH <= #2 0; 
 case (ID_EX_type) 
 RR_ALU_op: begin 
 case (ID_EX_IR[31:26]) // "opcode" 
 ADD_op: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B; 
 SUB_op: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B; 
 AND_op: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B; 
 OR_op: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B; 
 SLT_op: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B; 
 MUL_op: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B; 
 default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx; 
 endcase
 end

RM_ALU_op: begin 
 case (ID_EX_IR[31:26]) // "opcode" 
 ADDI_op: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; 
 SUBI_op: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm; 
 SLTI_op: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_Imm; 
 default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx; 
 endcase
 end

LOAD_op, STORE_op: 
 begin 
 EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm; 
 EX_MEM_B <= #2 ID_EX_B; 
 end
 BRANCH_op: begin 
 EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm; 
 EX_MEM_cond <= #2 (ID_EX_A == 0); 
 end 
 endcase
 end

always @(posedge clk2) // MEM Stage 
 if (HALTED == 0) 
 begin 
 MEM_WB_type <= EX_MEM_type; 
 MEM_WB_IR <= #2 EX_MEM_IR; 
 case (EX_MEM_type) 
 RR_ALU_op, RM_ALU_op: 
 MEM_WB_ALUOut <= #2 EX_MEM_ALUOut; 
 LOAD_op: MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut]; 
 STORE_op: if (TAKEN_BRANCH == 0) // Disable write 
 Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B; 
 endcase
 end

always @(posedge clk1) // WB Stage 
 begin 
 if (TAKEN_BRANCH == 0) // Disable write if branch taken 
 case (MEM_WB_type) 
 RR_ALU_op: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut; // "rd" 
 RM_ALU_op: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut; // "rt" 
 LOAD_op: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // "rt" 
 HALT_op: HALTED <= #2 1'b1; 
 endcase
 end 
endmodule