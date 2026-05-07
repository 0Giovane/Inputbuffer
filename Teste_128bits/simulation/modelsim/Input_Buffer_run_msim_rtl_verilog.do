transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+F:/TesteV2 {F:/TesteV2/Input_Buffer.v}
vcom -93 -work work {F:/TesteV2/memoria.vhd}

