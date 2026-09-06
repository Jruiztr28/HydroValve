`timescale 1ns / 1ps

module rpm_meter_tb;

    reg clk;
    reg sensor_pulse;
    wire [11:0] rpm_value;
    
    // Wire para recibir la señal del módulo
    wire rpm_in_range;

    // Instancia del módulo (Unit Under Test)
    rpm_meter uut (
        .clk(clk),
        .sensor_pulse(sensor_pulse),
        .rpm_value(rpm_value),
        
        // --- CORRECCIÓN AQUÍ ---
        // El puerto del módulo se llama .rpm_in_range
        // El cable del testbench se llama (rpm_in_range)
        .rpm_in_range(rpm_in_range) 
    );

    // Generar reloj de 25 MHz (Periodo 40ns)
    always #20 clk = ~clk;

    // Tarea auxiliar para simular una vuelta completa del motor
    task simulate_rotation;
        input [31:0] target_rpm;
        reg [31:0] period_ns;
        begin
            // Calcular el periodo en nanosegundos para esas RPM
            // 60,000,000,000 ns / RPM
            period_ns = 60000000000 / target_rpm;

            // Simular el pulso del imán (1ms)
            sensor_pulse = 1;
            #1000000; 
            sensor_pulse = 0;
            
            // Esperar el resto de la vuelta
            #(period_ns - 1000000);
        end
    endtask

    initial begin
        $dumpfile("rpm_meter_tb.vcd");
        $dumpvars(0, rpm_meter_tb);

        clk = 0;
        sensor_pulse = 0;

        $display("Iniciando simulacion de RPM...");
        
        // Esperar un poco al inicio
        #1000000; 

        // --- PRUEBA 1: 300 RPM (Lento, Fuera de rango) ---
        $display("Simulando 300 RPM...");
        simulate_rotation(300); // Primera vuelta (inicia cronómetro)
        simulate_rotation(300); // Segunda vuelta (calcula valor)
        #100; // Dar tiempo para actualizar
        $display("RPM Medidas: %d, En Rango: %b", rpm_value, rpm_in_range);

        // --- PRUEBA 2: 700 RPM (Objetivo, En rango) ---
        $display("Simulando 700 RPM...");
        simulate_rotation(700);
        simulate_rotation(700);
        #100;
        $display("RPM Medidas: %d, En Rango: %b", rpm_value, rpm_in_range);

        // --- PRUEBA 3: 1000 RPM (Rápido, Fuera de rango) ---
        $display("Simulando 1000 RPM...");
        simulate_rotation(1000);
        simulate_rotation(1000);
        #100;
        $display("RPM Medidas: %d, En Rango: %b", rpm_value, rpm_in_range);

        // --- PRUEBA 4: PARADA DE MOTOR (Timeout) ---
        $display("Simulando parada de motor...");
        sensor_pulse = 0;
        // Esperamos mas de 1 segundo (25M ciclos * 40ns = 1s)
        #1100000000; 
        $display("RPM tras espera: %d", rpm_value);

        $finish;
    end

endmodule
