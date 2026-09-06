help: help-sim help-syn
clean: clean-syn clean-sim

# ==============================================================================
# 1. CONFIGURACIÓN DEL PROYECTO (MODIFICAR AQUÍ)
# ==============================================================================

# Nombre del archivo fuente principal (o el que quieres simular ahora)
DESIGN=fsm_charger.v

# Nombre del archivo del testbench
tb=fsm_charger_tb.v

# Si tienes más archivos (módulos extra), agrégalos aquí separados por espacio.
# Ejemplo para el futuro: MORE_SRC=rpm_meter.v pid_controller.v
MORE_SRC=

# ==============================================================================
# 2. CONFIGURACIÓN GENERAL (NO TOCAR NORMALMENTE)
# ==============================================================================
DIR_BUILD=build
DEVSERIAL=/dev/ttyACM0
MACROS_SIM=-DINIT=(2**25-10)
MACROS_RTL?=
MACROS_SYN?=
Z=template

top_NAME=$(basename $(notdir $(DESIGN)))
top?=$(top_NAME)

#################################################
###--- Reglas de Síntesis (Colorlight 5A-75E) ---###
#################################################
LPF?=$(top).lpf
JSON?=$(DIR_BUILD)/$(top).json
PNR?=$(DIR_BUILD)/$(top).pnr
BISTREAM?=$(DIR_BUILD)/$(top).bit
LOG_YOSYS?=$(DIR_BUILD)/yosys-$(top).log
LOG_NEXTPNR?=$(DIR_BUILD)/nextpnr-$(top).log

# Preprocesamiento
MACROS_SYN := $(foreach macro,$(MACROS_SYN),"$(macro)")

help-syn:
	@printf "\n## SINTESIS Y CONFIGURACIÓN ##\n"
	@printf "\tmake syn\t\t-> Sintetizar diseño\n"
	@printf "\tmake config\t\t-> Configurar fpga en CRAM\n"
	@printf "\tmake config-flash\t-> Guardar el bistream en memoria flash\n"
	@printf "\tmake detect\t\t-> Detectar FPGA\n"
	@printf "\tmake clean\t\t-> Limpiar archivos temporales\n"

# Cadena de herramientas: JSON -> PNR -> BITSTREAM
syn: json pnr bitstream

OBJS+=$(DESIGN) $(MORE_SRC)

$(JSON): $(OBJS)
	mkdir -p $(DIR_BUILD)
	yosys $(MACROS_SYN) -p "synth_ecp5 -top $(top) -json $(JSON)" $(OBJS) -l $(LOG_YOSYS)

log-syn:
	less $(LOG_YOSYS)

$(PNR): $(JSON)
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $(JSON) --lpf $(LPF) --freq 65 --textcfg $(PNR) --log $(LOG_NEXTPNR)

log-pnr:
	less $(LOG_NEXTPNR)

$(BISTREAM): $(PNR)
	ecppack $(PNR) $(BISTREAM)

# Configuración del Programador (openFPGALoader / FTDI)
CABLE= -c ft232RL
FT232RL_TXD=0
FT232RL_RXD=1
FT232RL_RTS=2
FT232RL_CTS=3
FT232RL_DTR=4
FT232RL_DSR=5
FT232RL_DCD=6
FT232RL_RI=7
TDI=$(FT232RL_TXD)
TDO=$(FT232RL_CTS)
TCK=$(FT232RL_DTR)
TMS=$(FT232RL_RXD)
CABLE_PINES?=$(TDI):$(TDO):$(TCK):$(TMS)

CONFIG_OPTIONS+=$(CABLE)
ifneq ($(CABLE_PINES),)
CONFIG_OPTIONS+= --pins=$(CABLE_PINES)
endif
CONFIG_OPTIONS+= --verbose
CONFIG_OPTIONS+= --freq 3000000

PATH_OPEN_FPGA_LOADER=openFPGALoader

reset:
	$(PATH_OPEN_FPGA_LOADER) $(CONFIG_OPTIONS)  -r

detect:
	$(PATH_OPEN_FPGA_LOADER) $(CONFIG_OPTIONS) --detect $(OPTIONS_CABLE)

config-flash:
	$(PATH_OPEN_FPGA_LOADER) $(CONFIG_OPTIONS) -f $(BISTREAM) --unprotect-flash

erase-flash:
	$(PATH_OPEN_FPGA_LOADER) $(CONFIG_OPTIONS) --bulk-erase --unprotect-flash

config-sram:
	$(PATH_OPEN_FPGA_LOADER) $(CONFIG_OPTIONS) -m $(BISTREAM)

config: config-sram

json:$(JSON)
pnr:$(PNR)
bitstream:$(BISTREAM)

# --- Comprimir Proyecto ---
zip:
	$(RM) $Z $Z.zip
	mkdir -p $Z
	cp -var *.v *.md *.lpf .gitignore Makefile $Z
	zip -r $Z.zip $Z

init:
	@echo "build/\nsim/\n*.log\n$Z/\n" > .gitignore

clean-syn:
	$(RM) -rf $(DIR_BUILD)

.PHONY: clean help-syn help-sim syn config

#################################################
###--- Reglas de Simulación (Icarus Verilog) ---###
#################################################
tb?=$(top_NAME)_tb.v
TBN=$(basename $(notdir $(tb)))
S=sim
LOG_YOSYS_RTL?=$(S)/yosys-$(top).log

# Configuración de Shell
.ONESHELL:
SHELL=/bin/bash

help-sim:
	@printf "\n## SIMULACIÓN Y RTL ##\n"
	@printf "\tmake sim \t-> Simular diseño\n"
	@printf "\tmake wave \t-> Ver simulación en gtkwave\n"

# Compilación y Ejecución
sim: clean-sim iverilog-compile vpp-simulate wave

MACROS_SIM := $(foreach macro,$(MACROS_SIM),"$(macro)")
MORE_SRC2SIM?=$(MORE_SRC)

iverilog-compile:
	mkdir -p $S
	iverilog $(MACROS_SIM) -o $S/$(TBN).vvp -s $(TBN) $(tb) $(DESIGN) $(MORE_SRC2SIM)

vpp-simulate:
	cd $S && vvp $(TBN).vvp -vcd -dumpfile=$(TBN).vcd

wave:
	@gtkwave $S/$(TBN).vcd $(TBN).gtkw || (echo "Abriendo GTKWave sin configuración previa...")

clean-sim:
	rm -rf $S

rtl-from-json:
	mkdir -p $S
	yosys -p 'read_verilog $(DESIGN) $(MORE_SRC); prep -top $(top); hierarchy -check; proc; write_json $S/$(top).json'
	netlistsvg $S/$(top).json -o $S/$(top).svg
	eog $S/$(top).svg
