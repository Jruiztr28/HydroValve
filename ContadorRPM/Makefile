help: help-sim help-syn
clean: clean-syn clean-sim

# ==========================================
# CONFIGURACIÓN DEL PROYECTO (MODIFICADO)
# ==========================================

# Diseño: Apuntamos al archivo del módulo de RPM
DESIGN=rpm_meter.v

# Test bench: Apuntamos al archivo de prueba de RPM
tb=rpm_meter_tb.v

# ==========================================

DIR_BUILD=build
DEVSERIAL=/dev/ttyACM0
MACROS_SIM=-DINIT=(2**25-10)
MACROS_RTL?=
MACROS_SYN?=
# Z: Nombre para empaquetar proyecto
Z=template

top_NAME=$(basename $(notdir $(DESIGN)))

#################################################
###--- Rules from colorlight-5a-75e-syn.mk ---###
#################################################
top?=$(top_NAME)
LPF?=$(top).lpf
JSON?=$(DIR_BUILD)/$(top).json
PNR?=$(DIR_BUILD)/$(top).pnr
BISTREAM?=$(DIR_BUILD)/$(top).bit
LOG_YOSYS?=$(DIR_BUILD)/yosys-$(top).log
LOG_NEXTPNR?=$(DIR_BUILD)/nextpnr-$(top).log

# MACRO_SYN sirve para indicar definiciones de preprocesamiento en la sintesis
MACROS_SYN := $(foreach macro,$(MACROS_SYN),"$(macro)")

help-syn:
	@printf "\n## SINTESIS Y CONFIGURACIÓN ##\n"
	@printf "\tmake syn\t\t-> Sintetizar diseño\n"
	@printf "\tmake config\t\t-> Configurar fpga en CRAM\n"
	@printf "\tmake config-flash\t-> Guardar el bistream en memoria flash\n"
	@printf "\tmake config-help\t-> Ayuda sobre cómo configurar la Colorlight\n"
	@printf "\tmake detect\t\t-> Detectar FPGA\n"
	@printf "\tmake reset\t\t-> Reiniciar FPGA\n"
	@printf "\tmake erase-flash\t-> Borrar la memoria flash de configuración\n"
	@printf "\tmake log-syn\t\t-> Ver el log de la síntesis con Yosys.\n"
	@printf "\tmake log-pnr\t\t-> Ver el log del place&route con nextpnr.\n"
	@printf "\tmake clean\t\t-> Limipiar síntesis si ha modificado el diseño\n"

syn: json pnr bitstream

OBJS+=$(DESIGN)

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

# USB-UART
CABLE= -c ft232RL
# Pines del FTDI usable
FT232RL_TXD=0
FT232RL_RXD=1
FT232RL_RTS=2
FT232RL_CTS=3
FT232RL_DTR=4
FT232RL_DSR=5
FT232RL_DCD=6
FT232RL_RI=7
# JTAG pines relacionados con los pines del ft232rl
TDI=$(FT232RL_TXD)
TDO=$(FT232RL_CTS)
TCK=$(FT232RL_DTR)
TMS=$(FT232RL_RXD)
# JTAG pines relacionados con los pines del ft232rl
CABLE_PINES?=$(TDI):$(TDO):$(TCK):$(TMS)

CONFIG_OPTIONS+=$(CABLE)

ifneq ($(CABLE_PINES),) # Si cables es diferente de vacío
CONFIG_OPTIONS+= --pins=$(CABLE_PINES)
endif
CONFIG_OPTIONS+= --verbose
CONFIG_OPTIONS+= --freq 3000000
# CONFIG_OPTIONS+= --invert-read-edge

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

config-help:
	@printf "## INFORMACIÓN DE CONFIGURACIÓN PARA COLORLIGHT ##\n"

json:$(JSON)
pnr:$(PNR)
bitstream:$(BISTREAM)

init:
	@echo "build/\nsim/\n*.log\n$Z/\n" > .gitignore
	touch $(top).png README.md

clean-syn:
	rm -rf $(DIR_BUILD)

.PHONY: clean

###############################
###--- Rules from sim.mk ---###
###############################
# Si no se define tb arriba, intenta deducirlo, pero ya lo definimos.
tb?=$(top_NAME)_tb.v
TBN=$(basename $(notdir $(tb)))

S=sim
LOG_YOSYS_RTL?=$(S)/yosys-$(top).log

.ONESHELL:
SHELL=/bin/bash
# Enviroment conda to activate
ENV=digital
CONDA_ACTIVATE = source $$($$CONDA_EXE info --base)/etc/profile.d/conda.sh ; conda activate; conda activate $(ENV)
RUN = $(CONDA_ACTIVATE) &&
# RUN =# Activate if don't use CONDA

help-sim:
	@printf "\n## SIMULACIÓN Y RTL##"
	@printf "\tmake rtl \t-> Crear el RTL desde el TOP\n"
	@printf "\tmake sim \t-> Simular diseño\n"
	@printf "\tmake wave \t-> Ver simulación en gtkwave\n"

rtl: rtl-from-json view-svg

sim: clean-sim iverilog-compile vpp-simulate wave

MACROS_SIM := $(foreach macro,$(MACROS_SIM),"$(macro)")
MORE_SRC2SIM?=

iverilog-compile:
	mkdir -p $S
ifneq ($(MORE_SRC2SIM), )
	cp -var $(MORE_SRC2SIM) $S
endif
	iverilog $(MACROS_SIM) -o $S/$(TBN).vvp -s $(TBN) $(tb) $(DESIGN)

VVP_ARG=
vpp-simulate:
	cd $S && vvp $(TBN).vvp -vcd $(VVP_ARG) -dumpfile=$(TBN).vcd

wave:
	@gtkwave $S/$(TBN).vcd $(TBN).gtkw || (echo "No hay un forma de onda que mostrar")

MACROS_RTL := $(foreach macro,$(MACROS_RTL),"$(macro)")
json-yosys:
	mkdir -p $S
	$(RUN) yosys $(MACROS_RTL) -p 'prep -top $(top); hierarchy -check; proc; write_json $S/$(top).json' $(DESIGN) -l $(LOG_YOSYS_RTL)

log-rtl:
	less $(LOG_YOSYS_RTL)

ConvertOneVerilogFile:
	mkdir -p $S
	$(RUN) yosys $(MACROS_SIM) -p 'prep -top $(top); hierarchy -check; proc; opt -full; write_verilog -noattr -nodec $S/$(top).v' $(DESIGN)

rtl-from-json: json-yosys
	cp $S/$(top).json $S/$(top)_origin.json
	sed -E 's/"\$$paramod\$$[^\\]+\\\\([^"]+)"/"\1"/g' $S/$(top)_origin.json > $S/$(top).json
	$(RUN) netlistsvg $S/$(top).json -o $S/$(top).svg
	sed -i 's|<svg\([^>]*\)>|<svg\1>\n  <rect width="100%" height="100%" fill="white"/>|' $S/$(top).svg

view-svg:
	eog $S/$(top).svg

rtl2png:
	convert -density 200 -resize 1200 $S/$(top).svg $(top).png

clean-sim:
	rm -rf $S $Z $Z.zip
