# Digital Control System for Smart Battery Charging with Hydroelectric Power Generation

This project implements a digital control system developed in **Verilog** for safe and efficient charging of lithium-ion batteries (3.7 V) using a micro-hydroelectric generation prototype. The system regulates water flow to a Pelton turbine using a servomotor controlled by a PI governor, maintaining generator speed within an optimal range.

---

## Authors

- **Juan Diego Ruiz Trejo**
- **Nicolás Moreno Molina**

---

## Key Features

- **Finite State Machine (FSM):** Controls operational modes (`OFF`, `SEARCH`, `TRACK`), ensuring safe transitions based on battery state and turbine speed.
- **PI Governor / PWM Control:** Regulates servovalve position using an adaptive PWM signal to adjust water flow according to generator RPM.
- **Battery Monitoring & Telemetry:** Integrates the INA219 sensor driver via I2C protocol to measure voltage and detect full charge status.
- **Speed Measurement (RPM):** Measures turbine rotation frequency using a Hall effect sensor.
- **Modular Verilog Design:** Structured into independent modules verified through GTKWave simulation.

---

## Finite State Machine (FSM)

Overall system control is governed by an FSM with three main states:

1. **`OFF` (`00`):** Standby or inactive state. The servovalve is forced fully closed (`servo_force_close = 1`). Indicator: **Red LED**.
2. **`SEARCH` (`01`):** Search state. The valve adjusts water flow to bring turbine speed into the target range. Indicator: **Yellow LED**.
3. **`TRACK` (`10`):** Optimal operation state. Achieved when turbine speed is within the target range (**650 RPM – 750 RPM**). The PI governor loop remains active to stabilize generation. Indicator: **Green LED**.

### Key Signals

| Signal | Type | Description |
| :--- | :--- | :--- |
| `rpm_in_range` | Input | Set to '1' when turbine speed is between 650 and 750 RPM. |
| `bat_charged` | Input | Set to '1' when the INA219 sensor detects a fully charged battery (~99%). |
| `leds[2:0]` | Output | Status indicators `[Red (OFF), Yellow (SEARCH), Green (TRACK)]`. |
| `pid_enable` | Output | Enables the PI governor control loop. |
| `servo_force_close` | Output | Forces valve fully closed for safety or system shutdown. |

---

## System Modules (Verilog)

- **`top_system.v`**: Top-level module interconnecting the FSM, RPM meter, INA219 driver, and PI governor.
- **`fsm_charger.v`**: Core state machine logic.
- **`rpm_meter.v`**: Hall sensor pulse counter and RPM range discriminator.
- **`rpm_governor.v`**: PI control loop and PWM signal generator for the servovalve.
- **`ina219_driver.v`**: I2C communication interface for battery voltage and charge state monitoring.
- **`UART/`**: Optional serial communication module for telemetry and remote monitoring.

---

## Simulation and Verification

The project is configured for compilation and simulation using open-source tools such as `Icarus Verilog` and `GTKWave`.

## Justification
The project came up because my partner Nicolas was working with generators and hydrological systems in order to produce energy for Non-Interconnected Zones (NIZ). They were working with bigger units but the idea remain the same and we ended up designing a system that would fit perfectly for the company he was working with.
