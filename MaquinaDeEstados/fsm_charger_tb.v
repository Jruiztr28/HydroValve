`timescale 1ns / 1ps

module fsm_charger_tb;

    // 1. Declaración de Señales (Inputs como reg, Outputs como wire)
    reg clk;
    reg rpm_in_range;
    reg bat_charged;
    reg soft_reset;

    wire L_off;
    wire L_SEARCH;
    wire L_TRACK;
    wire pid_enable;
    wire servo_force_close;

    // 2. Instanciación de la FSM (Unit Under Test)
    fsm_charger uut (
        .clk(clk),
        .rpm_in_range(rpm_in_range),
        .bat_charged(bat_charged),
        .soft_reset(soft_reset),
        .L_off(L_off),
        .L_SEARCH(L_SEARCH),
        .L_TRACK(L_TRACK),
        .pid_enable(pid_enable),
        .servo_force_close(servo_force_close)
    );

    // 3. Generación del Reloj (25 MHz -> 40ns periodo)
    always #20 clk = ~clk; 

    // 4. Proceso de Prueba
    initial begin
        // A. Inicialización
        $dumpfile("fsm_charger_tb.vcd"); // Archivo para GTKWave
        $dumpvars(0, fsm_charger_tb);
        
        clk = 0;
        rpm_in_range = 0;
        bat_charged = 0;
        soft_reset = 0;

        $display("--- INICIO DE SIMULACION ---");
        $display("Tiempo | Estado | In: RPM / Bat | Out: PID / Servo");

        // B. Esperar el Power-On Reset (Tu lógica tiene un contador de 15 ciclos)
        $display("Esperando reset interno (Power-On)...");
        repeat(20) @(posedge clk); 
        
        // --- PRUEBA 1: ARRANQUE (OFF -> SEARCH) ---
        // La batería NO está cargada (bat=0), debería pasar a SEARCH
        $display("Test 1: Bateria descargada, sistema debe buscar.");
        bat_charged = 0;
        #100; // Esperar unos ciclos

        // --- PRUEBA 2: ENCONTRAR RPM (SEARCH -> TRACK) ---
        // Simulamos que el generador llega a 700 RPM
        $display("Test 2: RPM estables. Pasar a TRACK.");
        rpm_in_range = 1;
        #100;

        // --- PRUEBA 3: PERDIDA DE ESTABILIDAD (TRACK -> SEARCH) ---
        // El viento cae, RPM bajan
        $display("Test 3: RPM inestables. Volver a SEARCH.");
        rpm_in_range = 0;
        #100;

        // --- PRUEBA 4: RECUPERACION (SEARCH -> TRACK) ---
        $display("Test 4: RPM recuperadas. Volver a TRACK.");
        rpm_in_range = 1;
        #100;

        // --- PRUEBA 5: BATERIA LLENA (TRACK -> OFF) ---
        // El BMS dice "Ya basta"
        $display("Test 5: Bateria LLENA. Apagar sistema (OFF).");
        bat_charged = 1;
        #100;

        // --- PRUEBA 6: SEGURIDAD EN OFF ---
        // Aunque haya RPM, si la batería está llena, no debe encender
        $display("Test 6: Intento de arranque con bateria llena (Debe fallar).");
        rpm_in_range = 1; 
        #100;

        // --- PRUEBA 7: DESCARGA DE BATERIA (OFF -> SEARCH) ---
        // La batería se usó, voltaje cae
        $display("Test 7: Bateria se descarga. Reiniciar busqueda.");
        bat_charged = 0;
        #100;

        // --- PRUEBA 8: RESET MANUAL ---
        // Botonazo de emergencia
        $display("Test 8: Boton de Reset presionado.");
        soft_reset = 1;
        #100;
        soft_reset = 0;
        #100;

        $display("--- FIN DE SIMULACION ---");
        $finish;
    end

    // Monitor opcional para ver en consola
    always @(posedge clk) begin
        // Imprime cambios significativos
        // Lógica para detectar cambio de estado visualmente en consola
    end

endmodule
