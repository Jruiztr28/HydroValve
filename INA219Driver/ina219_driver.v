module ina219_driver (
    input wire clk,             // 25 MHz
    input wire reset,
    inout wire sda,             
    output wire scl,            
    output reg bat_charged,     
    output reg [15:0] voltage_mv // 16 bits para ver el valor real sin cortes
);

    parameter BAT_FULL_THRESHOLD_MV = 4120; 
    parameter [6:0] I2C_ADDR = 7'h40;
    parameter CLK_DIV_MAX = 250; 

    // Estados de la FSM del I2C (¡NO confundir con la FSM del cargador!)
    localparam S_IDLE       = 0;
    localparam S_START1     = 1; 
    localparam S_ADDR_WR    = 2; 
    localparam S_ACK1       = 3;
    localparam S_REG_PTR    = 4; 
    localparam S_ACK2       = 5;
    localparam S_START2     = 6; 
    localparam S_ADDR_RD    = 7; 
    localparam S_ACK3       = 8;
    localparam S_READ_MSB   = 9; 
    localparam S_ACK_M      = 10;
    localparam S_READ_LSB   = 11; // Hex: B
    localparam S_NACK_M     = 12;
    localparam S_STOP       = 13;
    localparam S_WAIT       = 14; // Hex: E

    reg [3:0] state = S_IDLE;
    reg [7:0] bit_cnt;          
    reg [7:0] shift_reg;        
    reg [15:0] raw_data;        
    
    reg [8:0] clk_cnt = 0;
    reg i2c_tick;               
    reg scl_reg = 1;
    
    // VARIABLE CLAVE: Guardará el valor de SDA en el momento seguro
    reg sda_sampled;            

    // --- GENERADOR DE RELOJ Y SAMPLING ---
    always @(posedge clk) begin
        if (reset) begin
            clk_cnt <= 0;
            i2c_tick <= 0;
            scl_reg <= 1;
        end else begin
            if (clk_cnt >= CLK_DIV_MAX - 1) begin
                clk_cnt <= 0;
                i2c_tick <= 1; 
            end else begin
                clk_cnt <= clk_cnt + 1;
                i2c_tick <= 0;
            end

            // SCL: Alto primera mitad, Bajo segunda mitad
            if (clk_cnt < CLK_DIV_MAX/2) scl_reg <= 1;
            else scl_reg <= 0;
                
            // --- FIX: SAMPLING ---
            // Capturamos SDA exactamente en la mitad del nivel ALTO de SCL.
            // Esto evita leer basura cuando la señal está cambiando.
            if (clk_cnt == CLK_DIV_MAX/4) begin
                sda_sampled <= sda;
            end
        end
    end

    reg sda_out = 1;            
    reg sda_en = 0;             
    
    assign sda = (sda_en && !sda_out) ? 1'b0 : 1'bz;
    assign scl = scl_reg;

    reg [17:0] wait_timer; 
    reg [31:0] calc_temp; // 32 bits para cálculo matemático seguro

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            bat_charged <= 0;
            sda_en <= 0;
            sda_out <= 1;
            wait_timer <= 0;
            voltage_mv <= 0;
            raw_data <= 0;
        end else if (i2c_tick) begin 
            case (state)
                S_IDLE: begin
                    wait_timer <= 0;
                    state <= S_START1;
                    sda_out <= 1; sda_en <= 1; 
                end
                // ... (Estados de escritura igual que antes) ...
                S_START1: begin sda_out <= 0; sda_en <= 1; state <= S_ADDR_WR; bit_cnt <= 7; shift_reg <= {I2C_ADDR, 1'b0}; end
                S_ADDR_WR: begin sda_out <= shift_reg[7]; shift_reg <= {shift_reg[6:0], 1'b0}; if (bit_cnt == 0) begin state <= S_ACK1; sda_en <= 0; end else bit_cnt <= bit_cnt - 1; end
                S_ACK1: begin state <= S_REG_PTR; bit_cnt <= 7; shift_reg <= 8'h02; sda_en <= 1; end
                S_REG_PTR: begin sda_out <= shift_reg[7]; shift_reg <= {shift_reg[6:0], 1'b0}; if (bit_cnt == 0) begin state <= S_ACK2; sda_en <= 0; end else bit_cnt <= bit_cnt - 1; end
                S_ACK2: begin state <= S_START2; sda_out <= 1; sda_en <= 1; end
                S_START2: begin sda_out <= 0; state <= S_ADDR_RD; bit_cnt <= 7; shift_reg <= {I2C_ADDR, 1'b1}; end
                S_ADDR_RD: begin sda_out <= shift_reg[7]; shift_reg <= {shift_reg[6:0], 1'b0}; if (bit_cnt == 0) begin state <= S_ACK3; sda_en <= 0; end else bit_cnt <= bit_cnt - 1; end
                S_ACK3: begin state <= S_READ_MSB; bit_cnt <= 7; sda_en <= 0; end

                // ... LECTURA USANDO MUESTREO SEGURO ...
                S_READ_MSB: begin
                    raw_data[bit_cnt + 8] <= sda_sampled; // Usamos sda_sampled!
                    if (bit_cnt == 0) begin state <= S_ACK_M; sda_out <= 0; sda_en <= 1; end else bit_cnt <= bit_cnt - 1;
                end
                S_ACK_M: begin state <= S_READ_LSB; bit_cnt <= 7; sda_en <= 0; end
                S_READ_LSB: begin
                    raw_data[bit_cnt] <= sda_sampled; // Usamos sda_sampled!
                    if (bit_cnt == 0) begin state <= S_NACK_M; sda_out <= 1; sda_en <= 1; end else bit_cnt <= bit_cnt - 1;
                end
                S_NACK_M: begin state <= S_STOP; sda_out <= 0; end
                S_STOP: begin sda_out <= 1; state <= S_WAIT; end
                
                S_WAIT: begin
                    // Cálculo completo
                    calc_temp = (raw_data >> 3) * 4;
                    voltage_mv <= calc_temp[15:0];
                    
                    if (calc_temp >= BAT_FULL_THRESHOLD_MV) bat_charged <= 1;
                    else bat_charged <= 0;

                    if (wait_timer > 50000) state <= S_IDLE;
                    else wait_timer <= wait_timer + 1;
                end
            endcase
        end
    end
endmodule
