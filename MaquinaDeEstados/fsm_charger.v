module fsm_charger (
    input wire clk,
    // No usamos rst_n físico global, usamos un reset interno + soft_reset
    
    // Entradas (Mapeadas a J1)
    input wire rpm_in_range,            // Sensor RPM
    input wire bat_charged,            // Sensor Batería
    input wire soft_reset,   // Botón externo
    
    // Salidas (Mapeadas a J2-J4)
    output reg L_off,
    output reg L_SEARCH,
    output reg L_TRACK,
    output reg pid_enable,
    output reg servo_force_close
);

    // --- CONFIGURACIÓN DE ESTADOS ---
    parameter S_OFF    = 2'b00;
    parameter S_SEARCH = 2'b01;
    parameter S_TRACK  = 2'b10;

    reg [1:0] current_state = S_OFF;
    reg [1:0] next_state;

    // --- GENERADOR DE RESET INTERNO (POWER-ON RESET) ---
    // Esto asegura que la FPGA inicie en OFF al conectarla
    reg [3:0] reset_count = 0;
    reg internal_reset_active = 1;

    always @(posedge clk) begin
        if (reset_count < 4'd15) begin
            reset_count <= reset_count + 1'b1;
            internal_reset_active <= 1; // Reset activo
        end else begin
            internal_reset_active <= 0; // Soltar reset
        end
    end

    // Señal maestra de reset (Interno O Botón externo)
    wire system_reset = internal_reset_active || soft_reset;

    // --- 1. MEMORIA DE ESTADO ---
    always @(posedge clk) begin
        if (system_reset) begin
            current_state <= S_OFF;
        end else begin
            current_state <= next_state;
        end
    end

    // --- 2. LÓGICA DE SIGUIENTE ESTADO ---
    always @(*) begin
        next_state = current_state; // Valor por defecto

        case (current_state)
            S_OFF: begin
                // PRIORIDAD: Si hay reset o batería llena, nos quedamos en OFF.
                // Si la batería NO está llena (!bat_charged) y no hay reset, pasamos a SEARCH.
                // NOTA: Ignoramos 'r' aquí (seguridad).
                if (bat_charged)      next_state = S_OFF;
                else        next_state = S_SEARCH;
            end

            S_SEARCH: begin
                if (bat_charged)      next_state = S_OFF;   // Batería llena -> Apagar
                else if (rpm_in_range) next_state = S_TRACK; // RPM Estables -> TRACK
                else        next_state = S_SEARCH;// Si no, seguir buscando
            end

            S_TRACK: begin
                if (bat_charged)      next_state = S_OFF;    // Batería llena -> Apagar
                else if (!rpm_in_range) next_state = S_SEARCH; // Perdimos RPM -> Buscar
                else        next_state = S_TRACK;  // Todo OK -> Mantener
            end
            
            default: next_state = S_OFF;
        endcase
    end

    // --- 3. LÓGICA DE SALIDA ---
    always @(*) begin
        // Valores por defecto (Seguridad)
        L_off = 0; L_SEARCH = 0; L_TRACK = 0;
        pid_enable = 0; servo_force_close = 1; 

        case (current_state)
            S_OFF: begin
                L_off             = 1;
                L_SEARCH          = 0;
                L_TRACK           = 0;
                pid_enable        = 0;
                servo_force_close = 1; // Servo cerrado forzosamente
            end

            S_SEARCH: begin
                L_off             = 0;
                L_SEARCH          = 1;
                L_TRACK           = 0;
                pid_enable        = 1; // PID activo para buscar estabilidad
                servo_force_close = 0;
            end

            S_TRACK: begin
                L_off             = 0;
                L_SEARCH          = 0;
                L_TRACK           = 1;
                pid_enable        = 1; // PID activo para mantener (segun tu corrección)
                servo_force_close = 0;
            end
        endcase
    end

endmodule