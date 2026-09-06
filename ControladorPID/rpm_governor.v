module rpm_governor (
    input wire clk,             // RELOJ DE 25 MHz
    input wire reset,           
    
    input wire enable,          
    input wire force_close,     
    
    input wire [11:0] current_rpm, 
    input wire [11:0] target_rpm,  
    
    output reg pwm_out          
);

    // ==========================================
    // 1. CONFIGURACIÓN DE TIEMPOS (25 MHz)
    // ==========================================
    parameter PWM_PERIOD_TICKS = 500_000; // 20ms (50Hz)
    
    // --- CAMBIOS REALIZADOS AQUÍ ---
    // Rango restringido: 0 grados a 90 grados
    parameter SERVO_MIN_TICKS = 25_000;  // 1.0ms -> 0 grados (Cerrado)
    parameter SERVO_MAX_TICKS = 37_500;  // 1.5ms -> 90 grados (Medio abierto)
    
    // ==========================================
    // 2. PARÁMETROS PID
    // ==========================================
    // Kp: Al reducir el rango de movimiento (ahora solo tenemos 12,500 ticks 
    // de juego entre min y max), el sistema es más sensible.
    integer Kp = 5;  
    integer Ki = 2;
    integer Kd = 0; 

    // ==========================================
    // 3. VARIABLES INTERNAS
    // ==========================================
    reg [18:0] pwm_counter;      
    reg [18:0] pulse_width;      
    
    reg signed [15:0] error;
    reg signed [31:0] integral;  
    reg signed [15:0] prev_error;
    reg signed [31:0] pid_calc;  
    
    // ==========================================
    // 4. LÓGICA PRINCIPAL
    // ==========================================
    always @(posedge clk) begin
        if (reset) begin
            pwm_counter <= 0;
            pulse_width <= SERVO_MIN_TICKS;
            pwm_out <= 0;
            integral <= 0;
            prev_error <= 0;
        end else begin
            
            // --- A. Contador de Periodo PWM ---
            if (pwm_counter < PWM_PERIOD_TICKS - 1) begin
                pwm_counter <= pwm_counter + 1;
            end else begin
                pwm_counter <= 0; 
            end

            // --- B. Generación de Pulso ---
            if (pwm_counter < pulse_width)
                pwm_out <= 1;
            else
                pwm_out <= 0;

            // --- C. PID (Sincronizado) ---
            if (pwm_counter == 0) begin
                
                if (force_close) begin
                    pulse_width <= SERVO_MIN_TICKS; // Ir a 0 grados
                    integral <= 0;
                    prev_error <= 0;
                end 
                else if (enable) begin
                    // 1. Error
                    error = $signed({1'b0, target_rpm}) - $signed({1'b0, current_rpm});

                    // 2. Integral (Anti-Windup ajustado a los nuevos límites)
                    if (!((pulse_width >= SERVO_MAX_TICKS && error > 0) || 
                          (pulse_width <= SERVO_MIN_TICKS && error < 0))) begin
                        integral <= integral + error;
                    end

                    // 3. Cálculo PID
                    pid_calc = SERVO_MIN_TICKS + (Kp * error) + (Ki * integral) + (Kd * (error - prev_error));

                    // 4. Clamping (Límites físicos 0-90 grados)
                    if (pid_calc > SERVO_MAX_TICKS) 
                        pulse_width <= SERVO_MAX_TICKS; // No pasar de 37,500 (90 grados)
                    else if (pid_calc < SERVO_MIN_TICKS) 
                        pulse_width <= SERVO_MIN_TICKS; // No bajar de 25,000 (0 grados)
                    else 
                        pulse_width <= pid_calc[18:0]; 

                    prev_error <= error;
                end 
                else begin
                    pulse_width <= SERVO_MIN_TICKS; 
                    integral <= 0;
                end
            end
        end
    end

endmodule
