`timescale 1ns / 1ps

module rpm_governor_tb; // Asegúrate que esto coincida con el nombre del archivo

    // ... (Definición de registros y cables igual que antes) ...
    reg clk;
    reg reset;
    reg enable;
    reg force_close;
    reg [11:0] current_rpm;
    reg [11:0] target_rpm;
    wire pwm_out;

    real pulse_width_ms;
    time t_start, t_end;

    rpm_governor u_dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .force_close(force_close),
        .current_rpm(current_rpm),
        .target_rpm(target_rpm),
        .pwm_out(pwm_out)
    );

    always #20 clk = ~clk;

    // ... (Bloque de medición de ancho de pulso igual que antes) ...
    always @(posedge pwm_out) t_start = $time;
    always @(negedge pwm_out) begin
        t_end = $time;
        pulse_width_ms = (t_end - t_start) / 1000000.0; 
        $display("Tiempo: %0t ns | RPM: %0d | Target: %0d | PWM: %0.3f ms", $time, current_rpm, target_rpm, pulse_width_ms);
    end

    // --- AQUÍ ESTÁ EL CAMBIO IMPORTANTE ---
    initial begin
        // Esto crea el archivo que GTKWave necesita leer
        $dumpfile("rpm_governor_tb.vcd"); 
        $dumpvars(0, rpm_governor_tb);    
    end
    // -------------------------------------

    initial begin
        // Inicialización
        clk = 0;
        reset = 1;
        enable = 0;
        force_close = 0;
        current_rpm = 0;
        target_rpm = 700;

        // ... resto de tu secuencia de prueba ...
        #100000; 
        reset = 0;
        
        // (Tu código de prueba sigue aquí igual...)
        // CASO 1...
        force_close = 1; enable = 1; current_rpm = 800;
        repeat(2) @(posedge pwm_out); #20000000;

        // CASO 2...
        force_close = 0; current_rpm = 0;
        repeat(5) @(posedge pwm_out); #20000000;

        // CASO 3...
        current_rpm = 850; 
        repeat(5) @(posedge pwm_out); #20000000;

        // CASO 4...
        current_rpm = 700;
        repeat(3) @(posedge pwm_out); #20000000;

        $finish;
    end

endmodule
