module rpm_meter (
    input wire clk,             // Reloj de 25 MHz
    input wire sensor_pulse,    // Entrada del sensor Hall (Pin C1)
    
    output reg [11:0] rpm_value, // Valor RPM calculado (Entero)
    
    // CAMBIO: Ahora se llama igual que en la FSM para evitar confusión
    output reg rpm_in_range      
);

    // --- CONFIGURACIÓN ---
    // Ajusta estos valores según lo que consideres "estable"
    parameter RPM_MIN_TARGET = 680;
    parameter RPM_MAX_TARGET = 720;

    // Constante: 25,000,000 * 60 = 1,500,000,000
    parameter [31:0] NUMERATOR = 32'd1500000000;

    // Timeout: 1 segundo (25M ciclos)
    parameter TIMEOUT_CYCLES = 32'd25000000;

    reg [31:0] cycle_counter = 0; 
    reg last_sensor_state = 0;    

    always @(posedge clk) begin
        // 1. DETECTOR DE FLANCO DE SUBIDA
        if (sensor_pulse == 1 && last_sensor_state == 0) begin
            
            // Filtro de ruido
            if (cycle_counter > 1000) begin
                // RPM = Constante / Tiempo
                rpm_value <= NUMERATOR / cycle_counter;
            end
            
            cycle_counter <= 0;
            
        end else begin
            // 2. SI NO HAY PULSO, CONTAMOS TIEMPO
            if (cycle_counter < TIMEOUT_CYCLES) begin
                cycle_counter <= cycle_counter + 1;
            end else begin
                // Timeout -> Motor parado
                rpm_value <= 0;
            end
        end

        last_sensor_state <= sensor_pulse;

        // 3. VERIFICACIÓN DE RANGO (Actualizado con el nuevo nombre)
        if (rpm_value >= RPM_MIN_TARGET && rpm_value <= RPM_MAX_TARGET) begin
            rpm_in_range <= 1; // ¡Nombre coincidente!
        end else begin
            rpm_in_range <= 0;
        end
    end

endmodule
