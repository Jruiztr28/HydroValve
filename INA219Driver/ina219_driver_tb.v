`timescale 1ns / 1ps

module ina219_driver_tb;

    // --- Señales del Testbench ---
    reg clk;
    reg reset;
    wire scl;
    wire sda; // ¡IMPORTANTE! SDA es 'wire' porque es bidireccional
    wire bat_charged;
    wire [15:0] voltage_mv;

    // Para simular la respuesta del esclavo
    reg sda_slave_drive; // 0 = El esclavo fuerza 0, 1 = El esclavo suelta (Z)

    // --- Instancia del DUT (Device Under Test) ---
    ina219_driver u_dut (
        .clk(clk),
        .reset(reset),
        .sda(sda),
        .scl(scl),
        .bat_charged(bat_charged),
        .voltage_mv(voltage_mv)
    );

    // --- Generación de Reloj (25 MHz) ---
    always #20 clk = ~clk;

    // --- Simulación de Resistencias PULL-UP ---
    // Esto le dice al simulador: si nadie fuerza la línea a 0, entonces es 1.
    pullup(sda);
    pullup(scl);

    // Conexión del driver del esclavo a la línea física SDA
    // Si sda_slave_drive es 0, forzamos 0. Si es 1, soltamos (Z).
    assign sda = (sda_slave_drive == 1'b0) ? 1'b0 : 1'bz;

    // ===============================================================
    // MODELO SIMPLIFICADO DEL ESCLAVO INA219
    // ===============================================================
    // Este bloque "espía" el bus I2C y responde cuando le toca.
    
    // Valor que queremos que el "sensor" devuelva.
    // Para 4150mV: (4150 / 4) = 1037.5 -> 1037 = 0x40D
    // El registro está desplazado 3 bits: 0x40D << 3 = 0x2068
    reg [15:0] simulated_reg_value = 16'h2068; 

    initial begin
        sda_slave_drive = 1; // Al principio, el esclavo no hace nada
        
        forever begin
            // 1. Esperar START condition (SDA baja mientras SCL es alto)
            @(negedge sda) if (scl) begin
                //$display("T=%0t | I2C Slave: START detectado", $time);

                // 2. Esperar 8 ciclos de SCL (Dirección + R/W)
                repeat(8) @(posedge scl); 

                // 3. Enviar ACK (Poner SDA a 0 durante el ciclo 9)
                @(negedge scl) sda_slave_drive = 0;
                @(negedge scl) sda_slave_drive = 1; // Soltar

                // (Aquí simplificamos: asumimos que el driver siempre hace lo correcto
                //  y no chequeamos la dirección ni si es lectura/escritura en la 1ra fase)

                // 4. Esperar 8 ciclos de SCL (Puntero de Registro)
                repeat(8) @(posedge scl);

                // 5. Enviar ACK (por el byte del puntero)
                @(negedge scl) sda_slave_drive = 0;
                @(negedge scl) sda_slave_drive = 1;

                // --- AHORA VIENE LA LECTURA ---
                // Esperamos el Repeated Start y la Dirección+Read...
                
                // 6. Esperar Repeated START
                @(negedge sda) if (scl); 
                
                // 7. Esperar 8 ciclos (Dirección + Read)
                repeat(8) @(posedge scl);

                // 8. Enviar ACK
                @(negedge scl) sda_slave_drive = 0;
                @(negedge scl) sda_slave_drive = 1;

                // 9. ENVIAR BYTE ALTO (MSB) - simulated_reg_value[15:8]
                send_byte(simulated_reg_value[15:8]);

                // 10. Esperar ACK del Master
                @(negedge scl); // El master pone 0 en SDA
                @(negedge scl); // El master suelta

                // 11. ENVIAR BYTE BAJO (LSB) - simulated_reg_value[7:0]
                send_byte(simulated_reg_value[7:0]);

                // 12. Esperar NACK del Master (Fin de lectura)
                @(negedge scl); 
                //$display("T=%0t | I2C Slave: Datos enviados. Fin transacción.", $time);
            end
        end
    end

    // Tarea auxiliar para que el esclavo envíe un byte bit a bit
    task send_byte(input [7:0] data);
        integer i;
        begin
            for (i=7; i>=0; i=i-1) begin
                @(negedge scl) sda_slave_drive = data[i];
            end
            @(negedge scl) sda_slave_drive = 1; // Soltar al terminar
        end
    endtask

    // ===============================================================
    // SECUENCIA DE PRUEBA PRINCIPAL
    // ===============================================================
    initial begin
        $dumpfile("ina219_driver_tb.vcd");
        $dumpvars(0, ina219_driver_tb);

        // Inicialización
        clk = 0;
        reset = 1;
        
        // Valor inicial: 3.7V (3700mV) -> NO CARGADA
        // 3700 / 4 = 925 = 0x39D. Desplazado: 0x39D << 3 = 0x1CE8
        simulated_reg_value = 16'h1CE8;

        $display("=== INICIO SIMULACIÓN INA219 ===");
        #1000 reset = 0; // Soltar reset

        // --- PRUEBA 1: Voltaje Bajo (3.7V) ---
        $display("--- Prueba 1: Voltaje 3700mV (Esperado: bat_charged = 0) ---");
        
        // Esperar suficiente para una transacción completa y el timer de espera
        // Una transacción toma ~200us. El timer espera más. Demos 5ms.
        #5000000; 

        if (bat_charged == 0 && voltage_mv == 3700)
            $display("SUCCESS: Batería detectada como NO cargada (Volts: %0d mV)", voltage_mv);
        else
            $display("ERROR: Fallo en detección baja. charged=%b, volts=%0d", bat_charged, voltage_mv);


        // --- PRUEBA 2: Voltaje Alto (4.15V) ---
        // Cambiamos el valor que "devuelve" el sensor simulado
        // 4150mV -> 0x2068
        simulated_reg_value = 16'h2068; 
        $display("\n--- Prueba 2: Voltaje 4150mV (Esperado: bat_charged = 1) ---");

        // Esperar otra transacción
        #5000000;

        if (bat_charged == 1 && voltage_mv == 4148) // 4148 por pérdida de precisión de bits
            $display("SUCCESS: Batería detectada como CARGADA (Volts: %0d mV)", voltage_mv);
        else
            $display("ERROR: Fallo en detección alta. charged=%b, volts=%0d", bat_charged, voltage_mv);


        $display("\n=== FIN SIMULACIÓN ===");
        $finish;
    end

endmodule
